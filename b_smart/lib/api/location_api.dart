import 'api_client.dart';
import '../config/api_config.dart';
import '../models/location_place.dart';

class LocationApi {
  static final LocationApi _instance = LocationApi._internal();
  factory LocationApi() => _instance;
  LocationApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  Future<List<LocationPlace>> searchPlaces(
    String query, {
    String? sessionToken,
  }) async {
    final params = <String, String>{
      'query': query,
    };
    if (sessionToken != null && sessionToken.isNotEmpty) {
      params['sessionToken'] = sessionToken;
    }
    final res = await _client.get(
      '$_basePath/location/search',
      queryParams: params,
    );
    final places = (res is Map ? res['places'] : null);
    if (places is! List) return const [];
    return places
        .whereType<Map>()
        .map((e) => LocationPlace.fromJson(Map<String, dynamic>.from(e)))
        .where((place) => place.displayText.isNotEmpty)
        .toList();
  }
}
