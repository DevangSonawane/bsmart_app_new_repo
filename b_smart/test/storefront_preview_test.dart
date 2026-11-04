import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:b_smart/config/api_config.dart';
import 'package:b_smart/models/store_profile.dart';
import 'package:b_smart/screens/store/store_profile_page.dart';
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
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'store': {
            'store_name': 'Meera Design Studio',
            'store_type': 'Personal Store',
            'about': 'Hand-painted home decor, custom murals and styling for '
                'small spaces across Mumbai.',
            'service_areas': ['Mumbai', 'Thane', 'Navi Mumbai', 'Online'],
            'languages': ['English', 'Hindi', 'Marathi'],
            'trust_badges': ['Verified', 'Top rated', 'Fast delivery'],
            'followers_count': 1284,
            'following_count': 37,
            'product_count': 24,
            'service_count': 6,
            'member_since': 'Mar 2024',
          },
        }),
      );
      await request.response.close();
    });
    ApiConfig.init(baseUrl: 'http://127.0.0.1:${server.port}');

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => <String>['wifi'],
    );

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: StoreProfilePage(ownerUserId: 'seller-1')),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StoreProfilePage),
      matchesGoldenFile('goldens/storefront_profile.png'),
    );

    await server.close(force: true);
  });

  testWidgets('storefront edit preview', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: StoreProfileEditPage(initial: _profile)),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StoreProfileEditPage),
      matchesGoldenFile('goldens/storefront_edit.png'),
    );
  });
}
