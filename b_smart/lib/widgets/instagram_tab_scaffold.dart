import 'dart:ui';

import 'package:flutter/material.dart';

class InstagramTabScaffold extends StatefulWidget {
  final List<Widget> pages;
  final List<String> labels;
  final ValueChanged<int>? onTabChanged;
  final int initialIndex;
  final double Function(int index)? bottomPaddingForIndex;
  final Color Function(int index)? pillBackgroundColorForIndex;

  const InstagramTabScaffold({
    super.key,
    required this.pages,
    this.labels = const ['POST', 'STORY', 'REEL', 'LIVE'],
    this.onTabChanged,
    this.initialIndex = 0,
    this.bottomPaddingForIndex,
    this.pillBackgroundColorForIndex,
  }) : assert(pages.length == 4, 'InstagramTabScaffold requires exactly 4 pages.'),
       assert(labels.length == 4, 'InstagramTabScaffold requires exactly 4 labels.'),
       assert(initialIndex >= 0 && initialIndex < 4, 'initialIndex must be between 0 and 3.');

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
  static const double _pillItemPadH = 4;
  static const double _pillItemPadV = 2;
  static const double _pillItemMarginH = 1;
  static const double _pillBorderWidth = 1;
  static const double _pillFontSize = 14;
  static const double _pillLetterSpacing = 1.2;
  static const double _pillHeight = 36;

  late final PageController _controller;
  double _pageValue = 0.0;
  int _currentIndex = 0;
  bool _isDragging = false;

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
      onHorizontalDragStart: (_) {
        _isDragging = true;
      },
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
        _isDragging = false;
        _controller.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
        widget.onTabChanged?.call(targetPage);
      },
      child: Stack(
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: widget.bottomPaddingForIndex?.call(_currentIndex) ?? 8,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final labels = widget.labels;
                    final centers = <double>[];
                    final textWidths = <double>[];
                    double totalWidth = 0;
                    for (var i = 0; i < labels.length; i++) {
                      final textStyle = TextStyle(
                        fontSize: _pillFontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: _pillLetterSpacing,
                      );
                      final textWidth = _measureTextWidth(labels[i], textStyle);
                      textWidths.add(textWidth);
                      final itemWidth = textWidth +
                          (_pillItemPadH * 2) +
                          (_pillItemMarginH * 2) +
                          (_pillBorderWidth * 2);
                      centers.add(totalWidth + (itemWidth / 2));
                      totalWidth += itemWidth;
                    }
                    totalWidth += _pillOuterPadH * 2;
                    for (var i = 0; i < centers.length; i++) {
                      centers[i] += _pillOuterPadH;
                    }

                    return SizedBox(
                      height: _pillHeight,
                      child: Stack(
                        children: [
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              final pagePos = (_controller.hasClients
                                      ? (_controller.page ?? _currentIndex.toDouble())
                                      : _pageValue)
                                  .clamp(0.0, (labels.length - 1).toDouble());
                              final lower = pagePos.floor().clamp(0, labels.length - 1);
                              final upper = pagePos.ceil().clamp(0, labels.length - 1);
                              final t = pagePos - lower;
                              final activeCenter =
                                  lerpDouble(centers[lower], centers[upper], t) ?? centers[lower];
                              final selectedIndex = pagePos.round().clamp(0, labels.length - 1);

                              final maxWidth = constraints.maxWidth;
                              double left = (maxWidth / 2) - activeCenter;
                              final minLeft = 0.0;
                              final maxLeft = (maxWidth - totalWidth).clamp(0.0, double.infinity);
                              left = left.clamp(minLeft, maxLeft);

                              final bgColor = widget.pillBackgroundColorForIndex?.call(_currentIndex) ??
                                  Colors.black.withValues(alpha: 0.6);
                              final hasBackground = bgColor.alpha > 0;

                              final pill = Container(
                                color: bgColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _pillOuterPadH,
                                  vertical: _pillOuterPadV,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(labels.length, (index) {
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
                                        margin: const EdgeInsets.symmetric(horizontal: _pillItemMarginH),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Opacity(
                                          opacity: _opacityForIndex(pagePos, index),
                                          child: SizedBox(
                                            width: textWidths[index],
                                            child: Center(
                                              child: Text(
                                                labels[index],
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : Colors.white70,
                                                  fontSize: _pillFontSize,
                                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                  letterSpacing: _pillLetterSpacing,
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
                                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                        child: pill,
                                      )
                                    : pill,
                              );

                              return Positioned(
                                left: left,
                                bottom: 0,
                                child: pillChild,
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

class _AlwaysScrollablePageScrollPhysics extends PageScrollPhysics {
  const _AlwaysScrollablePageScrollPhysics()
      : super(parent: const AlwaysScrollableScrollPhysics());

  @override
  _AlwaysScrollablePageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _AlwaysScrollablePageScrollPhysics();
  }
}
