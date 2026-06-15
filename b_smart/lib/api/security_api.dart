import 'api_client.dart';
import 'auth_api.dart';
import 'users_api.dart';

class SecurityApi {
  static final SecurityApi _instance = SecurityApi._internal();
  factory SecurityApi() => _instance;
  SecurityApi._internal();

  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> getMe() async {
    final res = await AuthApi().me();
    return res;
  }

  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    final res = await _client.get('/auth/sessions');
    final map = _unwrapMap(res);
    final raw = map['sessions'] ?? map['data'] ?? map['items'] ?? map;
    return _toList(raw);
  }

  Future<List<Map<String, dynamic>>> getLoginHistory() async {
    final res = await _client.get('/auth/login-history');
    final map = _unwrapMap(res);
    final raw = map['history'] ?? map['data'] ?? map['items'] ?? map;
    return _toList(raw);
  }

  Future<void> removeSession(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) return;
    await _client.delete('/auth/sessions/$id');
  }

  Future<void> logoutAllDevices() async {
    await _client.post('/auth/logout-all');
  }

  Future<Map<String, dynamic>> updateTwoFA({
    required String userId,
    required bool enabled,
    required String method,
  }) async {
    return UsersApi().updateUser(
      userId,
      extra: <String, dynamic>{
        'twoFA': <String, dynamic>{
          'enabled': enabled,
          'method': method,
        },
      },
    );
  }

  Future<Map<String, dynamic>> updateTwoFAMethod({
    required String userId,
    required String method,
  }) async {
    return UsersApi().updateUser(
      userId,
      extra: <String, dynamic>{
        'twoFA': <String, dynamic>{
          'method': method,
        },
      },
    );
  }

  Map<String, dynamic> _unwrapMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _toList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final inner = map['data'] ?? map['items'] ?? map['sessions'] ?? map['history'];
      return _toList(inner);
    }
    return <Map<String, dynamic>>[];
  }
}
