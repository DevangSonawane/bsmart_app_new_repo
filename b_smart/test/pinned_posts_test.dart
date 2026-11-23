import 'dart:io';

import 'package:b_smart/models/feed_post_model.dart';
import 'package:b_smart/preferences/content_preferences_notifier.dart';
import 'package:b_smart/preferences/content_preferences_scope.dart';
import 'package:b_smart/preferences/storage_preferences_notifier.dart';
import 'package:b_smart/preferences/storage_preferences_scope.dart';
import 'package:b_smart/services/network_status_notifier.dart';
import 'package:b_smart/services/network_status_scope.dart';
import 'package:b_smart/state/feed_actions.dart';
import 'package:b_smart/state/feed_reducer.dart';
import 'package:b_smart/state/feed_state.dart';
import 'package:b_smart/widgets/post_card.dart';
import 'package:b_smart/widgets/posts_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for docs/pinned-posts.md (Flutter side).

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

FeedPost _post(String id, {DateTime? pinnedAt, int ageMin = 0}) => FeedPost(
      id: id,
      userId: 'me',
      userName: 'devang',
      mediaType: PostMediaType.image,
      mediaUrls: const [],
      caption: 'Post $id',
      createdAt: DateTime(2026, 11, 23, 12).subtract(Duration(minutes: ageMin)),
      pinnedAt: pinnedAt,
    );

void main() {
  group('FeedPost pin parsing', () {
    test('reads is_pinned + pinned_at from API json', () {
      final p = FeedPost.fromJson({
        '_id': 'a',
        'is_pinned': true,
        'pinned_at': '2026-11-23T10:00:00.000Z',
      });
      expect(p.isPinned, isTrue);
      expect(p.pinnedAt, DateTime.parse('2026-11-23T10:00:00.000Z'));
    });

    test('unpinned post (pinned_at null) is not pinned', () {
      final p = FeedPost.fromJson(
          {'_id': 'b', 'is_pinned': false, 'pinned_at': null});
      expect(p.isPinned, isFalse);
      expect(p.pinnedAt, isNull);
    });

    test('falls back to pinned_at when is_pinned is missing', () {
      expect(FeedPost.parseIsPinned({'pinned_at': '2026-11-23T10:00:00Z'}),
          isTrue);
      expect(FeedPost.parseIsPinned(<String, dynamic>{}), isFalse);
    });

    test('copyWith can pin and clear the pin', () {
      final pinned = _post('x').copyWith(
          pinnedAt: DateTime(2026, 11, 23), isPinned: true);
      expect(pinned.isPinned, isTrue);
      final cleared = pinned.copyWith(clearPinnedAt: true);
      expect(cleared.isPinned, isFalse);
      expect(cleared.pinnedAt, isNull);
    });
  });

  test('sortPinnedFirst: pinned first (latest pin first), rest keep order', () {
    final posts = [
      _post('1'),
      _post('2', pinnedAt: DateTime(2026, 11, 20)),
      _post('3'),
      _post('4', pinnedAt: DateTime(2026, 11, 22)),
      _post('5'),
    ];
    expect(FeedPost.sortPinnedFirst(posts).map((p) => p.id).toList(),
        ['4', '2', '1', '3', '5']);
  });

  test('UpdatePostPinned reducer pins and unpins a feed post', () {
    var state = FeedState(posts: [_post('a'), _post('b')]);
    final at = DateTime(2026, 11, 23, 10);
    state = feedReducer(state, UpdatePostPinned('b', at));
    expect(state.posts[1].isPinned, isTrue);
    expect(state.posts[1].pinnedAt, at);
    expect(state.posts[0].isPinned, isFalse);
    state = feedReducer(state, UpdatePostPinned('b', null));
    expect(state.posts[1].isPinned, isFalse);
  });

  group('screenshots', () {
    setUpAll(() async {
      await _loadFont('packages/lucide_icons_flutter/Lucide',
          '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/lucide_icons_flutter-4.0.3/assets/lucide.ttf');
      await _loadFont('MaterialIcons',
          '/Users/devangsonawane/tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );
    });

    testWidgets('profile grid: pinned first with badge', (tester) async {
      tester.view.physicalSize = const Size(1170, 1170);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final posts = FeedPost.sortPinnedFirst([
        for (var i = 1; i <= 9; i++)
          _post('$i',
              pinnedAt: i == 5
                  ? DateTime(2026, 11, 23)
                  : (i == 8 ? DateTime(2026, 11, 21) : null)),
      ]);
      expect(posts.take(2).map((p) => p.id), ['5', '8']);

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: PostsGrid(
            posts: posts,
            backgroundColor: const Color(0xFF2A2A2E),
            onTap: (_) {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(Scaffold),
          matchesGoldenFile('goldens/pinned_profile_grid.png'));
    });

    testWidgets('feed card header shows pin badge', (tester) async {
      tester.view.physicalSize = const Size(1170, 600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: ContentPreferencesScope(
          notifier: ContentPreferencesNotifier(),
          child: StoragePreferencesScope(
            notifier: StoragePreferencesNotifier(),
            child: NetworkStatusScope(
              notifier: NetworkStatusNotifier.instance,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: PostCard(
                    post: _post('p', pinnedAt: DateTime(2026, 11, 23)),
                    isOwnPost: true,
                    isActive: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.bySemanticsLabel('Pinned post'), findsOneWidget);
      await expectLater(find.byType(Scaffold),
          matchesGoldenFile('goldens/pinned_feed_card.png'));
    });
  });
}
