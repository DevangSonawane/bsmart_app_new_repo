import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../api/api_exceptions.dart';
import '../../api/insights_api.dart';
import '../../models/insights_models.dart';
import '../../widgets/insights/insights_ui.dart';
import 'post_insights_screen.dart';

/// Account-wide insights — Instagram's "Professional dashboard / Insights".
///
/// Backed by `GET /users/:id/insights` and
/// `GET /users/:id/content-performance?days=N`.
class AccountInsightsScreen extends StatefulWidget {
  final String userId;
  final String? username;

  /// Pre-loaded data (used by previews/tests); skips the network calls.
  final AccountInsights? preloadedInsights;
  final Map<int, ContentPerformance>? preloadedPerformance;

  const AccountInsightsScreen({
    super.key,
    required this.userId,
    this.username,
    this.preloadedInsights,
    this.preloadedPerformance,
  });

  static Future<void> open(BuildContext context,
      {required String userId, String? username}) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          AccountInsightsScreen(userId: userId, username: username),
    ));
  }

  @override
  State<AccountInsightsScreen> createState() => _AccountInsightsScreenState();
}

class _AccountInsightsScreenState extends State<AccountInsightsScreen> {
  static const _periods = [7, 14, 28, 60, 90];
  static const _typeKeys = ['all', 'reel', 'post', 'story'];
  static const _typeLabels = ['All', 'Reels', 'Posts', 'Stories'];
  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  AccountInsights? _insights;
  final Map<int, ContentPerformance> _perfCache = {};
  ContentPerformance? _perf;
  int _days = 28;
  int _typeIndex = 0;
  int? _heatDay;
  bool _loading = true;
  bool _perfLoading = false;
  String? _error;
  Map<String, String>? _headers;

  bool get _isPreview => widget.preloadedInsights != null;

  @override
  void initState() {
    super.initState();
    if (_isPreview) {
      _insights = widget.preloadedInsights;
      _perfCache.addAll(widget.preloadedPerformance ?? const {});
      _perf = _perfCache[_days];
      _loading = false;
      _heatDay = _bestSlot()?.$1;
    } else {
      _loadAll();
    }
    ApiClient().getToken().then((t) {
      if (!mounted || t == null) return;
      setState(() => _headers = {'Authorization': 'Bearer $t'});
    });
  }

  String _errorText(Object e) {
    if (e is ApiException) {
      if (e.statusCode == 403) {
        return 'Insights are only available for your own account.';
      }
      return e.message;
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = InsightsApi();
      final results = await Future.wait([
        api.getUserInsights(widget.userId),
        api.getContentPerformance(widget.userId, days: _days),
      ]);
      if (!mounted) return;
      final perf = ContentPerformance.fromJson(results[1], fallbackDays: _days);
      setState(() {
        _insights = AccountInsights.fromJson(results[0]);
        _perfCache[_days] = perf;
        _perf = perf;
        _heatDay = _bestSlot()?.$1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorText(e);
      });
    }
  }

