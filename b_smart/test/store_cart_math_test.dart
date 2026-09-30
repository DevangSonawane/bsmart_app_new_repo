import 'package:b_smart/screens/store/store_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for cart money math and line merging.
///
/// These are pure functions of a parsed cart, so they need no backend.
void main() {
  StoreMockCartLine line(
    String id,
    double price,
    int qty, {
    Map<String, dynamic> variant = const {},
  }) {
    return StoreMockCartLine(
      item: StoreMockState.productFromApi({
        'id': id,
        'name': 'Item $id',
        'selling_price': price,
      }),
      quantity: qty,
      variant: variant,
    );
  }

  group('line totals', () {
    test('total is unit price times quantity', () {
      expect(line('a', 250, 4).total, 1000);
    });

    test('a single unit totals the unit price', () {
      expect(line('a', 2499, 1).total, 2499);
    });

    test('zero price yields zero, not null or NaN', () {
      final l = line('a', 0, 4);
      expect(l.total, 0);
      expect(l.total.isNaN, isFalse);
    });
  });

  group('variant pricing', () {
    test('variant price overrides the product price', () {
      final l = line('a', 500, 2, variant: {'color': 'red', 'price': 750});
      expect(l.unitPrice, 750);
      expect(l.total, 1500);
    });

    test('falls back to the product price when the variant has none', () {
      final l = line('a', 500, 2, variant: {'color': 'red'});
      expect(l.unitPrice, 500);
    });

    test('a zero variant price is ignored, not treated as free', () {
      final l = line('a', 500, 1, variant: {'price': 0});
      expect(l.unitPrice, 500);
    });
  });

  group('variant identity', () {
    test('same colour and size produce the same key', () {
      final a = line('a', 1, 1, variant: {'color': 'red', 'size': 'L'});
      final b = line('a', 1, 1, variant: {'color': 'red', 'size': 'L'});
      expect(a.variantKey, b.variantKey);
    });

    test('different size produces a different key', () {
      final a = line('a', 1, 1, variant: {'color': 'red', 'size': 'L'});
      final b = line('a', 1, 1, variant: {'color': 'red', 'size': 'M'});
      expect(a.variantKey, isNot(b.variantKey));
    });

    test('no variant yields an empty key so lines merge', () {
      expect(line('a', 1, 1).variantKey, '');
    });

    test('variant label joins the present parts', () {
      final l = line('a', 1, 1, variant: {'color': 'red', 'size': 'L'});
      expect(l.variantLabel, 'red · L');
    });
  });

  group('cart aggregation from a parsed response', () {
    test('subtotal sums every line', () {
      final lines = StoreMockState.cartLinesFromApi({
        'items': [
          {
            'product': {'id': 'p1', 'name': 'A', 'selling_price': 100},
            'quantity': 2,
          },
          {
            'product': {'id': 'p2', 'name': 'B', 'selling_price': 250},
            'quantity': 4,
          },
        ],
      })!;
      final subtotal = lines.fold<double>(0, (sum, l) => sum + l.total);
      expect(subtotal, 1200);
    });

    test('a mixed cart totals correctly across variants', () {
      final lines = StoreMockState.cartLinesFromApi({
        'items': [
          {
            'product': {'id': 'p1', 'name': 'A', 'selling_price': 500},
            'quantity': 1,
          },
          {
            'product': {'id': 'p1', 'name': 'A', 'selling_price': 500},
            'quantity': 2,
            'variant': {'color': 'red', 'size': 'L', 'price': 750},
          },
        ],
      })!;
      final subtotal = lines.fold<double>(0, (sum, l) => sum + l.total);
      // 1 x 500 (no variant) + 2 x 750 (priced variant)
      expect(subtotal, 2000);
    });

    test('quantity is clamped into a sane range', () {
      final lines = StoreMockState.cartLinesFromApi({
        'items': [
          {
            'product': {'id': 'p1', 'name': 'A', 'selling_price': 10},
            'quantity': 0,
          },
        ],
      })!;
      expect(lines.first.quantity, 1);
    });
  });

  group('price labels', () {
    test('whole numbers drop the decimals', () {
      expect(
        StoreMockState.productFromApi({
          'id': 'a',
          'name': 'A',
          'selling_price': 2499,
        }).priceLabel,
        '₹2499',
      );
    });

    test('paise amounts keep two decimals', () {
      expect(
        StoreMockState.productFromApi({
          'id': 'a',
          'name': 'A',
          'selling_price': 2499.5,
        }).priceLabel,
        '₹2499.50',
      );
    });
  });

  group('service parsing', () {
    test('reads price and duration', () {
      final s = StoreMockState.serviceFromApi({
        'id': 's1',
        'name': 'Home Cleaning',
        'price': 999,
        'duration': '1 hour',
      });
      expect(s.price, 999);
      expect(s.duration, '1 hour');
      expect(s.type, StoreMockItemType.service);
    });

    test('falls back to selling_price', () {
      final s = StoreMockState.serviceFromApi({
        'id': 's1',
        'name': 'S',
        'selling_price': 500,
      });
      expect(s.price, 500);
    });
  });
}
