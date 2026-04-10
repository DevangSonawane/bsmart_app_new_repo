import 'dart:async';
import '../api/ads_api.dart';
import '../models/ad_category_model.dart';
import '../models/ad_model.dart';

class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  final AdsApi _adsApi = AdsApi();

  List<AdCategory> _ensureAllFirst(List<AdCategory> categories) {
    final allIndex = categories.indexWhere((c) {
      final id = c.id.trim().toLowerCase();
      final name = c.name.trim().toLowerCase();
      return id == 'all' || name == 'all' || (id.startsWith('all') && id.length <= 4) || (name.startsWith('all') && name.length <= 4);
    });
    if (allIndex <= 0) return categories;

    final reordered = List<AdCategory>.from(categories);
    final allCategory = reordered.removeAt(allIndex);
    reordered.insert(0, allCategory);
    return reordered;
  }

  static const List<String> fallbackCategories = [
    'All',
    'Accessories',
    'Action Figures',
    'Art Supplies',
    'Baby Products',
    'Beauty & Personal Care',
    'Books',
    'Clothing & Apparel',
    'Electronics',
    'Food & Beverages',
    'Footwear',
    'Gaming',
    'Health & Wellness',
    'Home & Kitchen',
    'Jewellery',
    'Mobile & Tablets',
    'Pet Supplies',
    'Sports & Fitness',
    'Toys',
    'Travel',
  ];

  Future<List<AdCategory>> fetchCategories() async {
    try {
      final categories = await _adsApi.getCategories();
      if (categories.isNotEmpty) {
        final normalized = categories
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();

        final apiCategories = normalized
            .map((id) => AdCategory(id: id, name: _prettyCategoryName(id)))
            .toList();

        final hasAll = apiCategories.any((c) => c.id.toLowerCase() == 'all');
        if (!hasAll) {
          return _ensureAllFirst([AdCategory(id: 'All', name: 'All'), ...apiCategories]);
        }
        return _ensureAllFirst(apiCategories);
      }
    } catch (_) {
      // Graceful fallback to local categories if categories endpoint fails.
    }

    return getFallbackCategories();
  }

  List<AdCategory> getFallbackCategories() {
    final categories = fallbackCategories
        .map((name) => AdCategory(id: name, name: name))
        .toList();
    return _ensureAllFirst(categories);
  }

  String _prettyCategoryName(String raw) {
    final normalized = raw.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return raw;

    return normalized.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }

  Future<void> addCategory(String name) async {
    await _adsApi.addCategory(name);
  }

  Future<List<Ad>> fetchAds({String category = 'All'}) async {
    final rawList = await _adsApi.getFeed(category: category);
    return rawList.map(Ad.fromApi).where((ad) => ad.id.isNotEmpty).toList();
  }

  Future<List<Ad>> fetchUserAds({
    required String userId,
    String? category,
  }) async {
    final rawList = await _adsApi.getUserAds(userId, category: category);
    return rawList.map(Ad.fromApi).where((ad) => ad.id.isNotEmpty).toList();
  }

  Future<List<Ad>> fetchAllAds() async {
    final rawList = await _adsApi.getAllAds();
    return rawList.map(Ad.fromApi).where((ad) => ad.id.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>> searchAds({
    String? q,
    String? category,
    String? hashtag,
    String? userId,
    String? status,
    String? contentType,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _adsApi.searchAds(
      q: q,
      category: category,
      hashtag: hashtag,
      userId: userId,
      status: status,
      contentType: contentType,
      page: page,
      limit: limit,
    );

    final rawAds = (res['ads'] as List<dynamic>? ?? const <dynamic>[]);
    final rawUsers = (res['users'] as List<dynamic>? ?? const <dynamic>[]);
    final ads = rawAds
        .whereType<Map>()
        .map((item) => Ad.fromApi(Map<String, dynamic>.from(item)))
        .where((ad) => ad.id.isNotEmpty)
        .toList();
    final users = rawUsers
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    int toInt(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    return {
      'total': toInt(res['total'], ads.length),
      'page': toInt(res['page'], page),
      'limit': toInt(res['limit'], limit),
      'totalPages': toInt(res['totalPages'], 1),
      'ads': ads,
      'users': users,
    };
  }

  Future<Ad?> fetchAdById(String adId) async {
    final raw = await _adsApi.getAdById(adId);
    if (raw == null) return null;
    final ad = Ad.fromApi(raw);
    if (ad.id.isEmpty) return null;
    return ad;
  }

  Future<bool> deleteAd(String adId) async {
    return _adsApi.deleteAd(adId);
  }

  Future<Map<String, dynamic>> recordAdView({
    required String adId,
    required String userId,
  }) async {
    return _adsApi.recordAdView(adId: adId, userId: userId);
  }

  Future<Map<String, dynamic>> recordAdClick({
    required String adId,
    String? userId,
  }) async {
    return _adsApi.recordAdClick(adId: adId, userId: userId);
  }

  Future<Map<String, dynamic>> likeAd({
    required String adId,
    String? userId,
  }) async {
    return _adsApi.likeAd(adId: adId, userId: userId);
  }

  Future<Map<String, dynamic>> dislikeAd({
    required String adId,
    String? userId,
  }) async {
    return _adsApi.dislikeAd(adId: adId, userId: userId);
  }

  Future<Map<String, dynamic>> saveAd(String adId) async {
    return _adsApi.saveAd(adId);
  }

  Future<Map<String, dynamic>> unsaveAd(String adId) async {
    return _adsApi.unsaveAd(adId);
  }

  Future<List<Map<String, dynamic>>> fetchAdComments(String adId) async {
    return _adsApi.getAdComments(adId);
  }

  Future<List<Map<String, dynamic>>> fetchAdCommentsPaged(
    String adId, {
    int page = 1,
    int limit = 20,
  }) async {
    return _adsApi.getAdCommentsPaged(adId, page: page, limit: limit);
  }

  Future<Map<String, dynamic>> addAdComment({
    required String adId,
    required String text,
    String? parentId,
  }) async {
    return _adsApi.addAdComment(
      adId: adId,
      text: text,
      parentId: parentId,
    );
  }

  Future<List<Map<String, dynamic>>> fetchAdCommentReplies(
      String commentId) async {
    return _adsApi.getAdCommentReplies(commentId);
  }

  Future<bool> deleteAdComment(String commentId) async {
    return _adsApi.deleteAdComment(commentId);
  }

  Future<Map<String, dynamic>> toggleAdCommentLike(String commentId) async {
    return _adsApi.toggleAdCommentLike(commentId);
  }

  Future<Map<String, dynamic>> toggleAdCommentDislike(String commentId) async {
    return _adsApi.toggleAdCommentDislike(commentId);
  }

  Future<Map<String, dynamic>> getAdStats(String adId) async {
    return _adsApi.getAdStats(adId);
  }

  Future<Map<String, dynamic>> updateAdMetadata({
    required String adId,
    required Map<String, dynamic> metadata,
  }) async {
    return _adsApi.updateAdMetadata(adId: adId, metadata: metadata);
  }

  Future<Map<String, dynamic>> getAdWalletHistory({
    required String adId,
    int page = 1,
    int limit = 20,
  }) async {
    return _adsApi.getAdWalletHistory(adId: adId, page: page, limit: limit);
  }

  Future<Map<String, dynamic>> adminUpdateAdStatus({
    required String adId,
    required String status,
    String? rejectionReason,
  }) async {
    return _adsApi.adminUpdateAdStatus(
      adId: adId,
      status: status,
      rejectionReason: rejectionReason,
    );
  }

  Future<bool> adminDeleteAd(String adId) async {
    return _adsApi.adminDeleteAd(adId);
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    // Return null as Products API is not yet available
    return null;
  }

  Future<bool> createAd(Map<String, dynamic> data) async {
    final res = await _adsApi.createAd(data);
    final ok = res['success'];
    if (ok is bool) return ok;
    return true;
  }
}
