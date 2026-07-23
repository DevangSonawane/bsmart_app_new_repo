import 'api_client.dart';
import '../config/api_config.dart';

/// REST API wrapper for `/gift-cards` endpoints.
class GiftCardsApi {
  static final GiftCardsApi _instance = GiftCardsApi._internal();
  factory GiftCardsApi() => _instance;
  GiftCardsApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  List<Map<String, dynamic>> _parseGiftCardsList(dynamic res) {
    List<dynamic> rawList = const [];
    if (res is List) {
      rawList = res;
    } else if (res is Map) {
      if (res['data'] is List) {
        rawList = res['data'] as List;
      } else if (res['data'] is Map) {
        final data = res['data'] as Map;
        if (data['gift_cards'] is List) {
          rawList = data['gift_cards'] as List;
        } else if (data['items'] is List) {
          rawList = data['items'] as List;
        } else if (data['results'] is List) {
          rawList = data['results'] as List;
        } else if (data['cards'] is List) {
          rawList = data['cards'] as List;
        }
      } else if (res['gift_cards'] is List) {
        rawList = res['gift_cards'] as List;
      } else if (res['items'] is List) {
        rawList = res['items'] as List;
      } else if (res['results'] is List) {
        rawList = res['results'] as List;
      } else if (res['cards'] is List) {
        rawList = res['cards'] as List;
      }
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  /// `GET /api/gift-cards/active` - list active gift cards for the app.
  Future<List<Map<String, dynamic>>> getActiveGiftCards({
    String? category,
    String? type,
  }) async {
    final query = <String, String>{};
    final normalizedCategory = category?.trim();
    final normalizedType = type?.trim();

    if (normalizedCategory != null &&
        normalizedCategory.isNotEmpty &&
        normalizedCategory.toLowerCase() != 'all') {
      query['category'] = normalizedCategory;
    }
    if (normalizedType != null &&
        normalizedType.isNotEmpty &&
        normalizedType.toLowerCase() != 'all') {
      query['type'] = normalizedType;
    }

    final res = await _client.get(
      '$_basePath/gift-cards/active',
      queryParams: query.isEmpty ? null : query,
    );
    return _parseGiftCardsList(res);
  }

  /// `POST /api/gift-card-orders` - buy a gift card denomination with coins.
  Future<Map<String, dynamic>> createGiftCardOrder({
    required String giftCardId,
    required int bcoins,
  }) async {
    final id = giftCardId.trim();
    if (id.isEmpty) {
      throw ArgumentError('giftCardId cannot be empty');
    }
    if (bcoins <= 0) {
      throw ArgumentError('bcoins must be greater than zero');
    }

    final res = await _client.post(
      '$_basePath/gift-card-orders',
      body: {
        'gift_card_id': id,
        'bcoins': bcoins,
      },
    );

    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  /// `GET /api/gift-card-orders/my` - list the current user's gift card orders.
  Future<List<Map<String, dynamic>>> getMyGiftCardOrders(
      {String? status}) async {
    final normalizedStatus = status?.trim().toLowerCase();
    final query = (normalizedStatus == null ||
            normalizedStatus.isEmpty ||
            normalizedStatus == 'all')
        ? null
        : <String, String>{'status': normalizedStatus};

    final res = await _client.get(
      '$_basePath/gift-card-orders/my',
      queryParams: query,
    );

    List<dynamic> rawList = const [];
    if (res is List) {
      rawList = res;
    } else if (res is Map<String, dynamic>) {
      if (res['data'] is List) {
        rawList = res['data'] as List;
      } else if (res['data'] is Map && (res['data'] as Map)['orders'] is List) {
        rawList = (res['data'] as Map)['orders'] as List;
      } else if (res['orders'] is List) {
        rawList = res['orders'] as List;
      } else if (res['items'] is List) {
        rawList = res['items'] as List;
      } else if (res['results'] is List) {
        rawList = res['results'] as List;
      }
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
