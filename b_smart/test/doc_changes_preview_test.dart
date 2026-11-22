import 'dart:io';

import 'package:b_smart/screens/store/self_store_products_page.dart';
import 'package:b_smart/screens/store/self_store_services_manage_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _fr = '/Users/devangsonawane/tools/flutter/bin/cache/artifacts/material_fonts';
const _lucide =
    '/Users/devangsonawane/.pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.22/assets/lucide.ttf';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final bytes = await File(p).readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFont('Roboto', [
      '$_fr/Roboto-Regular.ttf',
      '$_fr/Roboto-Medium.ttf',
      '$_fr/Roboto-Bold.ttf',
      '$_fr/Roboto-Black.ttf',
    ]);
    const m = '/Users/devangsonawane/roast-room/app/public/brand/fonts';
    await _loadFont('Montserrat', [
      '$m/Montserrat-Regular.ttf',
      '$m/Montserrat-SemiBold.ttf',
      '$m/Montserrat-Bold.ttf',
    ]);
    // Text without an explicit font uses the test default; map it to a real font.
    for (final fam in ['FlutterTest', 'Ahem', '.SF UI Text', 'sans-serif']) {
      await _loadFont(fam, [
        '$m/Montserrat-Regular.ttf',
        '$m/Montserrat-SemiBold.ttf',
        '$m/Montserrat-Bold.ttf',
      ]);
    }
    await _loadFont('MaterialIcons', ['$_fr/MaterialIcons-Regular.otf']);
    await _loadFont('packages/lucide_icons_flutter/Lucide', [_lucide]);
    await _loadFont('Lucide', [_lucide]);
  });

  void tallView(WidgetTester tester, double height) {
    tester.view.physicalSize = Size(1170, height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('service form – pricing step', (tester) async {
    tallView(tester, 1900);
    await tester.pumpWidget(
        const MaterialApp(debugShowCheckedModeBanner: false, home: StoreAddServiceFlowScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // Fill a subservice: hours 0 + optional description.
    final hr = find.widgetWithText(TextField, 'Hr');
    if (hr.evaluate().isNotEmpty) await tester.enterText(hr.first, '0');
    final desc = find.widgetWithText(TextField, 'What this option includes…');
    if (desc.evaluate().isNotEmpty) {
      await tester.enterText(desc.first, 'Includes kitchen and 2 bathrooms');
    }
    await tester.pumpAndSettle();
    if (find.text('Flat price').evaluate().isNotEmpty) {
      await tester.tap(find.text('Flat price'));
      await tester.pumpAndSettle();
    }
    await expectLater(find.byType(StoreAddServiceFlowScreen),
        matchesGoldenFile('goldens/doc_service_pricing.png'));
  });

  testWidgets('product form – variants checkbox', (tester) async {
    tallView(tester, 1500);
    await tester.pumpWidget(
        const MaterialApp(debugShowCheckedModeBanner: false, home: StoreAddProductFlowScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(StoreAddProductFlowScreen),
        matchesGoldenFile('goldens/doc_product_variants_off.png'));
    await tester.ensureVisible(find.text('This product has variants'));
    await tester.tap(find.text('This product has variants'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(StoreAddProductFlowScreen),
        matchesGoldenFile('goldens/doc_product_variants_on.png'));
  });
}
