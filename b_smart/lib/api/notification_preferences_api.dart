import 'api_client.dart';

class NotificationPreferencesApi {
  static final NotificationPreferencesApi _instance =
      NotificationPreferencesApi._internal();
  factory NotificationPreferencesApi() => _instance;
  NotificationPreferencesApi._internal();

  final ApiClient _client = ApiClient();

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  bool _extractEnabled(dynamic res) {
    if (res is Map) {
      final map = Map<String, dynamic>.from(res);
      final direct = map['enabled'];
      if (direct != null) return _asBool(direct);
      final data = map['data'];
      if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        if (dm['enabled'] != null) return _asBool(dm['enabled']);
      }
    }
    return false;
  }

  String? _extractMessage(dynamic res) {
    if (res is Map) {
      final map = Map<String, dynamic>.from(res);
      final direct = map['message']?.toString();
      if (direct != null && direct.trim().isNotEmpty) return direct.trim();
      final data = map['data'];
      if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        final m = dm['message']?.toString();
        if (m != null && m.trim().isNotEmpty) return m.trim();
      }
    }
    return null;
  }

  Future<bool> userStatus(String targetUserId) async {
    final id = targetUserId.trim();
    if (id.isEmpty) throw ArgumentError('targetUserId cannot be empty');
    final res = await _client.get('/notification-preferences/users/$id/status');
    return _extractEnabled(res);
  }

  Future<Map<String, dynamic>> toggleUser(String targetUserId) async {
    final id = targetUserId.trim();
    if (id.isEmpty) throw ArgumentError('targetUserId cannot be empty');
    final res =
        await _client.post('/notification-preferences/users/$id/toggle');
    return {
      'enabled': _extractEnabled(res),
      'message': _extractMessage(res),
    };
  }

  Future<bool> vendorStatus(String targetVendorId) async {
    final id = targetVendorId.trim();
    if (id.isEmpty) throw ArgumentError('targetVendorId cannot be empty');
    final res =
        await _client.get('/notification-preferences/vendors/$id/status');
    return _extractEnabled(res);
  }

  Future<Map<String, dynamic>> toggleVendor(String targetVendorId) async {
    final id = targetVendorId.trim();
    if (id.isEmpty) throw ArgumentError('targetVendorId cannot be empty');
    final res =
        await _client.post('/notification-preferences/vendors/$id/toggle');
    return {
      'enabled': _extractEnabled(res),
      'message': _extractMessage(res),
    };
  }
}
