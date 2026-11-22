import 'dart:convert';
import 'dart:io';

import 'package:b_smart/api/api_client.dart';
import 'package:b_smart/config/api_config.dart';
import 'package:b_smart/screens/chat_conversation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fr = '/Users/devangsonawane/tools/flutter/bin/cache/artifacts/material_fonts';
const _m = '/Users/devangsonawane/roast-room/app/public/brand/fonts';
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

String _b64(Map<String, dynamic> m) =>
    base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');

void main() {
  late HttpServer server;

  setUpAll(() async {
    HttpOverrides.global = null;
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFont('Roboto', [
      '$_fr/Roboto-Regular.ttf',
      '$_fr/Roboto-Medium.ttf',
      '$_fr/Roboto-Bold.ttf',
    ]);
    await _loadFont('Montserrat',
        ['$_m/Montserrat-Regular.ttf', '$_m/Montserrat-SemiBold.ttf', '$_m/Montserrat-Bold.ttf']);
    await _loadFont('MaterialIcons', ['$_fr/MaterialIcons-Regular.otf']);
    await _loadFont('packages/lucide_icons_flutter/Lucide', [_lucide]);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 10, 5);
    final older = today.subtract(const Duration(days: 3));
    final imageBytes = await File('test/goldens/vault_light.png').readAsBytes();
    const me = {'_id': 'me', 'username': 'devang'};
    const riya = {'_id': 'u2', 'username': 'riya'};
    final messages = [
      {'_id': 'm1', 'sender': riya, 'text': 'Hey! Did you see the new vault page?', 'createdAt': older.toIso8601String()},
      {'_id': 'm2', 'sender': me, 'text': 'Yes, just shipped it 🎉', 'createdAt': older.add(const Duration(minutes: 20)).toIso8601String()},
      {'_id': 'm3', 'sender': riya, 'text': 'Looks great. Can you send the screenshot?', 'createdAt': older.add(const Duration(minutes: 50)).toIso8601String()},
      {'_id': 'm4', 'sender': me, 'text': 'Morning! Here it is', 'createdAt': today.toIso8601String(), 'replyTo': 'm3'},
      {'_id': 'm5', 'sender': me, 'text': 'Balance card + 30 day chart', 'mediaUrl': 'http://127.0.0.1:PORT/img.png', 'mediaType': 'image', 'createdAt': today.add(const Duration(minutes: 1)).toIso8601String()},
      {'_id': 'm6', 'sender': riya, 'text': 'Love the bars 😍', 'createdAt': today.add(const Duration(minutes: 40)).toIso8601String(), 'replyTo': 'm5'},
    ];

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    server.listen((req) async {
      final path = req.uri.path;
      req.response.headers.set('access-control-allow-origin', '*');
      if (path.endsWith('/img.png')) {
        req.response.headers.contentType = ContentType('image', 'png');
        req.response.add(imageBytes);
      } else if (path.contains('/messages')) {
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({
          'messages': jsonDecode(jsonEncode(messages).replaceAll('PORT', '$port')),
          'hasMore': false,
        }));
      } else {
        req.response.headers.contentType = ContentType.json;
        req.response.write('{}');
      }
      await req.response.close();
    });
    ApiConfig.init(baseUrl: 'http://127.0.0.1:$port/api');
  });

  tearDownAll(() => server.close(force: true));

  testWidgets('chat conversation preview', (tester) async {
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
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
    SharedPreferences.setMockInitialValues({});
    final token =
        '${_b64({'alg': 'HS256'})}.${_b64({'user_id': 'me', 'exp': 9999999999})}.sig';
    await ApiClient().saveToken(token);

    tester.view.physicalSize = const Size(1170, 4050);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatConversationScreen(
        conversationId: 'c1',
        initialConversation: const {
          '_id': 'c1',
          'participants': [
            {'_id': 'me', 'username': 'devang'},
            {'_id': 'u2', 'username': 'riya', 'full_name': 'Riya Shah'},
          ],
        },
      ),
    ));
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.enterText(find.byType(TextField).last,
        'This is a long message\nthat goes onto a second line\nand a third one');
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(ChatConversationScreen),
        matchesGoldenFile('goldens/doc_chat.png'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
