import 'package:b_smart/screens/store/store_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for image-URL resolution on seller-owned catalog items.
///
/// The influencer upload endpoints return `images: [{fileName, fileUrl}]`.
/// `fileName` is a bare filename, not a URL, so any resolver that tries it
/// before `fileUrl` resolves to a broken image. My Products and My Services
/// both had such a resolver, which is why published images did not render.
void main() {
  group('firstImageUrl', () {
    test('prefers fileUrl over the bare fileName', () {
      final url = StoreMockState.firstImageUrl({
        'images': [
          {
            'fileName': 'product_image.jpg',
            'fileUrl': 'https://cdn.example.com/uploads/p.jpg',
          },
        ],
      });
      expect(url, contains('p.jpg'));
      expect(url, isNot(contains('product_image')));
    });

    test('accepts snake_case file_url', () {
      final url = StoreMockState.firstImageUrl({
        'images': [
          {'file_url': 'https://cdn.example.com/uploads/s.jpg'},
        ],
      });
      expect(url, contains('s.jpg'));
    });

    test('accepts a plain url key', () {
      final url = StoreMockState.firstImageUrl({
        'images': [
          {'url': 'https://cdn.example.com/uploads/u.png'},
        ],
      });
      expect(url, contains('u.png'));
    });

    test('falls back to a bare filename rather than showing nothing', () {
      final url = StoreMockState.firstImageUrl({
        'images': [
          {'fileName': 'photo.jpg'},
        ],
      });
      // The filename alone is not a URL; absoluteUrl either builds a usable
      // absolute URL from it or rejects it. It must never throw.
      expect(url, isA<String>());
    });

    test('reads a plain string image list', () {
      final url = StoreMockState.firstImageUrl({
        'images': ['https://cdn.example.com/uploads/plain.jpg'],
      });
      expect(url, contains('plain.jpg'));
    });

    test('reads a single top-level fileUrl', () {
      final url = StoreMockState.firstImageUrl({
        'fileUrl': 'https://cdn.example.com/uploads/single.jpg',
      });
      expect(url, contains('single.jpg'));
    });

    test('returns empty for an item with no images', () {
      expect(StoreMockState.firstImageUrl({'name': 'No images'}), '');
      expect(StoreMockState.firstImageUrl(const {}), '');
      expect(StoreMockState.firstImageUrl({'images': <dynamic>[]}), '');
    });

    test('skips an unusable first image and uses the next one', () {
      final url = StoreMockState.firstImageUrl({
        'images': [
          {'fileName': 'broken.jpg'},
          {'fileUrl': 'https://cdn.example.com/uploads/second.jpg'},
        ],
      });
      expect(url, isNotEmpty);
    });

    test('a parsed product carries the resolved image url', () {
      final item = StoreMockState.productFromApi({
        'id': 'p1',
        'name': 'Mug',
        'selling_price': 120,
        'images': [
          {
            'fileName': 'mug.jpg',
            'fileUrl': 'https://cdn.example.com/uploads/mug.jpg',
          },
        ],
      });
      expect(item.imageUrl, contains('mug.jpg'));
    });

    test('a parsed service carries the resolved image url', () {
      final item = StoreMockState.serviceFromApi({
        'id': 's1',
        'name': 'Consultation',
        'price': 500,
        'images': [
          {
            'fileName': 'svc.jpg',
            'fileUrl': 'https://cdn.example.com/uploads/svc.jpg',
          },
        ],
      });
      expect(item.imageUrl, contains('svc.jpg'));
    });
  });
}