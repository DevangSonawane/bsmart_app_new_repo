import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/insights_models.dart';
import '../../theme/design_tokens.dart';
import '../safe_network_image.dart';
import '../../utils/url_helper.dart';

/// Shared look & feel for the Insights screens — modelled on Instagram's
/// professional dashboard: flat sections, bold headings, hairline dividers,
/// big centered numbers and soft gradient charts.
class InsightsPalette {
  static const Color primary = Color(0xFF7B5CFF); // chart purple
  static const Color secondary = DesignTokens.instaPink;
  static const Color tertiary = DesignTokens.instaOrange;
  static const Color positive = Color(0xFF22C55E);
  static const Color negative = Color(0xFFEF4444);

  static const LinearGradient chartGradient = LinearGradient(
    colors: [Color(0xFF7B5CFF), DesignTokens.instaPink],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static Color muted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58);
  static Color faint(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
  static Color fg(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  static Color card(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF161616) : const Color(0xFFF5F5F7);
  }
}

final NumberFormat _fullFmt = NumberFormat.decimalPattern();

String formatCompact(num value) {
  final v = value.abs();
  String trim(double n) =>
      n.toStringAsFixed(n >= 100 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '');
  final sign = value < 0 ? '-' : '';
  if (v >= 1000000000) return '$sign${trim(v / 1000000000)}B';
  if (v >= 1000000) return '$sign${trim(v / 1000000)}M';
  if (v >= 10000) return '$sign${trim(v / 1000)}K';
  return _fullFmt.format(value);
}

String formatFull(num value) => _fullFmt.format(value);

String formatWatchTime(int ms) {
  if (ms <= 0) return '0s';
  final d = Duration(milliseconds: ms);
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}

String prettyLabel(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return 'Unknown';
  return s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout primitives
// ─────────────────────────────────────────────────────────────────────────────

class InsightsSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final bool showDivider;

  const InsightsSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 22, 16, 22),
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDivider)
          Divider(height: 1, thickness: 0.6, color: InsightsPalette.faint(context)),
        Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: InsightsPalette.fg(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: InsightsPalette.muted(context),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

/// "Label ........ value  (+12%)" — the classic Instagram overview row.
class InsightMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final double? delta;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool emphasize;

  const InsightMetricRow({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.icon,
    this.onTap,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = InsightsPalette.fg(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: InsightsPalette.muted(context)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (delta != null) ...[
              const SizedBox(width: 8),
              DeltaText(delta: delta!),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight,
                  size: 18, color: InsightsPalette.muted(context)),
            ],
          ],
        ),
      ),
    );
  }
}

