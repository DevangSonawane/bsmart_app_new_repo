import 'package:b_smart/screens/store/shared/store_money.dart';
import 'package:b_smart/screens/store/store_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for store money formatting.
///
/// Amounts were rendered with a bare `toStringAsFixed`, so the app showed
/// `₹1000` instead of `₹1,000`. These pin the grouping and the whole/fraction
/// decimal rule used at every store price display.
void main() {
  group('groupThousands', () {
    test('leaves short numbers alone', () {
      expect(groupThousands('0'), '0');
      expect(groupThousands('7'), '7');
      expect(groupThousands('999'), '999');
    });

    test('groups from the right', () {
      expect(groupThousands('1000'), '1,000');
      expect(groupThousands('12345'), '12,345');
      expect(groupThousands('123456'), '123,456');
      expect(groupThousands('1234567'), '1,234,567');
      expect(groupThousands('123456789'), '123,456,789');
    });
  });

  group('formatStoreAmount', () {
    test('whole amounts drop the decimals', () {
      expect(formatStoreAmount(1000), '1,000');
      expect(formatStoreAmount(100000), '100,000');
      expect(formatStoreAmount(0), '0');
      expect(formatStoreAmount(12), '12');
    });

    test('fractional amounts keep two decimals', () {
      expect(formatStoreAmount(1000.5), '1,000.50');
      expect(formatStoreAmount(99.99), '99.99');
      expect(formatStoreAmount(1234.56), '1,234.56');
    });

    test('an explicit decimal count wins over the whole check', () {
      expect(formatStoreAmount(1000, decimals: 2), '1,000.00');
      expect(formatStoreAmount(1000.5, decimals: 0), '1,001');
    });

    test('keeps the minus sign outside the grouping', () {
      expect(formatStoreAmount(-2500), '-2,500');
      expect(formatStoreAmount(-2500.5), '-2,500.50');
    });

    test('handles non-finite amounts without throwing', () {
      expect(formatStoreAmount(double.infinity), isNotEmpty);
      expect(formatStoreAmount(double.nan), isNotEmpty);
    });
  });

  group('formatStoreMoney', () {
    test('prefixes the rupee sign', () {
      expect(formatStoreMoney(1000), '₹1,000');
      expect(formatStoreMoney(1000.25), '₹1,000.25');
      expect(formatStoreMoney(-1200), '-₹1,200');
    });
  });

  group('catalog price label', () {
    test('a whole catalog price is grouped', () {
      final item = StoreMockState.productFromApi({
        'id': 'p1',
        'name': 'Desk',
        'selling_price': 25000,
      });
      expect(item.priceLabel, '₹25,000');
    });

    test('a fractional catalog price keeps decimals', () {
      final item = StoreMockState.productFromApi({
        'id': 'p1',
        'name': 'Desk',
        'selling_price': 2499.5,
      });
      expect(item.priceLabel, '₹2,499.50');
    });

    test('a service price is grouped too', () {
      final item = StoreMockState.serviceFromApi({
        'id': 's1',
        'name': 'Consulting',
        'price': 1500,
      });
      expect(item.priceLabel, '₹1,500');
    });
  });

  group('cart money helper', () {
    test('always shows two decimals, grouped', () {
      expect(StoreMockState.instance.money(1234.5), '₹1,234.50');
      expect(StoreMockState.instance.money(1000), '₹1,000.00');
    });
  });
  _negativeSavingsGroup();
}
/// The cart renders savings as a negative amount. The formatter owns the sign,
/// so these call sites must not prepend their own '-' or the output reads
/// `-₹-1,200`.
void _negativeSavingsGroup() {
  group('negative savings rendering', () {
    test('a savings amount renders with a single leading minus', () {
      final text = formatStoreMoney(-1500.25, decimals: 2);
      expect(text, '-₹1,500.25');
      expect(text.contains('-₹-'), isFalse);
      expect('₹${text}'.contains('-₹-'), isFalse);
    });

    test('negating a positive savings value matches', () {
      expect(formatStoreMoney(-1500.25, decimals: 2),
          '-${formatStoreMoney(1500.25, decimals: 2)}');
    });
  });

}
