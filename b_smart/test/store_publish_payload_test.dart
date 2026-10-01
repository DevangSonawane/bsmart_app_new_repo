import 'package:b_smart/api/upload_api.dart';
import 'package:b_smart/screens/store/store_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the influencer product/service publish payloads.
///
/// Products used to be published by uploading `XFile.path` at submit time.
/// `pickMultiImage` can return a content:// URI or a provider cache path that
/// `MultipartFile.fromPath` cannot open, so the upload threw and the UI
/// reported "Publish failed" for a product the backend had already accepted.
/// These tests pin the upload-filename rules that keep the bytes path working
/// and the payload keys the create endpoints require.
void main() {
  group('influencer upload filename', () {
    test('keeps a name that already has an extension', () {
      expect(influencerUploadFilename('photo.png', 'content://x/photo'),
          'photo.png');
      expect(influencerUploadFilename('a.jpeg', '/tmp/a.jpeg'), 'a.jpeg');
    });

    test('falls back to the path extension when the name has none', () {
      expect(influencerUploadFilename('', '/tmp/shot.webp'), 'product_image.webp');
      expect(influencerUploadFilename('IMG_1', '/cache/IMG_1.png'),
          'product_image.png');
    });

    test('defaults to jpg for a content:// URI with no extension', () {
      // Content URIs have no extension to copy, and the server needs one to
      // pick the multipart content type.
      expect(influencerUploadFilename('', 'content://media/external/images/1'),
          'product_image.jpg');
    });

    test('rejects a non-image extension so the content type stays valid', () {
      // ".here" would be sent as the file extension and the server could not
      // derive image/jpeg from it.
      expect(influencerUploadFilename('', 'no.extension.at.all.here'),
          'product_image.jpg');
      expect(influencerUploadFilename('report.pdf', '/tmp/report.pdf'),
          'product_image.jpg');
    });

    test('keeps a webp name that the content-type map can resolve', () {
      expect(influencerUploadFilename('shot.webp', 'content://x/1'),
          'shot.webp');
    });
  });

  group('uploaded image payload', () {
    test('serialises to the fileName/fileUrl pair the API stores', () {
      const img = UploadedImage(fileName: 'p.jpg', fileUrl: 'https://x/p.jpg');
      expect(img.toJson(), {
        'fileName': 'p.jpg',
        'fileUrl': 'https://x/p.jpg',
      });
    });

    test('parses a server response and drops entries with no url', () {
      final images = UploadedImage.listOf({
        'images': [
          {'fileName': 'a.png', 'fileUrl': 'https://x/a.png'},
          {'file_name': 'b.png', 'url': 'https://x/b.png'},
          {'fileName': 'broken.png'},
        ],
      });
      expect(images.length, 2);
      expect(images.first.fileName, 'a.png');
      expect(images.last.fileUrl, 'https://x/b.png');
    });

    test('unwraps a nested data.images envelope', () {
      final images = UploadedImage.listOf({
        'data': {
          'images': [
            {'fileUrl': 'https://x/c.jpg'},
          ],
        },
      });
      expect(images.length, 1);
      expect(images.single.fileUrl, 'https://x/c.jpg');
    });
  });

  group('catalog parsing after publish', () {
    test('a product keeps its id so edit and delete stay wired', () {
      final item = StoreMockState.productFromApi({
        'id': 'p1',
        'name': 'Mug',
        'selling_price': 120,
        'stock_quantity': 3,
      });
      expect(item.id, 'p1');
    });

    test('a service keeps its id so edit and delete stay wired', () {
      final item = StoreMockState.serviceFromApi({
        'id': 's1',
        'name': 'Consultation',
        'price': 500,
      });
      expect(item.id, 's1');
    });

    test('a product with no id still parses instead of throwing', () {
      // A missing id used to disable Edit/Delete, so publish must not blow up
      // on an id-less response.
      final item = StoreMockState.productFromApi({'name': 'No id'});
      expect(item.title, 'No id');
      expect(item.id, isEmpty);
    });
  });
}
