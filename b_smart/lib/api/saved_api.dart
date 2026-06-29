import '../config/api_config.dart';
import 'api_client.dart';

/// REST API wrapper for saved content.
///
/// Expected endpoints:
///   GET /saved
///   GET /saved/{userId}
class SavedApi {
  static final SavedApi _instance = SavedApi._internal();
  factory SavedApi() => _instance;
  SavedApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  Future<dynamic> getSavedItems() async {
    return _client.get('$_basePath/saved');
  }

  Future<dynamic> getSavedItemsForUser(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return const <String, dynamic>{};
    return _client.get('$_basePath/saved/$id');
  }
}
