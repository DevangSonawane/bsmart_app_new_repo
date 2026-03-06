import 'dart:async';
import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/ad_category_model.dart';
import '../models/ad_model.dart';

class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
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

  List<AdCategory> getCategories() {
    return fallbackCategories.map((name) => AdCategory(id: name, name: name)).toList();
  }

  Future<List<Ad>> fetchAds({String category = 'All'}) async {
    final params = category == 'All' ? null : <String, String>{'category': category};
    final res = await _client.get('$_basePath/ads/feed', queryParams: params);

    List<dynamic> rawList = const [];
    if (res is List) {
      rawList = res;
    } else if (res is Map) {
      if (res['data'] is List) {
        rawList = res['data'] as List;
      } else if (res['data'] is Map && (res['data'] as Map)['ads'] is List) {
        rawList = (res['data'] as Map)['ads'] as List;
      } else if (res['ads'] is List) {
        rawList = res['ads'] as List;
      }
    }

    return rawList
        .whereType<Map>()
        .map((item) => Ad.fromApi(Map<String, dynamic>.from(item)))
        .where((ad) => ad.id.isNotEmpty)
        .toList();
  }

  Future<void> likeAd(String adId) async {
    await _client.post('$_basePath/ads/$adId/like');
  }

  Future<void> dislikeAd(String adId) async {
    await _client.post('$_basePath/ads/$adId/dislike');
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    // Return null as Products API is not yet available
    return null;
  }

  Future<bool> createAd(Map<String, dynamic> data) async {
    // Return false as Ads API is not yet available
    return false;
  }
}
