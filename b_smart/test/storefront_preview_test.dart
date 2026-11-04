import 'dart:io';

import 'package:b_smart/models/store_profile.dart';
import 'package:b_smart/screens/store/store_profile_page.dart';
import 'package:b_smart/screens/store/store_profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

const _profile = StoreProfile(
  storeName: 'Meera Design Studio',
  storeType: 'Personal Store',
  about: 'Hand-painted home decor, custom murals and styling for small spaces '
      'across Mumbai.',
  serviceAreas: ['Mumbai', 'Thane', 'Navi Mumbai', 'Online'],
  languages: ['English', 'Hindi', 'Marathi'],
  trustBadges: ['Verified', 'Top rated', 'Fast delivery'],
  followersCount: 1284,
  followingCount: 37,
  productCount: 24,
  serviceCount: 6,
  memberSince: 'Mar 2024',
);

void main() {
  setUpAll(() async {
    await _loadFont(
      'Montserrat',
      '/System/Library/Fonts/Supplemental/Arial.ttf',
    );
    await _loadFont('Lucide', 'assets/fonts/lucide.ttf');
  });

  testWidgets('storefront profile preview', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => <String>['wifi'],
    );

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Seed the cache so the page renders the loaded state, not a spinner.
    StoreProfileState.instance.debugSeed(
      'seller-1',
      _profile,
      asSelf: true,
    );

    await tester.pumpWidget(
      const MaterialApp(home: StoreProfilePage(ownerUserId: 'seller-1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Meera Design Studio'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);

    await expectLater(
      find.byType(StoreProfilePage),
      matchesGoldenFile('goldens/storefront_profile.png'),
    );
  });

  testWidgets('storefront edit preview', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: StoreProfileEditPage(initial: _profile)),
    );
    // Text fields blink their caret forever, so settle is not an option here.
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(StoreProfileEditPage),
      matchesGoldenFile('goldens/storefront_edit.png'),
    );
  });
}
