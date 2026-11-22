import 'dart:convert';
import 'dart:io';

import 'package:b_smart/screens/wallet_screen.dart';
import 'package:b_smart/services/page_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUpAll(() async {
    // Let google_fonts fetch the real Montserrat files (tests block HTTP by default).
    HttpOverrides.global = null;
    GoogleFonts.config.allowRuntimeFetching = true;
    await _loadFont('Lucide', 'assets/fonts/lucide.ttf');
    await _loadFont('packages/lucide_icons_flutter/Lucide', '/Users/devangsonawane/.pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.22/assets/lucide.ttf');
    await _loadFont('MaterialIcons',
        '/Users/devangsonawane/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  for (final dark in [false, true]) {
    testWidgets('vault preview ${dark ? 'dark' : 'light'}', (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (call) async => <String>['wifi'],
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );

      final now = DateTime.now();
      final ledger = <Map<String, dynamic>>[
        for (var d = 0; d < 30; d++)
          if (d % 4 != 3)
            {
              'id': 'tx$d',
              'userId': 'u1',
              'type': 'AD_REWARD',
              'amount': 20 + (d * 37) % 90,
              'status': 'COMPLETED',
              'timestamp': now.subtract(Duration(days: d)).toIso8601String(),
              'description': 'Ad reward',
            },
        {
          'id': 'spend1',
          'userId': 'u1',
          'type': 'PAYOUT',
          'amount': -500,
          'status': 'COMPLETED',
          'timestamp': now.subtract(const Duration(days: 2)).toIso8601String(),
          'description': 'Gift card',
        },
      ];
      SharedPreferences.setMockInitialValues(
          {'wallet_local_ledger_v1': jsonEncode(ledger)});

      PageCacheService().clearAll();
      await PageCacheService().set(
        'wallet',
        'anon',
        const {'section': 'none'},
        jsonEncode({
          'coinBalance': 1250,
          'walletData': {'summary': {}},
          'totalEarnedLifetime': 1750,
          'totalSpentLifetime': 500,
          'totalEarnedMonth': 900,
          'totalSpentMonth': 500,
        }),
      );

      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const WalletScreen(),
      ));
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Available Balance'), findsOneWidget);
      expect(find.text("Today's Rate"), findsOneWidget);
      expect(find.text('Last 30 Days Received'), findsOneWidget);
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pump();
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(WalletScreen),
        matchesGoldenFile('goldens/vault_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }
}
