import 'dart:async';

class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  Future<List<Map<String, dynamic>>> fetchAds({int limit = 20, int offset = 0}) async {
    // Return empty list as Ads API is not yet available
    return [];
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