class DeltaText extends StatelessWidget {
  final double delta;
  final double fontSize;
  const DeltaText({super.key, required this.delta, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final rounded = double.parse(delta.toStringAsFixed(1));
    final color = rounded > 0
        ? InsightsPalette.positive
        : rounded < 0
            ? InsightsPalette.negative
            : InsightsPalette.muted(context);
    final sign = rounded > 0 ? '+' : '';
    final txt = rounded.abs() >= 1000
        ? '$sign${formatCompact(rounded)}%'
        : '$sign${rounded.toStringAsFixed(rounded.abs() >= 100 ? 0 : 1)}%';
    return Text(
      txt,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Big centered hero number — e.g. "12.4K / Views".
class InsightHeroNumber extends StatelessWidget {
  final String value;
  final String label;
  final double? delta;
  final String? deltaSuffix;

  const InsightHeroNumber({
    super.key,
    required this.value,
    required this.label,
    this.delta,
    this.deltaSuffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: InsightsPalette.fg(context),
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: InsightsPalette.muted(context), fontSize: 14)),
        if (delta != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DeltaText(delta: delta!),
              if (deltaSuffix != null)
                Text(' $deltaSuffix',
                    style: TextStyle(
                        color: InsightsPalette.muted(context), fontSize: 13)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Row of icon + count pairs under the post thumbnail.
class EngagementIconRow extends StatelessWidget {
  final List<(IconData, int)> items;
  const EngagementIconRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (icon, count) in items)
          Column(
            children: [
              Icon(icon, size: 24, color: InsightsPalette.fg(context)),
              const SizedBox(height: 6),
              Text(
                formatCompact(count),
                style: TextStyle(
                  color: InsightsPalette.fg(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Small pill tab selector (Gender / Age / Locations, All / Reels / …).
class InsightPillTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const InsightPillTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fg = InsightsPalette.fg(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: i == selected ? fg : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: i == selected
                          ? fg
                          : fg.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == selected
                          ? Theme.of(context).scaffoldBackgroundColor
                          : fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Honest "not tracked yet" note, used where the data model can't back a
/// metric (instead of showing invented numbers).
class InsightNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const InsightNote(
      {super.key, required this.text, this.icon = LucideIcons.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: InsightsPalette.card(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: InsightsPalette.muted(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: InsightsPalette.muted(context),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InsightEmpty extends StatelessWidget {
  final String text;
  const InsightEmpty({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style:
              TextStyle(color: InsightsPalette.muted(context), fontSize: 13.5),
        ),
      ),
    );
  }
}

class InsightErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const InsightErrorState(
      {super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: InsightsPalette.card(context),
              ),
              child: Icon(LucideIcons.chartNoAxesColumn,
                  size: 28, color: InsightsPalette.muted(context)),
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load insights',
              style: TextStyle(
                color: InsightsPalette.fg(context),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: InsightsPalette.muted(context), fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: InsightsPalette.fg(context),
                foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing skeleton block for loading states.
class InsightSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const InsightSkeleton(
      {super.key, required this.height, this.width, this.radius = 10});

  @override
  State<InsightSkeleton> createState() => _InsightSkeletonState();
}

class _InsightSkeletonState extends State<InsightSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = InsightsPalette.fg(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.05 + 0.05 * _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class InsightThumb extends StatelessWidget {
  final String url;
  final Map<String, String>? headers;
  final double width;
  final double height;
  final double radius;
  final bool isReel;

  const InsightThumb({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.headers,
    this.radius = 8,
    this.isReel = false,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: InsightsPalette.card(context),
      alignment: Alignment.center,
      child: Icon(isReel ? LucideIcons.clapperboard : LucideIcons.image,
          size: math.min(width, height) * 0.3,
          color: InsightsPalette.muted(context)),
    );
    final trimmed = url.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: trimmed.isEmpty
            ? placeholder
            : SafeNetworkImage(
                url: trimmed,
                headers: UrlHelper.shouldAttachAuthHeader(trimmed)
                    ? headers
                    : null,
                fit: BoxFit.cover,
                width: width,
                height: height,
                placeholder: placeholder,
                errorWidget: placeholder,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Charts
// ─────────────────────────────────────────────────────────────────────────────

/// Horizontal percentage bars — used for gender, age and location breakdowns.
class InsightBarList extends StatelessWidget {
  final List<InsightBucket> buckets;
  final int maxItems;
  final bool showPercent;

  const InsightBarList({
    super.key,
    required this.buckets,
    this.maxItems = 6,
    this.showPercent = true,
  });

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const InsightEmpty(text: 'Not enough data yet');
    }
    final total = buckets.fold<num>(0, (s, b) => s + b.value);
    final shown = buckets.take(maxItems).toList();
    final maxV = shown.map((b) => b.value).reduce(math.max);
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _BarRow(
              label: prettyLabel(shown[i].label),
              valueText: showPercent
                  ? '${(shown[i].value / total * 100).toStringAsFixed(1)}%'
                  : formatCompact(shown[i].value),
              fraction: maxV == 0 ? 0 : shown[i].value / maxV,
              index: i,
            ),
          ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double fraction;
  final int index;

  const _BarRow({
    required this.label,
    required this.valueText,
    required this.fraction,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: InsightsPalette.fg(context), fontSize: 14)),
            ),
            Text(valueText,
                style: TextStyle(
                    color: InsightsPalette.fg(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 7),
        LayoutBuilder(builder: (context, c) {
          return Stack(
            children: [
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color: InsightsPalette.faint(context),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction.clamp(0, 1).toDouble()),
                duration: Duration(milliseconds: 500 + index * 60),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Container(
                  height: 7,
                  width: c.maxWidth * v,
                  decoration: BoxDecoration(
                    gradient: InsightsPalette.chartGradient,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class DonutSegment {
  final String label;
  final num value;
  final Color color;
  const DonutSegment(this.label, this.value, this.color);
}

/// Instagram-style donut with a centered total and a legend underneath.
class InsightDonut extends StatelessWidget {
  final List<DonutSegment> segments;
  final String centerValue;
  final String centerLabel;
  final double size;

  const InsightDonut({
    super.key,
    required this.segments,
    required this.centerValue,
    required this.centerLabel,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<num>(0, (s, e) => s + e.value);
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              painter: _DonutPainter(
                segments: segments,
                progress: t,
                track: InsightsPalette.faint(context),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(centerValue,
                        style: TextStyle(
                            color: InsightsPalette.fg(context),
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    Text(centerLabel,
                        style: TextStyle(
                            color: InsightsPalette.muted(context),
                            fontSize: 12.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (final s in segments)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: s.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s.label,
                      style: TextStyle(
                          color: InsightsPalette.fg(context), fontSize: 14)),
                ),
                Text(
                  total == 0
                      ? '0%'
                      : '${(s.value / total * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: InsightsPalette.fg(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    formatCompact(s.value),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: InsightsPalette.muted(context), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double progress;
  final Color track;

  _DonutPainter(
      {required this.segments, required this.progress, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    final total = segments.fold<num>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    var start = -math.pi / 2;
    final sweepTotal = math.pi * 2 * progress;
    const gap = 0.04;
    for (final s in segments) {
      if (s.value <= 0) continue;
      final sweep = sweepTotal * (s.value / total);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = s.color;
      final visible = segments.where((e) => e.value > 0).length > 1
          ? math.max(0.0, sweep - gap)
          : sweep;
      canvas.drawArc(rect, start + gap / 2, visible, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.segments != segments;
}

class LineSeries {
  final List<double> values;
  final Color color;
  final bool dashed;
  final bool filled;
  final String label;

  const LineSeries({
    required this.values,
    required this.color,
    required this.label,
    this.dashed = false,
    this.filled = true,
  });
}

/// Smooth area/line chart with optional comparison series, x labels and a
/// touch scrubber that shows the value under the finger.
class InsightLineChart extends StatefulWidget {
  final List<LineSeries> series;
  final List<String> xLabels;
  final double height;
  final double? maxY;
  final String Function(double v) formatY;
  final String Function(int index)? tooltipTitle;

  const InsightLineChart({
    super.key,
    required this.series,
    required this.xLabels,
    required this.formatY,
    this.height = 190,
    this.maxY,
    this.tooltipTitle,
  });

  @override
  State<InsightLineChart> createState() => _InsightLineChartState();
}

class _InsightLineChartState extends State<InsightLineChart> {
  int? _touched;

  int get _len => widget.series.isEmpty
      ? 0
      : widget.series.map((s) => s.values.length).reduce(math.max);

  void _updateTouch(Offset local, double width) {
    if (_len < 2) return;
    const left = 0.0;
    const right = 36.0;
    final usable = width - left - right;
    final idx = ((local.dx - left) / usable * (_len - 1)).round();
    setState(() => _touched = idx.clamp(0, _len - 1));
  }

  @override
  Widget build(BuildContext context) {
    final fg = InsightsPalette.fg(context);
    final labelStyle =
        TextStyle(color: InsightsPalette.muted(context), fontSize: 11);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 34,
          child: _touched == null
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    if (widget.tooltipTitle != null)
                      Text(widget.tooltipTitle!(_touched!),
                          style: TextStyle(
                              color: InsightsPalette.muted(context),
                              fontSize: 12.5)),
                    const Spacer(),
                    for (final s in widget.series)
                      if (_touched! < s.values.length)
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Row(
                            children: [
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: s.color,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              Text(widget.formatY(s.values[_touched!]),
                                  style: TextStyle(
                                      color: fg,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                  ],
                ),
        ),
        LayoutBuilder(builder: (context, c) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _updateTouch(d.localPosition, c.maxWidth),
            onPanUpdate: (d) => _updateTouch(d.localPosition, c.maxWidth),
            onPanEnd: (_) => setState(() => _touched = null),
            onPanCancel: () => setState(() => _touched = null),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => CustomPaint(
                size: Size(c.maxWidth, widget.height),
                painter: _LinePainter(
                  series: widget.series,
                  progress: t,
                  maxY: widget.maxY,
                  grid: InsightsPalette.faint(context),
                  labelColor: InsightsPalette.muted(context),
                  formatY: widget.formatY,
                  touched: _touched,
                  bg: Theme.of(context).scaffoldBackgroundColor,
                  fontFamily: DefaultTextStyle.of(context).style.fontFamily ??
                      Theme.of(context).textTheme.bodyMedium?.fontFamily,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        if (widget.xLabels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 36),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final l in widget.xLabels) Text(l, style: labelStyle),
              ],
            ),
          ),
        if (widget.series.length > 1) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final s in widget.series)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 3,
                      decoration: BoxDecoration(
                        color: s.dashed ? s.color.withValues(alpha: 0.6) : s.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(s.label,
                        style: TextStyle(
                            color: InsightsPalette.muted(context),
                            fontSize: 12.5)),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<LineSeries> series;
  final double progress;
  final double? maxY;
  final Color grid;
  final Color labelColor;
  final Color bg;
  final String Function(double) formatY;
  final int? touched;
  final String? fontFamily;

  _LinePainter({
    this.fontFamily,
    required this.series,
    required this.progress,
    required this.maxY,
    required this.grid,
    required this.labelColor,
    required this.formatY,
    required this.touched,
    required this.bg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const rightPad = 36.0;
    const topPad = 6.0;
    const bottomPad = 4.0;
    final w = size.width - rightPad;
    final h = size.height - topPad - bottomPad;

    var top = maxY ??
        series
            .expand((s) => s.values)
            .fold<double>(0, (m, v) => math.max(m, v));
    if (top <= 0) top = 1;
    if (maxY == null) top = _niceCeil(top);

    // Grid + y labels.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = topPad + h - h * i / 3;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
            text: formatY(top * i / 3),
            style: TextStyle(
                color: labelColor, fontSize: 10.5, fontFamily: fontFamily)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w + 6, y - tp.height / 2));
    }

    for (final s in series) {
      final n = s.values.length;
      if (n == 0) continue;
      final pts = <Offset>[
        for (var i = 0; i < n; i++)
          Offset(
            n == 1 ? w / 2 : w * i / (n - 1),
            topPad + h - h * (s.values[i] / top).clamp(0.0, 1.0) * progress,
          ),
      ];
      final path = _smooth(pts);

      if (s.filled) {
        final fill = Path.from(path)
          ..lineTo(pts.last.dx, topPad + h)
          ..lineTo(pts.first.dx, topPad + h)
          ..close();
        canvas.drawPath(
          fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                s.color.withValues(alpha: 0.28),
                s.color.withValues(alpha: 0.0),
              ],
            ).createShader(Rect.fromLTWH(0, topPad, w, h)),
        );
      }

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.dashed ? 2 : 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = s.dashed ? s.color.withValues(alpha: 0.65) : s.color;
      if (s.dashed) {
        _drawDashed(canvas, path, linePaint);
      } else {
        canvas.drawPath(path, linePaint);
      }

      if (touched != null && touched! < n) {
        final p = pts[touched!];
        canvas.drawLine(
          Offset(p.dx, topPad),
          Offset(p.dx, topPad + h),
          Paint()
            ..color = labelColor.withValues(alpha: 0.4)
            ..strokeWidth = 1,
        );
        canvas.drawCircle(p, 6, Paint()..color = bg);
        canvas.drawCircle(p, 4.5, Paint()..color = s.color);
      }
    }
  }

  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length < 3) {
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      return path;
    }
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      const k = 0.18;
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) * k, p1.dy + (p2.dy - p0.dy) * k);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) * k, p2.dy - (p3.dy - p1.dy) * k);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  double _niceCeil(double v) {
    if (v <= 6) return v <= 3 ? 3 : 6;
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final f = v / exp;
    const steps = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0];
    final nice = steps.firstWhere((x) => f <= x, orElse: () => 10.0);
    return nice * exp;
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.progress != progress || old.touched != touched || old.series != series;
}

/// Vertical bars for one day's 24 hours — Instagram's "Most active times".
class InsightHourBars extends StatelessWidget {
  final List<int> values; // length 24
  final int? highlight;
  final double height;

  const InsightHourBars({
    super.key,
    required this.values,
    this.highlight,
    this.height = 140,
  });

  String _hourLabel(int h) {
    if (h == 0) return '12a';
    if (h == 12) return '12p';
    return h < 12 ? '${h}a' : '${h - 12}p';
  }

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 0 : values.reduce(math.max);
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var h = 0; h < 24; h++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('$h-${values[h]}'),
                      tween: Tween(
                          begin: 0,
                          end: maxV == 0 ? 0 : values[h] / maxV),
                      duration: Duration(milliseconds: 380 + h * 14),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Container(
                        height: math.max(3, height * v),
                        decoration: BoxDecoration(
                          gradient: h == highlight
                              ? const LinearGradient(
                                  colors: [
                                    DesignTokens.instaPink,
                                    InsightsPalette.primary
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : null,
                          color: h == highlight
                              ? null
                              : InsightsPalette.primary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final h in const [0, 6, 12, 18, 23])
              Text(_hourLabel(h),
                  style: TextStyle(
                      color: InsightsPalette.muted(context), fontSize: 11)),
          ],
        ),
      ],
    );
  }
}
