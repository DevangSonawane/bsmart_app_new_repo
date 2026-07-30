import 'dart:ui';

import 'package:flutter/material.dart';

class InstagramTabScaffold extends StatefulWidget {
  final List<Widget> pages;
  final List<String> labels;
  final ValueChanged<int>? onTabChanged;
  final int initialIndex;
  final double Function(int index)? bottomPaddingForIndex;
  final Color Function(int index)? pillBackgroundColorForIndex;
  final bool Function(int index)? pillVisibleForIndex;

  const InstagramTabScaffold({
    super.key,
    required this.pages,
    this.labels = const ['Moments', 'Glimpses', 'bSparks', 'Buzz'],
    this.onTabChanged,
    this.initialIndex = 0,
    this.bottomPaddingForIndex,
    this.pillBackgroundColorForIndex,
    this.pillVisibleForIndex,
  })  : assert(pages.length == 4,
            'InstagramTabScaffold requires exactly 4 pages.'),
        assert(labels.length == 4,
            'InstagramTabScaffold requires exactly 4 labels.'),
        assert(initialIndex >= 0 && initialIndex < 4,
            'initialIndex must be between 0 and 3.');

  @override
  State<InstagramTabScaffold> createState() => _InstagramTabScaffoldState();
}

class _InstagramTabScaffoldState extends State<InstagramTabScaffold> {
  static const double _minOpacity = 0.5;
  static const double _maxOpacity = 1.0;
  static const Duration _tapDuration = Duration(milliseconds: 200);
  static const Duration _pillAnimDuration = Duration(milliseconds: 420);
  static const double _pillOuterPadH = 8;
  static const double _pillOuterPadV = 6;
  static const double _pillItemPadH = 2;
  static const double _pillItemPadV = 2;
  static const double _pillItemMarginH = 0;
  static const double _pillBorderWidth = 1;
  static const double _pillFontSize = 13.5;
  static const double _pillLetterSpacing = 0.7;
  static const double _pillHeight = 36;

