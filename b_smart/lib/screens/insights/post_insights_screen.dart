import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../api/api_exceptions.dart';
import '../../api/insights_api.dart';
import '../../models/insights_models.dart';
import '../../widgets/insights/insights_ui.dart';

/// Instagram-style insights for one post, reel or promoted reel.
///
/// Backed by `GET /posts/:id/stats` or `GET /promote-reels/:id/stats`.
class PostInsightsScreen extends StatefulWidget {
  final String postId;
  final bool isPromoted;

  /// Optional thumbnail to show while the stats load.
  final String? initialThumbnailUrl;

  /// Pre-loaded data (used by previews/tests); skips the network call.
  final ContentInsights? preloaded;

  const PostInsightsScreen({
    super.key,
    required this.postId,
    this.isPromoted = false,
    this.initialThumbnailUrl,
    this.preloaded,
  });

  static Future<void> open(
    BuildContext context, {
    required String postId,
    bool isPromoted = false,
    String? thumbnailUrl,
  }) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PostInsightsScreen(
        postId: postId,
        isPromoted: isPromoted,
        initialThumbnailUrl: thumbnailUrl,
      ),
    ));
  }

  @override
  State<PostInsightsScreen> createState() => _PostInsightsScreenState();
}

class _PostInsightsScreenState extends State<PostInsightsScreen> {
  ContentInsights? _data;
  String? _error;
  bool _loading = true;
  Map<String, String>? _headers;
  int _audienceTab = 0;
  int _likesTab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.preloaded != null) {
      _data = widget.preloaded;
      _loading = false;
    } else {
      _load();
    }
    ApiClient().getToken().then((t) {
      if (!mounted || t == null) return;
      setState(() => _headers = {'Authorization': 'Bearer $t'});
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = InsightsApi();
      final json = widget.isPromoted
          ? await api.getPromoteReelStats(widget.postId)
          : await api.getPostStats(widget.postId);
      if (!mounted) return;
      setState(() {
        _data = ContentInsights.fromJson(json,
            fallbackType: widget.isPromoted ? 'promote' : null);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.statusCode == 403
            ? 'Insights are only available for your own content.'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  String get _title {
    if (widget.isPromoted) return 'Promoted reel insights';
    final d = _data;
    if (d == null) return 'Insights';
    return d.isReel ? 'Reel insights' : 'Post insights';
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
        title: Text(
          _title,
          style: TextStyle(
            color: InsightsPalette.fg(context),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return _buildSkeleton(context);
    if (_error != null || _data == null) {
      return InsightErrorState(
        message: _error ?? 'No data available.',
        onRetry: _load,
      );
    }
    final d = _data!;
    return RefreshIndicator(
      onRefresh: widget.preloaded != null ? () async {} : _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildHeader(context, d),
          _buildOverview(context, d),
          _buildViews(context, d),
          if (d.isReel && !widget.isPromoted) _buildRetention(context, d),
          _buildAudience(context, d),
          _buildLikes(context, d),
          _buildComments(context, d),
        ],
      ),
    );
  }

  // ── Header: thumbnail + date + engagement icons ──────────────────────────

  Widget _buildHeader(BuildContext context, ContentInsights d) {
    final isReel = d.isReel || widget.isPromoted;
    final thumb = d.thumbnailUrl.isNotEmpty
        ? d.thumbnailUrl
        : (widget.initialThumbnailUrl ?? '');
    final date = d.createdAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
      child: Column(
        children: [
          Stack(
            children: [
              InsightThumb(
                url: thumb,
                headers: _headers,
                width: isReel ? 112 : 132,
                height: isReel ? 190 : 132,
                radius: 12,
                isReel: isReel,
              ),
              if (isReel)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(LucideIcons.clapperboard,
                      color: Colors.white, size: 16, shadows: [
                    Shadow(color: Colors.black54, blurRadius: 6),
                  ]),
                ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 12),
            Text(
              '${widget.isPromoted ? 'Promoted' : 'Posted'} on '
              '${DateFormat('d MMMM').format(date)} at '
              '${DateFormat('h:mm a').format(date)}',
              style: TextStyle(
                  color: InsightsPalette.muted(context), fontSize: 13),
            ),
          ],
          if (d.caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              d.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: InsightsPalette.fg(context), fontSize: 13.5),
            ),
          ],
          const SizedBox(height: 22),
          EngagementIconRow(items: [
            (LucideIcons.heart, d.likes.total),
            (LucideIcons.messageCircle, d.commentsTotal),
            if (d.shares > 0) (LucideIcons.send, d.shares),
            if (d.saves > 0) (LucideIcons.bookmark, d.saves),
            (LucideIcons.eye, d.viewsTotal),
          ]),
        ],
      ),
    );
  }

  // ── Overview ─────────────────────────────────────────────────────────────

  Widget _buildOverview(BuildContext context, ContentInsights d) {
    final interactions = d.likes.total + d.commentsTotal + d.shares + d.saves;
    return InsightsSection(
      title: 'Overview',
      child: Column(
        children: [
          InsightMetricRow(
              label: 'Views', value: formatFull(d.viewsTotal), emphasize: true),
          InsightMetricRow(
              label: 'Accounts reached', value: formatFull(d.viewsUnique)),
          InsightMetricRow(
              label: 'Interactions', value: formatFull(interactions)),
          if (d.isReel)
            InsightMetricRow(
                label: 'Watched to the end',
                value: formatFull(d.viewsCompleted)),
          InsightMetricRow(
            label: 'Engagement rate',
            value: '${d.engagementRate.toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }

  // ── Views ────────────────────────────────────────────────────────────────

  Widget _buildViews(BuildContext context, ContentInsights d) {
    final repeat = (d.viewsTotal - d.viewsUnique).clamp(0, d.viewsTotal);
    return InsightsSection(
      title: 'Views',
      child: Column(
        children: [
          InsightHeroNumber(
              value: formatCompact(d.viewsTotal), label: 'Views'),
          const SizedBox(height: 22),
          if (d.viewsTotal > 0)
            InsightDonut(
              size: 170,
              centerValue: formatCompact(d.viewsUnique),
              centerLabel: 'Unique viewers',
              segments: [
                DonutSegment('Unique viewers', d.viewsUnique,
                    InsightsPalette.primary),
                DonutSegment('Repeat views', repeat, InsightsPalette.secondary),
              ],
            )
          else
            const InsightEmpty(text: 'No views yet'),
          if (d.isReel && d.viewsTotal > 0) ...[
            const SizedBox(height: 8),
            _completionBar(context, d),
          ],
        ],
      ),
    );
  }

  Widget _completionBar(BuildContext context, ContentInsights d) {
    final rate = d.completionRate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: InsightsPalette.card(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Completion rate',
                    style: TextStyle(
                        color: InsightsPalette.fg(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              Text('${rate.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: InsightsPalette.fg(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 7,
              backgroundColor: InsightsPalette.faint(context),
              valueColor:
                  const AlwaysStoppedAnimation(InsightsPalette.positive),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatFull(d.viewsCompleted)} of ${formatFull(d.viewsTotal)} views watched all the way through',
            style:
                TextStyle(color: InsightsPalette.muted(context), fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // ── Retention ────────────────────────────────────────────────────────────

  Widget _buildRetention(BuildContext context, ContentInsights d) {
    if (d.retention.isEmpty) {
      return const InsightsSection(
        title: 'Audience retention',
        child: InsightEmpty(
            text: 'Retention appears once people start watching this reel.'),
      );
    }
    final hasPlatform = d.platformRetention.isNotEmpty;
    final at50 = _valueAt(d.retention, 50);
    final platformAt50 =
        hasPlatform ? _valueAt(d.platformRetention, 50) : null;
    String? callout;
    if (platformAt50 != null && at50 != null) {
      final diff = at50 - platformAt50;
      callout = diff >= 0
          ? '${at50.toStringAsFixed(0)}% of viewers reached the halfway point — ${diff.toStringAsFixed(0)} pts above typical reels on bSmart.'
          : '${at50.toStringAsFixed(0)}% of viewers reached the halfway point — ${diff.abs().toStringAsFixed(0)} pts below typical reels on bSmart.';
    }
    return InsightsSection(
      title: 'Audience retention',
      subtitle: 'Percentage of viewers still watching at each point of your reel.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InsightLineChart(
            height: 180,
            maxY: 100,
            formatY: (v) => '${v.toStringAsFixed(0)}%',
            tooltipTitle: (i) =>
                '${d.retention[i.clamp(0, d.retention.length - 1)].percent.toStringAsFixed(0)}% through',
            xLabels: const ['Start', '25%', '50%', '75%', 'End'],
            series: [
              LineSeries(
                values: d.retention.map((p) => p.value).toList(),
                color: InsightsPalette.primary,
                label: 'This reel',
              ),
              if (hasPlatform)
                LineSeries(
                  values: d.platformRetention.map((p) => p.value).toList(),
                  color: InsightsPalette.muted(context),
                  label: 'Typical reels on bSmart',
                  dashed: true,
                  filled: false,
                ),
            ],
          ),
          if (callout != null) ...[
            const SizedBox(height: 16),
            InsightNote(text: callout, icon: LucideIcons.sparkles),
          ],
        ],
      ),
    );
  }

  double? _valueAt(List<RetentionPoint> pts, double percent) {
    if (pts.isEmpty) return null;
    RetentionPoint best = pts.first;
    for (final p in pts) {
      if ((p.percent - percent).abs() < (best.percent - percent).abs()) {
        best = p;
      }
    }
    return best.value;
  }

  // ── Audience (who viewed) ────────────────────────────────────────────────

  Widget _buildAudience(BuildContext context, ContentInsights d) {
    if (widget.isPromoted) {
      return const InsightsSection(
        title: 'Audience',
        child: InsightNote(
          text:
              'Viewer location and age aren\'t tracked for promoted reels yet. '
              'Views, likes and comments above are exact.',
        ),
      );
    }
    if (!d.isReel) {
      return const InsightsSection(
        title: 'Audience',
        child: InsightNote(
          text:
              'Per-viewer breakdowns are available for reels. For photo posts, '
              'see who liked it below.',
        ),
      );
    }
    final tabs = ['Locations', 'Age'];
    final buckets = _audienceTab == 0 ? d.viewsByLocation : d.viewsByAge;
    return InsightsSection(
      title: 'Audience',
      subtitle: 'Based on unique viewers of this reel.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InsightPillTabs(
            labels: tabs,
            selected: _audienceTab,
            onChanged: (i) => setState(() => _audienceTab = i),
          ),
          const SizedBox(height: 20),
          InsightBarList(buckets: buckets),
        ],
      ),
    );
  }

  // ── Likes ────────────────────────────────────────────────────────────────

  Widget _buildLikes(BuildContext context, ContentInsights d) {
    final showDislikes = d.isReel && d.hasDislikes && !widget.isPromoted;
    final source = (_likesTab == 2 && showDislikes) ? d.dislikes : d.likes;
    final isAgeTab = _likesTab == 1;
    final buckets = isAgeTab ? source.byAge : source.byGender;
    final labels = ['Gender', 'Age', if (showDislikes) 'Didn\'t like'];
    return InsightsSection(
      title: 'Likes',
      subtitle: 'Who liked this, from their profile details.',
      trailing: Text(formatFull(d.likes.total),
          style: TextStyle(
              color: InsightsPalette.fg(context),
              fontSize: 17,
              fontWeight: FontWeight.w700)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InsightPillTabs(
            labels: labels,
            selected: _likesTab,
            onChanged: (i) => setState(() => _likesTab = i),
          ),
          const SizedBox(height: 20),
          if (_likesTab == 2 && showDislikes) ...[
            Text(
              '${formatFull(d.dislikes.total)} viewers watched but didn\'t like',
              style: TextStyle(
                  color: InsightsPalette.muted(context), fontSize: 13),
            ),
            const SizedBox(height: 14),
            InsightBarList(buckets: d.dislikes.byGender),
          ] else if (!isAgeTab && buckets.isNotEmpty)
            _genderDonut(context, buckets)
          else
            InsightBarList(buckets: buckets),
        ],
      ),
    );
  }

  Widget _genderDonut(BuildContext context, List<InsightBucket> buckets) {
    const colors = [
      InsightsPalette.primary,
      InsightsPalette.secondary,
      InsightsPalette.tertiary,
      Color(0xFF14B8A6),
    ];
    final total = buckets.fold<num>(0, (s, b) => s + b.value);
    return InsightDonut(
      size: 160,
      centerValue: formatCompact(total),
      centerLabel: 'Likes',
      segments: [
        for (var i = 0; i < buckets.length && i < 4; i++)
          DonutSegment(prettyLabel(buckets[i].label), buckets[i].value,
              colors[i]),
      ],
    );
  }

  // ── Comments ─────────────────────────────────────────────────────────────

  Widget _buildComments(BuildContext context, ContentInsights d) {
    return InsightsSection(
      title: 'Comments',
      trailing: Text(formatFull(d.commentsTotal),
          style: TextStyle(
              color: InsightsPalette.fg(context),
              fontSize: 17,
              fontWeight: FontWeight.w700)),
      child: d.recentComments.isEmpty
          ? const InsightEmpty(text: 'No comments yet')
          : Column(
              children: [
                for (final c in d.recentComments) _commentTile(context, c),
              ],
            ),
    );
  }

  Widget _commentTile(BuildContext context, InsightComment c) {
    final initial = c.username.isNotEmpty ? c.username[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: c.avatarUrl.isEmpty
                ? Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        gradient: InsightsPalette.chartGradient),
                    child: Text(initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  )
                : InsightThumb(
                    url: c.avatarUrl,
                    headers: _headers,
                    width: 34,
                    height: 34,
                    radius: 17,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: c.username.isEmpty ? 'user' : c.username,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(text: c.text),
                  ]),
                  style: TextStyle(
                      color: InsightsPalette.fg(context),
                      fontSize: 14,
                      height: 1.35),
                ),
                if (c.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(_timeAgo(c.createdAt!),
                      style: TextStyle(
                          color: InsightsPalette.muted(context),
                          fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inDays >= 7) return '${d.inDays ~/ 7}w';
    if (d.inDays >= 1) return '${d.inDays}d';
    if (d.inHours >= 1) return '${d.inHours}h';
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return 'now';
  }

  Widget _buildSkeleton(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
            child: InsightSkeleton(height: 170, width: 110, radius: 12)),
        const SizedBox(height: 14),
        const Center(child: InsightSkeleton(height: 12, width: 160)),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
              4, (_) => const InsightSkeleton(height: 40, width: 40)),
        ),
        const SizedBox(height: 30),
        for (var i = 0; i < 5; i++) ...[
          const InsightSkeleton(height: 16),
          const SizedBox(height: 18),
        ],
        const SizedBox(height: 10),
        const InsightSkeleton(height: 180, radius: 16),
      ],
    );
  }
}
