import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerStrip extends StatefulWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onChanged;
  final VoidCallback onOpenFullPicker;

  const ColorPickerStrip({
    super.key,
    required this.colors,
    required this.selected,
    required this.onChanged,
    required this.onOpenFullPicker,
  });

  @override
  State<ColorPickerStrip> createState() => _ColorPickerStripState();

  static Future<Color?> openFullPicker(
    BuildContext context,
    Color initial,
  ) async {
    Color temp = initial;
    return showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: initial,
              onColorChanged: (c) => temp = c,
              enableAlpha: false,
              displayThumbColor: true,
              portraitOnly: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(temp),
              child: const Text('Select', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

class _ColorPickerStripState extends State<ColorPickerStrip> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<List<Color>> _buildPages(List<Color> colors) {
    if (colors.isEmpty) return [const []];
    const perPage = 9;
    final pages = <List<Color>>[];
    for (var i = 0; i < colors.length; i += perPage) {
      pages.add(colors.sublist(i, math.min(i + perPage, colors.length)));
    }
    while (pages.length < 3) {
      pages.add(const []);
    }
    return pages.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(widget.colors);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 32,
          child: PageView.builder(
            padEnds: false,
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (context, index) {
              final colors = pages[index];
              return Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: widget.onOpenFullPicker,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const SweepGradient(
                          colors: [
                            Colors.red,
                            Colors.yellow,
                            Colors.green,
                            Colors.cyan,
                            Colors.blue,
                            Colors.purple,
                            Colors.red,
                          ],
                        ),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ...colors.map((c) {
                    final isSelected = c.value == widget.selected.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => widget.onChanged(c),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.white,
                              width: isSelected ? 1.8 : 1.2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final active = i == _pageIndex;
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white38,
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
    );
  }
}