  late final PageController _controller;
  double _pageValue = 0.0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
    _pageValue = widget.initialIndex.toDouble();
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    _controller.animateToPage(
      index,
      duration: _tapDuration,
      curve: Curves.easeInOut,
    );
  }

  double _opacityForIndex(double pagePos, int index) {
    final distance = (pagePos - index).abs().clamp(0.0, 1.0);
    final t = 1.0 - distance;
    return _minOpacity + (_maxOpacity - _minOpacity) * t;
  }

  double _measureTextWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        if (!_controller.hasClients) return;
        _controller.jumpTo(
          (_controller.offset - details.delta.dx)
              .clamp(0.0, _controller.position.maxScrollExtent),
        );
        _pageValue = _controller.page ?? _currentIndex.toDouble();
      },
      onHorizontalDragEnd: (details) {
        if (!_controller.hasClients) return;
        final velocity = details.primaryVelocity ?? 0;
        int targetPage;
        if (velocity < -300) {
          targetPage = (_currentIndex + 1).clamp(0, widget.pages.length - 1);
        } else if (velocity > 300) {
          targetPage = (_currentIndex - 1).clamp(0, widget.pages.length - 1);
        } else {
          targetPage = _pageValue.round().clamp(0, widget.pages.length - 1);
        }
        _controller.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
        widget.onTabChanged?.call(targetPage);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.pages.length,
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _pageValue = index.toDouble();
              });
              widget.onTabChanged?.call(index);
            },
            itemBuilder: (context, index) => widget.pages[index],
          ),
          if (widget.pillVisibleForIndex?.call(_currentIndex) ?? true)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        widget.bottomPaddingForIndex?.call(_currentIndex) ?? 8,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final labels = widget.labels;
                      final maxWidth = constraints.maxWidth;
                      const textSafetyWidth = 2.0;
                      const baseTextStyle = TextStyle(
                        fontSize: _pillFontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: _pillLetterSpacing,
                      );
                      final labelWidths = <double>[];
                      final itemWidths = <double>[];
                      final centers = <double>[];
                      var totalWidth = _pillOuterPadH * 2;
                      for (var i = 0; i < labels.length; i++) {
                        final textWidth =
                            _measureTextWidth(labels[i], baseTextStyle);
                        final labelWidth = textWidth + textSafetyWidth;
                        final itemWidth = labelWidth +
                            (_pillItemPadH * 2) +
                            (_pillItemMarginH * 2) +
                            (_pillBorderWidth * 2);
                        labelWidths.add(labelWidth);
                        itemWidths.add(itemWidth);
                        centers.add(totalWidth + (itemWidth / 2));
                        totalWidth += itemWidth;
                      }
                      final scale = totalWidth > maxWidth
                          ? (maxWidth / totalWidth).clamp(0.0, 1.0)
                          : 1.0;
                      final effectiveFontSize =
                          (_pillFontSize * scale).clamp(11.0, _pillFontSize);
                      final effectiveLetterSpacing =
                          (_pillLetterSpacing * scale)
                              .clamp(0.0, _pillLetterSpacing);
                      final scaledWidth = totalWidth * scale;

                      return SizedBox(
                        height: _pillHeight + 6,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) {
                                final pagePos = (_controller.hasClients
                                        ? (_controller.page ??
                                            _currentIndex.toDouble())
                                        : _pageValue)
                                    .clamp(0.0, (labels.length - 1).toDouble());
                                final lower =
                                    pagePos.floor().clamp(0, labels.length - 1);
                                final upper =
                                    pagePos.ceil().clamp(0, labels.length - 1);
                                final t = pagePos - lower;
                                final activeCenter = lerpDouble(
                                        centers[lower], centers[upper], t) ??
                                    centers[lower];
                                final selectedIndex =
                                    pagePos.round().clamp(0, labels.length - 1);

                                double left =
                                    (maxWidth / 2) - (activeCenter * scale);
                                const minLeft = 0.0;
                                final maxLeft = (maxWidth - scaledWidth)
                                    .clamp(0.0, double.infinity);
                                left = left.clamp(minLeft, maxLeft);

                                final bgColor = widget
                                        .pillBackgroundColorForIndex
                                        ?.call(_currentIndex) ??
                                    Colors.black.withValues(alpha: 0.6);
                                final hasBackground = bgColor.a > 0;

                                final pill = Container(
                                  color: bgColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: _pillOuterPadH,
                                    vertical: _pillOuterPadV,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children:
                                        List.generate(labels.length, (index) {
                                      final isSelected = index == selectedIndex;
                                      return GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTap: () => _onTap(index),
                                        child: AnimatedContainer(
                                          duration: _pillAnimDuration,
                                          curve: Curves.easeInOutCubic,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: _pillItemPadH,
                                            vertical: _pillItemPadV,
                                          ),
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: _pillItemMarginH),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Opacity(
                                            opacity: _opacityForIndex(
                                                pagePos, index),
                                            child: SizedBox(
                                              width: labelWidths[index],
                                              child: Center(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    labels[index],
                                                    maxLines: 1,
                                                    softWrap: false,
                                                    overflow: TextOverflow.clip,
                                                    style: TextStyle(
                                                      color: isSelected
                                                          ? Colors.white
                                                          : Colors.white70,
                                                      fontSize: isSelected
                                                          ? effectiveFontSize +
                                                              0.9
                                                          : effectiveFontSize,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w900
                                                          : FontWeight.w500,
                                                      letterSpacing:
                                                          effectiveLetterSpacing,
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                );

                                final pillChild = ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: hasBackground
                                      ? BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 16, sigmaY: 16),
                                          child: pill,
                                        )
                                      : pill,
                                );

                                return Positioned(
                                  left: left,
                                  bottom: 3,
                                  child: Transform.scale(
                                    alignment: Alignment.topLeft,
                                    scale: scale,
                                    child: SizedBox(
                                      width: totalWidth,
                                      child: pillChild,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
