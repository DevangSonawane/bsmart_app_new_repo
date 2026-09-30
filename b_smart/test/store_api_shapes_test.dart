import 'package:b_smart/api/address_api.dart';
import 'package:b_smart/api/wishlist_api.dart';
import 'package:b_smart/models/ship_address.dart';
import 'package:b_smart/models/store_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the pure list-unwrapping helpers used by the wishlist and
/// address APIs. These tolerate the several envelope shapes a REST response
/// can arrive in, so they are the most likely place for a silent regression.
void main() {
  group('wishlist response shapes', () {
    test('unwraps the documented products array', () {
      final items = WishlistApi.listFrom({
        'success': true,
        'total': 2,
        'products': [
          {'id': 'p1', 'name': 'A', 'selling_price': 100},
          {'id': 'p2', 'name': 'B', 'selling_price': 200},
        ],
      });
      expect(items.length, 2);
      expect(items.first['id'], 'p1');
    });

    test('unwraps a wishlist array', () {
      final items = WishlistApi.listFrom({
        'wishlist': [
          {'id': 'p1'},
        ],
      });
      expect(items.length, 1);
    });

    test('unwraps a data array', () {
      final items = WishlistApi.listFrom({
        'data': [
          {'id': 'p1'},
        ],
      });
      expect(items.length, 1);
    });

    test('returns empty for an unknown envelope', () {
      expect(WishlistApi.listFrom({'unexpected': true}), isEmpty);
      expect(WishlistApi.listFrom(const {}), isEmpty);
    });

    test('keeps wishlisted_at alongside product fields', () {
      final items = WishlistApi.listFrom({
        'products': [
          {
            'id': 'p1',
            'name': 'A',
            'wishlisted_at': '2026-09-29T08:30:00.000Z',
          },
        ],
      });
      expect(items.first['wishlisted_at'], isNotNull);
    });
  });

  group('address response shapes', () {
    test('unwraps a bare list', () {
      final items = AddressApi.listFrom([
        {'id': 'a1', 'address_line1': '221B Baker St'},
      ]);
      expect(items.length, 1);
    });

    test('unwraps an addresses envelope', () {
      final items = AddressApi.listFrom({
        'addresses': [
          {'id': 'a1', 'address_line1': '221B Baker St'},
        ],
      });
      expect(items.length, 1);
    });

    test('unwraps a data envelope', () {
      final items = AddressApi.listFrom({
        'data': {'addresses': [{'id': 'a1'}]},
      });
      expect(items.length, 1);
    });

    test('accepts a single object from a create response', () {
      final items = AddressApi.listFrom({
        'address_line1': '221B Baker St',
        'pincode': '400001',
      });
      expect(items.length, 1);
    });

    test('the first entry is marked default', () {
      final items = AddressApi.listFrom({
        'addresses': [
          {'id': 'a1', 'address_line1': 'first'},
          {'id': 'a2', 'address_line1': 'second'},
        ],
      });
      expect(
        ShipAddress.fromApiJson(items.first, fallbackDefault: true).isDefault,
        isTrue,
      );
      expect(
        ShipAddress.fromApiJson(items[1]).isDefault,
        isFalse,
      );
    });

    test('entries without a line are dropped', () {
      final items = AddressApi.listFrom({
        'addresses': [
          {'id': 'a1', 'address_line1': 'kept'},
          {'id': 'a2'},
        ],
      });
      expect(items.length, 2);
      // The unusable row is filtered before a default is assigned, so the
      // first surviving address is still the default.
      final parsed = AddressApi.parseList({'addresses': items});
      expect(parsed.length, 1);
      expect(parsed.first.line1, 'kept');
      expect(parsed.first.isDefault, isTrue);
    });

    test('an all-invalid list parses to empty, not a crash', () {
      expect(AddressApi.parseList({'addresses': [{'id': 'a1'}]}), isEmpty);
    });
  });

  group('address checkout payloads', () {
    const a = ShipAddress(
      id: 'a1',
      label: 'Home',
      name: 'Aniket',
      phone: '9876543210',
      line1: '221B Baker St',
      city: 'Mumbai',
      state: 'Maharashtra',
      pincode: '400001',
    );

    test('shipping_address matches the checkout spec', () {
      final json = a.toShippingJson();
      expect(json['name'], 'Aniket');
      expect(json['phone'], '9876543210');
      expect(json['address_line1'], '221B Baker St');
      expect(json['city'], 'Mumbai');
      expect(json['state'], 'Maharashtra');
      expect(json['pincode'], '400001');
    });

    test('customer_address only carries the three required fields', () {
      final json = a.toCustomerJson();
      expect(json.keys.length, 3);
      expect(json.containsKey('address_line1'), isTrue);
      expect(json.containsKey('city'), isTrue);
      expect(json.containsKey('pincode'), isTrue);
    });

    test('every shipping value is a non-empty string', () {
      a.toShippingJson().forEach((key, value) {
        expect(value.trim(), isNotEmpty, reason: '$key must not be blank');
      });
    });
  });

  group('store profile edge cases', () {
    test('an empty profile is reported as empty', () {
      expect(const StoreProfile().isEmpty, isTrue);
    });

    test('a name alone is not empty', () {
      expect(const StoreProfile(storeName: 'A').isEmpty, isFalse);
    });

    test('comma separated service areas are split', () {
      final p = StoreProfile.fromApiJson({
        'store': {'service_areas': 'Mumbai, Online'},
      });
      expect(p.serviceAreas, ['Mumbai', 'Online']);
    });

    test('numeric counts arriving as strings still parse', () {
      final p = StoreProfile.fromApiJson({
        'store': {'followers_count': '42', 'product_count': '7'},
      });
      expect(p.followersCount, 42);
      expect(p.productCount, 7);
    });

    test('a blank store_type is omitted from the update patch', () {
      final patch = const StoreProfile().toUpdateJson(storeType: '   ');
      expect(patch.containsKey('store_type'), isFalse);
    });
  });
}
