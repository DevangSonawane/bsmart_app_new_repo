import 'api_client.dart';

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

  Future<Map<String, dynamic>> getVendorById(String vendorUserId) async {
    final res = await _client.get('/vendors/$vendorUserId');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getVendorPublicProfile(String vendorUserId) async {
    final uid = vendorUserId.trim();
    if (uid.isEmpty) throw ArgumentError('vendorUserId cannot be empty');
    final res = await _client.get('/vendors/profile/$uid/public');
    return res as Map<String, dynamic>;
  }
}