  Future<void> _selectPeriod(int days) async {
    if (days == _days) return;
    setState(() => _days = days);
    final cached = _perfCache[days];
    if (cached != null) {
      setState(() => _perf = cached);
      return;
    }
    if (_isPreview) return;
    setState(() => _perfLoading = true);
    try {
      final json =
          await InsightsApi().getContentPerformance(widget.userId, days: days);
      if (!mounted) return;
      final perf = ContentPerformance.fromJson(json, fallbackDays: days);
      setState(() {
        _perfCache[days] = perf;
        if (_days == days) _perf = perf;
        _perfLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _perfLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_errorText(e)),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _showPeriodPicker() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: InsightsPalette.muted(ctx).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text('Date range',
                style: TextStyle(
                    color: InsightsPalette.fg(ctx),
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            const SizedBox(height: 8),
            for (final d in _periods)
              ListTile(
                title: Text('Last $d days',
                    style: TextStyle(color: InsightsPalette.fg(ctx))),
                trailing: Icon(
                  d == _days ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: d == _days
                      ? InsightsPalette.fg(ctx)
                      : InsightsPalette.muted(ctx),
                ),
                onTap: () => Navigator.of(ctx).pop(d),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) _selectPeriod(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft,
              color: InsightsPalette.fg(context), size: 26),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Insights',
            style: TextStyle(
                color: InsightsPalette.fg(context),
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return _buildSkeleton();
    if (_error != null || _insights == null) {
      return InsightErrorState(
          message: _error ?? 'No data available.', onRetry: _loadAll);
    }
    final ins = _insights!;
    return RefreshIndicator(
      onRefresh: _isPreview ? () async {} : _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildPeriodBar(context),
          _buildOverview(context, ins),
          _buildPerformance(context),
          _buildFollowers(context, ins),
          _buildReach(context, ins),
          _buildTerritories(context, ins),
          _buildActiveTimes(context, ins),
          _buildTopContent(context, ins),
          _buildRecentContent(context, ins),
          _buildLifetimeTotals(context, ins),
        ],
      ),
    );
  }

  // ── Period bar ───────────────────────────────────────────────────────────

  Widget _buildPeriodBar(BuildContext context) {
    final end = _perf?.end ?? DateTime.now();
    final start = _perf?.start ?? end.subtract(Duration(days: _days));
    final fmt = DateFormat('d MMM');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          InkWell(
            onTap: _showPeriodPicker,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: InsightsPalette.card(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text('Last $_days days',
                      style: TextStyle(
                          color: InsightsPalette.fg(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronDown,
                      size: 16, color: InsightsPalette.fg(context)),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (_perfLoading)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Text('${fmt.format(start)} – ${fmt.format(end)}',
              style: TextStyle(
                  color: InsightsPalette.muted(context), fontSize: 13)),
        ],
      ),
    );
  }

  // ── Overview ─────────────────────────────────────────────────────────────

  Widget _buildOverview(BuildContext context, AccountInsights ins) {
    final cur = _perf?.currentFor('all') ?? const PerformanceMetrics();
    final prev = _perf?.previousFor('all') ?? const PerformanceMetrics();
    final interactions = cur.likes + cur.comments + cur.saves;
    final prevInteractions = prev.likes + prev.comments + prev.saves;
    return InsightsSection(
      title: 'Overview',
      subtitle: 'You shared ${formatFull(cur.contentCount)} '
          '${cur.contentCount == 1 ? 'piece' : 'pieces'} of content in the last $_days days.',
      showDivider: false,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
      child: Column(
        children: [
          InsightMetricRow(
            label: 'Views',
            value: formatFull(cur.plays),
            delta: percentDelta(cur.plays, prev.plays),
          ),
          InsightMetricRow(
            label: 'Interactions',
            value: formatFull(interactions),
            delta: percentDelta(interactions, prevInteractions),
          ),
          InsightMetricRow(
            label: 'New followers',
            value: '+${formatFull(ins.newFollowers30d)}',
          ),
          InsightMetricRow(
            label: 'Total followers',
            value: formatFull(ins.followers),
          ),
        ],
      ),
    );
  }

  // ── Content performance ──────────────────────────────────────────────────

  Widget _buildPerformance(BuildContext context) {
    final key = _typeKeys[_typeIndex];
    final cur = _perf?.currentFor(key) ?? const PerformanceMetrics();
    final prev = _perf?.previousFor(key) ?? const PerformanceMetrics();
    final isReelish = key == 'all' || key == 'reel';

    final tiles = <_StatTileData>[
      _StatTileData('Views', formatCompact(cur.plays),
          percentDelta(cur.plays, prev.plays), LucideIcons.play),
      _StatTileData('Likes', formatCompact(cur.likes),
          percentDelta(cur.likes, prev.likes), LucideIcons.heart),
      _StatTileData('Comments', formatCompact(cur.comments),
          percentDelta(cur.comments, prev.comments), LucideIcons.messageCircle),
      _StatTileData('Saves', formatCompact(cur.saves),
          percentDelta(cur.saves, prev.saves), LucideIcons.bookmark),
      _StatTileData(
          'Engagement',
          '${cur.engagementRate.toStringAsFixed(1)}%',
          percentDelta(cur.engagementRate, prev.engagementRate),
          LucideIcons.activity),
      if (isReelish)
        _StatTileData(
            'Watch time',
            formatWatchTime(cur.watchTimeMs),
            percentDelta(cur.watchTimeMs, prev.watchTimeMs),
            LucideIcons.clock),
      _StatTileData('Shared', formatFull(cur.contentCount),
          percentDelta(cur.contentCount, prev.contentCount), LucideIcons.layoutGrid),
    ];

    return InsightsSection(
      title: 'Content performance',
      subtitle: 'Compared with the previous $_days days.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InsightPillTabs(
            labels: _typeLabels,
            selected: _typeIndex,
            onChanged: (i) => setState(() => _typeIndex = i),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in tiles) SizedBox(width: w, child: _StatTile(t)),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── Followers ────────────────────────────────────────────────────────────

  Widget _buildFollowers(BuildContext context, AccountInsights ins) {
    final growth = _filledGrowth(ins.followerGrowth);
    final fmt = DateFormat('d MMM');
    final labels = growth.isEmpty
        ? <String>[]
        : [
            fmt.format(growth.first.date),
            fmt.format(growth[growth.length ~/ 2].date),
            fmt.format(growth.last.date),
          ];
    return InsightsSection(
      title: 'Followers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InsightHeroNumber(
            value: formatFull(ins.followers),
            label: 'Followers',
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              '+${formatFull(ins.newFollowers30d)} new in the last 30 days',
              style: const TextStyle(
                  color: InsightsPalette.positive,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 18),
          if (growth.isEmpty || ins.newFollowers30d == 0)
            const InsightEmpty(text: 'No new followers in the last 30 days')
          else
            InsightLineChart(
              height: 170,
              xLabels: labels,
              formatY: (v) => formatCompact(v.round()),
              tooltipTitle: (i) => DateFormat('EEE, d MMM')
                  .format(growth[i.clamp(0, growth.length - 1)].date),
              series: [
                LineSeries(
                  values: growth.map((g) => g.count.toDouble()).toList(),
                  color: InsightsPalette.primary,
                  label: 'New followers',
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Fills missing days with zero so the chart's x-axis is a real timeline.
  List<DailyCount> _filledGrowth(List<DailyCount> raw) {
    if (raw.isEmpty) return raw;
    final byDay = <String, int>{};
    String k(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    for (final g in raw) {
      byDay[k(g.date)] = (byDay[k(g.date)] ?? 0) + g.count;
    }
    final end = DateTime.now();
    final start = DateTime(end.year, end.month, end.day)
        .subtract(const Duration(days: 29));
    return [
      for (var i = 0; i < 30; i++)
        () {
          final d = start.add(Duration(days: i));
          return DailyCount(d, byDay[k(d)] ?? 0);
        }(),
    ];
  }

  // ── Reach ────────────────────────────────────────────────────────────────

  Widget _buildReach(BuildContext context, AccountInsights ins) {
    return InsightsSection(
      title: 'Accounts reached',
      subtitle: 'Unique people who watched your reels.',
      child: ins.reachTotal == 0
          ? const InsightEmpty(text: 'No reel viewers yet')
          : InsightDonut(
              centerValue: formatCompact(ins.reachTotal),
              centerLabel: 'Accounts reached',
              segments: [
                DonutSegment(
                    'Followers', ins.reachFollowers, InsightsPalette.primary),
                DonutSegment('Non-followers', ins.reachNonFollowers,
                    InsightsPalette.secondary),
              ],
            ),
    );
  }

  Widget _buildTerritories(BuildContext context, AccountInsights ins) {
    return InsightsSection(
      title: 'Top locations',
      subtitle: 'Where your reel viewers are.',
      child: InsightBarList(buckets: ins.topTerritories, maxItems: 5),
    );
  }

  // ── Most active times ────────────────────────────────────────────────────

  (int, int)? _bestSlot() {
    final ins = _insights;
    if (ins == null || !ins.hasHeatmap) return null;
    var best = (0, 0);
    var bestV = -1;
    for (var d = 0; d < 7; d++) {
      for (var h = 0; h < 24; h++) {
        if (ins.heatmap[d][h] > bestV) {
          bestV = ins.heatmap[d][h];
          best = (d, h);
        }
      }
    }
    return best;
  }

  String _hourRange(int h) {
    String f(int x) {
      final hh = x % 24;
      final suffix = hh < 12 ? 'am' : 'pm';
      final v = hh % 12 == 0 ? 12 : hh % 12;
      return '$v$suffix';
    }

    return '${f(h)} – ${f(h + 1)}';
  }

  Widget _buildActiveTimes(BuildContext context, AccountInsights ins) {
    if (!ins.hasHeatmap) {
      return const InsightsSection(
        title: 'Most active times',
        child: InsightEmpty(
            text: 'Post a few reels to see when your audience watches.'),
      );
    }
    final best = _bestSlot()!;
    final day = _heatDay ?? best.$1;
    final row = ins.heatmap[day];
    final peakHour = row.indexOf(row.reduce(math.max));
    return InsightsSection(
      title: 'Most active times',
      subtitle: 'When your reel views land (IST).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var d = 0; d < 7; d++)
                GestureDetector(
                  onTap: () => setState(() => _heatDay = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 40,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: d == day
                          ? InsightsPalette.fg(context)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _dayNames[d].substring(0, 1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: d == day
                            ? Theme.of(context).scaffoldBackgroundColor
                            : InsightsPalette.muted(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          InsightHourBars(values: row, highlight: peakHour),
          const SizedBox(height: 18),
          InsightNote(
            icon: LucideIcons.sparkles,
            text:
                'Your best window is ${_dayNames[best.$1]}, ${_hourRange(best.$2)}. '
                'Try posting a little before then.',
          ),
        ],
      ),
    );
  }

  // ── Content ──────────────────────────────────────────────────────────────

  void _openContent(InsightContentItem item) {
    if (item.id.isEmpty) return;
    PostInsightsScreen.open(context,
        postId: item.id, thumbnailUrl: item.thumbnailUrl);
  }

  Widget _buildTopContent(BuildContext context, AccountInsights ins) {
    return InsightsSection(
      title: 'Top content',
      subtitle: 'Your best performers by views.',
      padding: const EdgeInsets.fromLTRB(16, 22, 0, 22),
      child: ins.topPosts.isEmpty
          ? const InsightEmpty(text: 'Nothing posted yet')
          : SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: ins.topPosts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final item = ins.topPosts[i];
                  return GestureDetector(
                    onTap: () => _openContent(item),
                    child: Stack(
                      children: [
                        InsightThumb(
                          url: item.thumbnailUrl,
                          headers: _headers,
                          width: 116,
                          height: 196,
                          radius: 10,
                          isReel: item.isReel,
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black54],
                                stops: [0.6, 1],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Row(
                            children: [
                              Icon(
                                  item.isReel
                                      ? LucideIcons.play
                                      : LucideIcons.eye,
                                  color: Colors.white,
                                  size: 13),
                              const SizedBox(width: 4),
                              Text(formatCompact(item.views),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        if (item.isReel)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(LucideIcons.clapperboard,
                                color: Colors.white, size: 14),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildRecentContent(BuildContext context, AccountInsights ins) {
    final fmt = DateFormat('d MMM');
    final items = ins.recentContent.take(10).toList();
    return InsightsSection(
      title: 'Recent content',
      child: items.isEmpty
          ? const InsightEmpty(text: 'Nothing posted yet')
          : Column(
              children: [
                for (final item in items)
                  InkWell(
                    onTap: () => _openContent(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          InsightThumb(
                            url: item.thumbnailUrl,
                            headers: _headers,
                            width: 52,
                            height: item.isReel ? 68 : 52,
                            radius: 8,
                            isReel: item.isReel,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.caption.isEmpty
                                      ? (item.isReel ? 'Reel' : 'Post')
                                      : item.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: InsightsPalette.fg(context),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    item.isReel ? 'Reel' : 'Post',
                                    if (item.createdAt != null)
                                      fmt.format(item.createdAt!),
                                  ].join(' · '),
                                  style: TextStyle(
                                      color: InsightsPalette.muted(context),
                                      fontSize: 12.5),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _miniStat(context, LucideIcons.eye,
                                        item.views),
                                    _miniStat(context, LucideIcons.heart,
                                        item.likes),
                                    _miniStat(context,
                                        LucideIcons.messageCircle,
                                        item.comments),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(LucideIcons.chevronRight,
                              size: 18,
                              color: InsightsPalette.muted(context)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _miniStat(BuildContext context, IconData icon, int value) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        children: [
          Icon(icon, size: 13, color: InsightsPalette.muted(context)),
          const SizedBox(width: 4),
          Text(formatCompact(value),
              style: TextStyle(
                  color: InsightsPalette.fg(context),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLifetimeTotals(BuildContext context, AccountInsights ins) {
    return InsightsSection(
      title: 'Lifetime',
      subtitle: 'Totals across everything you\'ve posted.',
      child: Column(
        children: [
          InsightMetricRow(
              icon: LucideIcons.layoutGrid,
              label: 'Posts',
              value: formatFull(ins.posts)),
          InsightMetricRow(
              icon: LucideIcons.eye,
              label: 'Views',
              value: formatFull(ins.views)),
          InsightMetricRow(
              icon: LucideIcons.heart,
              label: 'Likes',
              value: formatFull(ins.likes)),
          InsightMetricRow(
              icon: LucideIcons.messageCircle,
              label: 'Comments',
              value: formatFull(ins.comments)),
          InsightMetricRow(
              icon: LucideIcons.users,
              label: 'Following',
              value: formatFull(ins.following)),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Row(children: [InsightSkeleton(height: 34, width: 130)]),
        const SizedBox(height: 22),
        for (var i = 0; i < 4; i++) ...[
          const InsightSkeleton(height: 16),
          const SizedBox(height: 18),
        ],
        const SizedBox(height: 10),
        const Row(children: [
          Expanded(child: InsightSkeleton(height: 84, radius: 14)),
          SizedBox(width: 10),
          Expanded(child: InsightSkeleton(height: 84, radius: 14)),
        ]),
        const SizedBox(height: 10),
        const Row(children: [
          Expanded(child: InsightSkeleton(height: 84, radius: 14)),
          SizedBox(width: 10),
          Expanded(child: InsightSkeleton(height: 84, radius: 14)),
        ]),
        const SizedBox(height: 24),
        const InsightSkeleton(height: 190, radius: 16),
      ],
    );
  }
}

class _StatTileData {
  final String label;
  final String value;
  final double? delta;
  final IconData icon;
  const _StatTileData(this.label, this.value, this.delta, this.icon);
}

class _StatTile extends StatelessWidget {
  final _StatTileData data;
  const _StatTile(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: InsightsPalette.card(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 14, color: InsightsPalette.muted(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(data.label,
                    style: TextStyle(
                        color: InsightsPalette.muted(context), fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: InsightsPalette.fg(context),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          if (data.delta != null)
            Row(
              children: [
                DeltaText(delta: data.delta!, fontSize: 12),
                Text(' vs prev.',
                    style: TextStyle(
                        color: InsightsPalette.muted(context), fontSize: 11.5)),
              ],
            )
          else
            Text('No prior data',
                style: TextStyle(
                    color: InsightsPalette.muted(context), fontSize: 11.5)),
        ],
      ),
    );
  }
}
