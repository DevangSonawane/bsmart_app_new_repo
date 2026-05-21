import 'api_client.dart';
import 'api_exceptions.dart';
import '../config/api_config.dart';

/// REST API wrapper for `/wallet` endpoints.
class WalletApi {
  static final WalletApi _instance = WalletApi._internal();
  factory WalletApi() => _instance;
  WalletApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  /// `GET /wallet/me` — current wallet + recent transactions (vendor/member).
  Future<Map<String, dynamic>> me({int? limit, int? page}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = limit.toString();
    if (page != null) query['page'] = page.toString();
    final res = await _client.get('$_basePath/wallet/me', queryParams: query);
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  /// `GET /wallet/member/{userId}/history` — member reward history.
  Future<Map<String, dynamic>> memberHistory({
    required String userId,
    int? limit,
    int? page,
  }) async {
    final id = userId.trim();
    if (id.isEmpty) throw ArgumentError('userId cannot be empty');
    final query = <String, String>{};
    if (limit != null) query['limit'] = limit.toString();
    if (page != null) query['page'] = page.toString();
    final res = await _client.get(
      '$_basePath/wallet/member/$id/history',
      queryParams: query,
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  /// `GET /wallet` — wallet balance / transactions (backend shape varies).
  ///
  /// React web app uses this as a fallback for quickly reading the balance.
  Future<Map<String, dynamic>> wallet({int? limit, int? page}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = limit.toString();
    if (page != null) query['page'] = page.toString();
    final res = await _client.get('$_basePath/wallet', queryParams: query);
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  /// Best-effort balance getter that mirrors the React web app logic:
  /// tries `/wallet/me` then `/wallet`.
  Future<int> getBalance({int? limit}) async {
    Future<int?> tryExtract(Map<String, dynamic> data) async {
      final wallet = data['wallet'];
      final dataNode = data['data'];
      dynamic bal = data['balance'];
      if (bal == null && wallet is Map) bal = wallet['balance'];
      if (bal == null && dataNode is Map) {
        final dn = Map<String, dynamic>.from(dataNode);
        bal = dn['balance'];
        if (bal == null && dn['wallet'] is Map) {
          bal = (dn['wallet'] as Map)['balance'];
        }
      }
      if (bal is int) return bal;
      if (bal is num) return bal.toInt();
      if (bal is String) return int.tryParse(bal);
      return null;
    }

    try {
      final res = await me(limit: limit);
      final bal = await tryExtract(res);
      if (bal != null) return bal;
    } catch (_) {}

    try {
      final res = await wallet(limit: limit);
      final bal = await tryExtract(res);
      if (bal != null) return bal;
    } catch (_) {}

    return 0;
  }

  /// `GET /wallet` returning a transaction list varies across backend versions.
  /// This tries to return a list safely, or throws on server errors.
  Future<List<Map<String, dynamic>>> listAllTransactions({
    int? limit,
    int? page,
  }) async {
    try {
      final res = await wallet(limit: limit, page: page);
      dynamic raw = res['transactions'] ?? res['data'] ?? res['items'] ?? res['results'];
      if (raw is Map && raw['transactions'] is List) raw = raw['transactions'];
      final list = (raw is List ? raw : const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return list;
    } on ApiException {
      rethrow;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }
}

