import 'api_client.dart';
import 'api_exceptions.dart';

/// REST API wrapper for `/vendors` endpoints (used by the React web app).
///
/// Endpoints:
///   GET /vendors/:id – Get vendor details (public/protected depending on backend)
///   GET /vendors/profile/:id/public – Public vendor profile (React web app)
class VendorsApi {
  static final VendorsApi _instance = VendorsApi._internal();
  factory VendorsApi() => _instance;
  VendorsApi._internal();

  final ApiClient _client = ApiClient();

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _normalizeVendorProfile(dynamic res) {
    final root = _asMap(res);
    final data = _asMap(root['data']);
    final vendor = _asMap(root['vendor'] ?? data['vendor']);
    final user = _asMap(root['user'] ?? root['userId'] ?? root['user_id'] ?? data['user'] ?? data['userId'] ?? data['user_id']);

    if (root.isNotEmpty) {
      final normalized = <String, dynamic>{...root};
      if (data.isNotEmpty) {
        normalized.addAll(data);
      }
      if (vendor.isNotEmpty) {
        normalized['vendor'] = vendor;
      }
      if (user.isNotEmpty) {
        normalized['user'] = user;
        normalized['user_id'] = user;
      }
      return normalized;
    }

    return <String, dynamic>{
      if (vendor.isNotEmpty) 'vendor': vendor,
      if (user.isNotEmpty) 'user': user,
      if (data.isNotEmpty) ...data,
    };
  }

  Future<Map<String, dynamic>> getVendorById(String vendorUserId) async {
    final res = await _client.get('/vendors/$vendorUserId');
    return _normalizeVendorProfile(res);
  }

  Future<Map<String, dynamic>> getVendorPublicProfile(String vendorUserId) async {
    final uid = vendorUserId.trim();
    if (uid.isEmpty) throw ArgumentError('vendorUserId cannot be empty');
    try {
      final res = await _client.get('/vendors/profile/$uid/public');
      return _normalizeVendorProfile(res);
    } on ApiException catch (e) {
      if (e.statusCode == 304) {
        final fallback = await _client.get(
          '/vendors/profile/$uid/public',
          queryParams: <String, String>{
            '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );
        return _normalizeVendorProfile(fallback);
      }
      rethrow;
    }
  }
}
