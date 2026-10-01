import 'package:b_smart/screens/store/shared/store_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the shared seller tab bar.
///
/// The underline used to be placed with a `FractionallySizedBox` alignment.
/// That cannot work: FSB sizes *itself* to `widthFactor * maxWidth` and then
/// aligns its child inside that shrunken box, so the indicator never left the
/// leftmost segment. These tests assert the indicator's real geometry.
void main() {
  /// Indicator geometry relative to the tab bar's own left edge, so the
  /// assertions do not depend on where the bar sits on the test surface.
  Future<(double, double)> indicatorBox(WidgetTester tester) async {
    final active = find.byKey(const ValueKey('store-underline-indicator'));
    expect(active, findsOneWidget);
    final bar = tester.getRect(find.byType(StoreUnderlineTabs));
    final rect = tester.getRect(active);
    return (rect.left - bar.left, rect.width);
  }

  Future<void> pumpTabs(
    WidgetTester tester, {
    required List<String> labels,
    required int selected,
    required ValueChanged<int> onSelected,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: StoreUnderlineTabs(
              tabs: labels,
              selectedIndex: selected,
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('two-tab indicator sits under the first tab', (tester) async {
    await pumpTabs(
      tester,
      labels: const ['Published', 'Drafts'],
      selected: 0,
      onSelected: (_) {},
    );
    final (left, width) = await indicatorBox(tester);
    expect(left, closeTo(0, 0.5));
    expect(width, closeTo(150, 0.5));
  });

  testWidgets('two-tab indicator moves to the second tab', (tester) async {
    await pumpTabs(
      tester,
      labels: const ['Published', 'Drafts'],
      selected: 1,
      onSelected: (_) {},
    );
    final (left, width) = await indicatorBox(tester);
    expect(left, closeTo(150, 0.5));
    expect(width, closeTo(150, 0.5));
  });

  testWidgets('three-tab indicator reaches the third tab', (tester) async {
    await pumpTabs(
      tester,
      labels: const ['Active', 'Drafts', 'Out of stock'],
      selected: 2,
      onSelected: (_) {},
    );
    final (left, width) = await indicatorBox(tester);
    expect(left, closeTo(200, 0.5));
    expect(width, closeTo(100, 0.5));
  });

  testWidgets('tapping a tab reports its index', (tester) async {
    var picked = -1;
    await pumpTabs(
      tester,
      labels: const ['Published', 'Drafts'],
      selected: 0,
      onSelected: (i) => picked = i,
    );
    await tester.tap(find.text('Drafts'));
    await tester.pump();
    expect(picked, 1);
  });

  testWidgets('an out-of-range index clamps instead of overflowing',
      (tester) async {
    await pumpTabs(
      tester,
      labels: const ['Published', 'Drafts'],
      selected: 7,
      onSelected: (_) {},
    );
    final (left, width) = await indicatorBox(tester);
    expect(left, closeTo(150, 0.5));
    expect(width, closeTo(150, 0.5));
  });

  _distanceGroup();
}
/// Geometry checks that keep every underlined tab row in the app at the same
/// text-to-underline distance as My Products.
void _distanceGroup() {
  group('label to underline distance', () {
    Future<double> gap(WidgetTester tester, List<String> labels) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StoreUnderlineTabs(
                tabs: labels,
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ));
      final label = tester.getRect(find.text(labels.first));
      final line = tester.getRect(
          find.byKey(const ValueKey('store-underline-indicator')));
      return line.top - label.bottom;
    }

    testWidgets('is the same for two, three and four tabs', (tester) async {
      final two = await gap(tester, const ['Published', 'Drafts']);
      final three = await gap(tester, const ['A', 'B', 'C']);
      final four = await gap(tester, const ['A', 'B', 'C', 'D']);
      expect(three, closeTo(two, 0.5));
      expect(four, closeTo(two, 0.5));
    });

    testWidgets('underline sits just under the text, not far below it',
        (tester) async {
      // My Products renders at ~9px. The previous Spacer-driven layout pushed
      // the underline to the bottom of a taller box, leaving ~17px.
      final d = await gap(tester, const ['Published', 'Drafts']);
      expect(d, closeTo(9, 1));
      expect(d, lessThan(12));
    });
  });
}
