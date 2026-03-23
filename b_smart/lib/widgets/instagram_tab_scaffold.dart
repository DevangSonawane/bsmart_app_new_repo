import 'dart:ui';

import 'package:flutter/material.dart';

class InstagramTabScaffold extends StatefulWidget {
  final List<Widget> pages;
  final List<String> labels;
  final ValueChanged<int>? onTabChanged;
  final int initialIndex;

  const InstagramTabScaffold({
    super.key,
    required this.pages,
    this.labels = const ['POST', 'STORY', 'REEL', 'LIVE'],
    this.onTabChanged,
    this.initialIndex = 0,
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
    _controller.addListener(_handlePageScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePageScroll);
    _controller.dispose();
    super.dispose();
  }

  void _handlePageScroll() {
    if (_isDragging) return;
    final page = _controller.page;
    if (page == null) return;
    setState(() {
      _pageValue = page;
      _currentIndex = page.round().clamp(0, widget.labels.length - 1);
    });
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    _controller.animateToPage(
      index,
      duration: _tapDuration,
      curve: Curves.easeInOut,
    );
  }

  double _opacityForIndex(int index) {
    final distance = (_pageValue - index).abs().clamp(0.0, 1.0);
    final t = 1.0 - distance;
    return _minOpacity + (_maxOpacity - _minOpacity) * t;
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
        setState(() {
          _pageValue = _controller.page ?? _currentIndex.toDouble();
        });
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
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(widget.labels.length, (index) {
                            final isSelected = index == _currentIndex;
                            return GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => _onTap(index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Opacity(
                                  opacity: _opacityForIndex(index),
                                  child: Text(
                                    widget.labels[index],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
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

class _AlwaysScrollablePageScrollPhysics extends PageScrollPhysics {
  const _AlwaysScrollablePageScrollPhysics()
      : super(parent: const AlwaysScrollableScrollPhysics());

  @override
  _AlwaysScrollablePageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _AlwaysScrollablePageScrollPhysics();
  }
}
