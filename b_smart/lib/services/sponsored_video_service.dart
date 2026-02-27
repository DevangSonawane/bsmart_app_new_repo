import '../models/user_account_model.dart';
import '../models/media_model.dart';
import '../services/content_moderation_service.dart';

class SponsoredVideoService {
  static final SponsoredVideoService _instance = SponsoredVideoService._internal();
  factory SponsoredVideoService() => _instance;

  final List<SponsoredVideo> _videos = [];
  final ContentModerationService _moderationService = ContentModerationService();

  SponsoredVideoService._internal();

  Future<SponsoredVideo> createDraft({
    required String userId,
    required String productName,
    required String productDescription,
    required String brandName,
    required String productUrl,
  }) async {
    final video = SponsoredVideo(
      id: 'sponsored-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      productName: productName,
      productDescription: productDescription,
      brandName: brandName,
      productUrl: productUrl,
      createdAt: DateTime.now(),
    );

    _videos.add(video);
    return video;
  }

  Future<bool> updateDraft(SponsoredVideo video) async {
    final index = _videos.indexWhere((v) => v.id == video.id);
    if (index == -1) return false;

    _videos[index] = video;
    return true;
  }

  Future<SponsoredVideo?> getVideo(String videoId) async {
    try {
      return _videos.firstWhere((v) => v.id == videoId);
    } catch (e) {
      return null;
    }
  }

  Future<List<SponsoredVideo>> getUserVideos(String userId) async {
    return _videos.where((v) => v.userId == userId).toList();
  }

  Future<SponsoredVideoStatus> submitForReview(String videoId) async {
    final video = await getVideo(videoId);
    if (video == null) {
      throw Exception('Video not found');
    }

    // Validate required fields
    if (video.videoUrl == null) {
      throw Exception('Video is required');
    }

    if (video.productImageUrls.isEmpty) {
      throw Exception('At least one product image is required');
    }

    if (video.productName.isEmpty || video.productDescription.isEmpty) {
      throw Exception('Product details are required');
    }

    // Run content moderation
    // Note: This is a simplified check - in real app would analyze actual video
    final moderationResult = await _moderationService.moderateMedia(
      media: MediaItem(
        id: video.id,
        type: MediaType.video,
        createdAt: video.createdAt,
      ),
      caption: video.productDescription,
      isSponsored: true,
    );

    if (moderationResult.isBlocked) {
      // Update video status to rejected
      final index = _videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        _videos[index] = SponsoredVideo(
          id: video.id,
          userId: video.userId,
          videoUrl: video.videoUrl,
          thumbnailUrl: video.thumbnailUrl,
          productImageUrls: video.productImageUrls,
          productName: video.productName,
          productDescription: video.productDescription,
          price: video.price,
          currency: video.currency,
          discount: video.discount,
          productCategory: video.productCategory,
          brandName: video.brandName,
          productUrl: video.productUrl,
          sku: video.sku,
          variant: video.variant,
          offerValidity: video.offerValidity,
          affiliateId: video.affiliateId,
          status: SponsoredVideoStatus.rejected,
          rejectionReason: moderationResult.reason,
          createdAt: video.createdAt,
          submittedAt: DateTime.now(),
        );
      }
      return SponsoredVideoStatus.rejected;
    }

    // Update video status to under review
    final index = _videos.indexWhere((v) => v.id == videoId);
    if (index != -1) {
      _videos[index] = SponsoredVideo(
        id: video.id,
        userId: video.userId,
        videoUrl: video.videoUrl,
        thumbnailUrl: video.thumbnailUrl,
        productImageUrls: video.productImageUrls,
        productName: video.productName,
        productDescription: video.productDescription,
        price: video.price,
        currency: video.currency,
        discount: video.discount,
        productCategory: video.productCategory,
        brandName: video.brandName,
        productUrl: video.productUrl,
        sku: video.sku,
        variant: video.variant,
        offerValidity: video.offerValidity,
        affiliateId: video.affiliateId,
        status: SponsoredVideoStatus.underReview,
        createdAt: video.createdAt,
        submittedAt: DateTime.now(),
      );
    }

    return SponsoredVideoStatus.underReview;
  }

  Future<bool> approveVideo(String videoId) async {
    final video = await getVideo(videoId);
    if (video == null) return false;

    final index = _videos.indexWhere((v) => v.id == videoId);
    if (index != -1) {
      _videos[index] = SponsoredVideo(
        id: video.id,
        userId: video.userId,
        videoUrl: video.videoUrl,
        thumbnailUrl: video.thumbnailUrl,
        productImageUrls: video.productImageUrls,
        productName: video.productName,
        productDescription: video.productDescription,
        price: video.price,
        currency: video.currency,
        discount: video.discount,
        productCategory: video.productCategory,
        brandName: video.brandName,
        productUrl: video.productUrl,
        sku: video.sku,
        variant: video.variant,
        offerValidity: video.offerValidity,
        affiliateId: video.affiliateId,
        status: SponsoredVideoStatus.approved,
        createdAt: video.createdAt,
        submittedAt: video.submittedAt,
        approvedAt: DateTime.now(),
        campaignId: 'campaign-${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    return true;
  }

  Future<bool> rejectVideo(String videoId, String reason) async {
    final video = await getVideo(videoId);
    if (video == null) return false;

    final index = _videos.indexWhere((v) => v.id == videoId);
    if (index != -1) {
      _videos[index] = SponsoredVideo(
        id: video.id,
        userId: video.userId,
        videoUrl: video.videoUrl,
        thumbnailUrl: video.thumbnailUrl,
        productImageUrls: video.productImageUrls,
        productName: video.productName,
        productDescription: video.productDescription,
        price: video.price,
        currency: video.currency,
        discount: video.discount,
        productCategory: video.productCategory,
        brandName: video.brandName,
        productUrl: video.productUrl,
        sku: video.sku,
        variant: video.variant,
        offerValidity: video.offerValidity,
        affiliateId: video.affiliateId,
        status: SponsoredVideoStatus.rejected,
        rejectionReason: reason,
        createdAt: video.createdAt,
        submittedAt: video.submittedAt,
      );
    }

    return true;
  }
}
