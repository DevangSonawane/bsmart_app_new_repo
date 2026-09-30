import 'package:b_smart/models/ship_address.dart';
import 'package:b_smart/models/store_profile.dart';
import 'package:b_smart/screens/store/store_models.dart';
import 'package:b_smart/services/razorpay_checkout_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the response parsers.
///
/// Every case here corresponds to a bug that shipped: product images were
/// blank because `fileUrl` was never read, cart totals were 0.00 because the
/// line list/price keys were missed, and Razorpay never opened because the
/// sibling `razorpay` payload was discarded before it reached the checkout.
void main() {
  group('product parsing', () {
    test('reads price from selling_price (documented field)', () {
      final item = StoreMockState.productFromApi({
        'id': 'p1',
        'name': 'Leather Tote',
        'selling_price': 2499,
      });
      expect(item.price, 2499);
      expect(item.priceLabel, '₹2499');
    });

    test('parses price given as a string', () {
      final item = StoreMockState.productFromApi({
        'id': 'p1',
        'name': 'Tote',
        'selling_price': '2499.50',
      });
      expect(item.price, 2499.50);
    });

    test('falls back through price keys when selling_price is absent', () {
      expect(
        StoreMockState.productFromApi({'price': 100}).price,
        100,
      );
      expect(
        StoreMockState.productFromApi({'mrp': 2999}).price,
        2999,
      );
    });

    test('prefers fileUrl over fileName for images', () {
      // The upload endpoints return {fileName, fileUrl}. Reading fileName
      // first produced a bare filename and a broken image.
      final item = StoreMockState.productFromApi({
        'id': 'p1',
        'name': 'Tote',
        'images': [
          {'fileName': 'product1.jpg', 'fileUrl': 'https://cdn/x/product1.jpg'},
        ],
      });
      expect(item.imageUrl, 'https://cdn/x/product1.jpg');
    });

    test('falls back to fileName when it holds a real path', () {
      final item = StoreMockState.productFromApi({
        'id': 'p1',
        'name': 'Tote',
        'images': [
          {'fileName': 'uploads/users/1/product1.jpg'},
        ],
      });
      expect(item.imageUrl, contains('product1.jpg'));
      expect(item.imageUrl, startsWith('http'));
    });

    test('handles images as a flat list of URL strings (wishlist shape)', () {
      final item = StoreMockState.productFromApi({
        'id': 'p1',
        'name': 'Tote',
        'images': ['https://cdn/x/p1.jpg'],
      });
      expect(item.imageUrl, 'https://cdn/x/p1.jpg');
    });
  });

  group('cart parsing (₹0.00 subtotal regression)', () {
    test('finds the line list at the root', () {
      final lines = StoreMockState.cartLinesFromApi({
        'items': [
          {
            'product': {'id': 'p1', 'name': 'Tote', 'selling_price': 500},
            'quantity': 4,
          }
        ],
      });
      expect(lines, isNotNull);
      expect(lines!.length, 1);
      expect(lines.first.item.price, 500);
      expect(lines.first.quantity, 4);
      expect(lines.first.total, 2000);
    });

    test('finds the line list nested under data', () {
      final lines = StoreMockState.cartLinesFromApi({
        'data': {
          'items': [
            {'product': {'id': 'p1', 'name': 'T', 'selling_price': 250}},
          ],
        },
      });
      expect(lines!.first.item.price, 250);
    });

    test('finds the line list nested under cart', () {
      final lines = StoreMockState.cartLinesFromApi({
        'cart': {
          'items': [
            {'product': {'id': 'p1', 'name': 'T', 'selling_price': 120}},
          ],
        },
      });
      expect(lines!.first.item.price, 120);
    });

    test('uses the cart line own price when the product lacks one', () {
      final lines = StoreMockState.cartLinesFromApi({
        'items': [
          {
            'product_id': 'p1',
            'product_name': 'Tote',
            'unit_price': 300,
            'quantity': 2,
          }
        ],
      });
      expect(lines!.first.item.price, 300);
      expect(lines.first.total, 600);
    });

    test('reads a flat line with an inline price', () {
      final lines = StoreMockState.cartLinesFromApi({
        'items': [
          {'product_id': 'p1', 'name': 'Tote', 'price': 99, 'quantity': 3},
        ],
      });
      expect(lines!.first.item.price, 99);
      expect(lines.first.total, 297);
    });

    test('variant price wins over product price', () {
      final lines = StoreMockState.cartLinesFromApi({
        'items': [
          {
            'product': {'id': 'p1', 'name': 'T', 'selling_price': 500},
            'quantity': 1,
            'variant': {'color': 'red', 'size': 'L', 'price': 750},
          }
        ],
      });
      expect(lines!.first.total, 750);
    });

    test('returns null when no line list is present', () {
      expect(StoreMockState.cartLinesFromApi({'total': 3}), isNull);
    });

    test('an empty cart yields zero totals, not a crash', () {
      final lines = StoreMockState.cartLinesFromApi({'items': []});
      expect(lines, isNotNull);
      expect(lines!.isEmpty, isTrue);
    });
  });

  group('razorpay response (never-opened checkout regression)', () {
    test('reads the razorpay block alongside order', () {
      final result = RazorpayCheckoutService.razorpayOf({
        'order': {'id': 'o1', 'status': 'pending'},
        'razorpay': {
          'order_id': 'order_123',
          'amount': 249900,
          'key_id': 'rzp_test_abc',
        },
      }, fallbackTotal: 2499);
      expect(result, isNotNull);
      expect(result!.orderId, 'order_123');
      expect(result.keyId, 'rzp_test_abc');
      expect(result.amountPaise, 249900);
    });

    test('reads the block nested under data', () {
      final result = RazorpayCheckoutService.razorpayOf({
        'data': {
          'razorpay': {'order_id': 'order_9', 'key_id': 'rzp_test_x'},
        },
      }, fallbackTotal: 100);
      expect(result?.orderId, 'order_9');
    });

    test('falls back to the cart total when amount is missing', () {
      final result = RazorpayCheckoutService.razorpayOf({
        'razorpay': {'order_id': 'order_1', 'key_id': 'rzp_test_y'},
      }, fallbackTotal: 2499);
      expect(result?.amountPaise, 249900);
    });

    test('returns null when the server sent no razorpay block', () {
      final result = RazorpayCheckoutService.razorpayOf({
        'order': {'id': 'o1'},
      }, fallbackTotal: 100);
      expect(result, isNull);
    });
  });

  group('address parsing', () {
    test('reads the documented address_line1 field', () {
      final a = ShipAddress.fromApiJson({
        'id': 'a1',
        'label': 'Home',
        'name': 'Aniket',
        'phone': '9876543210',
        'address_line1': '221B Baker St',
        'city': 'Mumbai',
        'state': 'Maharashtra',
        'pincode': '400001',
        'is_default': true,
      });
      expect(a.line1, '221B Baker St');
      expect(a.isDefault, isTrue);
      expect(a.toShippingJson()['address_line1'], '221B Baker St');
      expect(a.toApiJson()['address_line1'], '221B Baker St');
    });

    test('marks the first entry default when no flag is sent', () {
      final a = ShipAddress.fromApiJson({
        'id': 'a1',
        'address_line1': 'x',
        'pincode': '1',
      }, fallbackDefault: true);
      expect(a.isDefault, isTrue);
    });

    test('summaryLine joins the populated parts', () {
      const a = ShipAddress(
        id: 'a1',
        label: 'Home',
        name: 'A',
        phone: '1',
        line1: '221B Baker St',
        city: 'Mumbai',
        state: 'MH',
        pincode: '400001',
      );
      expect(a.summaryLine, '221B Baker St, Mumbai, MH, 400001');
    });
  });

  group('store profile parsing', () {
    test('unwraps the store object and all fields', () {
      final p = StoreProfile.fromApiJson({
        'store': {
          'store_name': "Harsh's Store",
          'store_type': 'Personal Store',
          'about': 'Curated streetwear',
          'service_areas': ['Mumbai', 'Online'],
          'languages': ['English', 'Hindi'],
          'trust_badges': ['Professional', 'Trusted'],
          'followers_count': 12,
          'product_count': 3,
          'service_count': 1,
          'is_following': true,
        },
      });
      expect(p.storeName, "Harsh's Store");
      expect(p.storeType, 'Personal Store');
      expect(p.serviceAreas, ['Mumbai', 'Online']);
      expect(p.languages, ['English', 'Hindi']);
      expect(p.trustBadges, ['Professional', 'Trusted']);
      expect(p.followersCount, 12);
      expect(p.productCount, 3);
      expect(p.isFollowing, isTrue);
    });

    test('update json sends only the provided fields', () {
      const p = StoreProfile();
      final patch = p.toUpdateJson(languages: ['Hindi'], storeType: 'Shop');
      expect(patch.containsKey('languages'), isTrue);
      expect(patch.containsKey('store_type'), isTrue);
      expect(patch.containsKey('service_areas'), isFalse);
      expect(patch.containsKey('trust_badges'), isFalse);
    });

    test('an absent store parses to an empty profile, not a crash', () {
      final p = StoreProfile.fromApiJson(const {});
      expect(p.isEmpty, isTrue);
    });
  });
}
