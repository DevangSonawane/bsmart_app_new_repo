import 'package:flutter_test/flutter_test.dart';
import 'package:b_smart/services/page_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PageCacheService().clearAll();
    PageCacheService().enablePageCache = true;
  });

  group('PageCacheService', () {
    test('cache miss returns null', () async {
      final result = await PageCacheService()
          .get('home_feed', 'user123', const <String, dynamic>{});
      expect(result, isNull);
    });

    test('cache hit returns data within TTL', () async {
      await PageCacheService()
          .set('home_feed', 'user123', const <String, dynamic>{}, 'cached_feed');
      final result = await PageCacheService()
          .get('home_feed', 'user123', const <String, dynamic>{});
      expect(result, 'cached_feed');
    });

    test('cache miss after TTL expiry', () async {
      final service = PageCacheService();
      service.debugCache['home_feed_v1_ user123'] = CacheEntry(
        data: 'old_data',
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
        ttl: const Duration(minutes: 5),
      );
      final result =
          await service.get('home_feed', 'user123', const <String, dynamic>{});
      expect(result, isNull);
    });

    test('invalidation removes correct key', () async {
      await PageCacheService()
          .set('home_feed', 'user123', const <String, dynamic>{}, 'feed');
      await PageCacheService()
          .set('reels', 'user123', const <String, dynamic>{}, 'reels');
      await PageCacheService().invalidate('home_feed', 'user123');
      final feed =
          await PageCacheService().get('home_feed', 'user123', const <String, dynamic>{});
      final reels =
          await PageCacheService().get('reels', 'user123', const <String, dynamic>{});
      expect(feed, isNull);
      expect(reels, 'reels');
    });

    test('LRU eviction when max entries exceeded', () async {
      final service = PageCacheService();
      for (int i = 0; i < 31; i++) {
        await service.set('page_group', 'user$i', const <String, dynamic>{}, 'data_$i');
      }
      // First inserted entry should have been evicted
      final first =
          await service.get('page_group', 'user0', const <String, dynamic>{});
      expect(first, isNull);
    });

    test('schema version mismatch causes miss', () async {
      final service = PageCacheService();
      service.debugCache['home_feed_v2_ user123'] = CacheEntry(
        data: 'new_schema_data',
        timestamp: DateTime.now(),
        ttl: const Duration(minutes: 5),
      );
      final result =
          await service.get('home_feed', 'user123', const <String, dynamic>{});
      expect(result, isNull);
    });
  });
}
