import '../models/ship_address.dart';
import 'api_client.dart';

/// REST API wrapper for the saved-address endpoints.
///
///   GET    /addresses            – list saved addresses, default first
///   POST   /addresses            – save a new address
///   PATCH  /addresses/:id        – update an address (owner only)
///   DELETE /addresses/:id        – delete an address (soft delete)
///   PATCH  /addresses/:id/default – set an address as the default
///
/// Access: authenticated. The backend owns default-address promotion rules
/// (first saved becomes default; deleting the default promotes the next
/// most recent), so this layer never promotes locally — it re-reads the
/// list after every mutation.
class AddressApi {
  AddressApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// GET /addresses — default address first.
  Future<List<ShipAddress>> list() async {
    final data = await _client.get('/addresses');
    return parseList(data);
  }

  /// Maps a response payload into addresses, default first.
  ///
  /// Invalid entries are dropped *before* the default is applied, so a
  /// malformed first row can never leave every address un-defaulted.
  static List<ShipAddress> parseList(dynamic data) {
    final items = _listOf(data);
    if (items.isEmpty) return const [];
    final valid = items
        .map(ShipAddress.fromApiJson)
        .where((a) => a.line1.trim().isNotEmpty)
        .toList();
    if (valid.isEmpty) return const [];
    return [
      valid.first.copyWith(isDefault: true),
      ...valid.skip(1).map((a) => a.copyWith(isDefault: false)),
    ];
  }

  /// POST /addresses — the first address saved becomes the default server-side.
  Future<List<ShipAddress>> create(ShipAddress address) async {
    await _client.post('/addresses', body: address.toApiJson());
    return list();
  }

  /// PATCH /addresses/:id
  Future<List<ShipAddress>> update(String id, ShipAddress address) async {
    await _client.patch(
      '/addresses/${Uri.encodeComponent(id)}',
      body: address.toApiJson(),
    );
    return list();
  }

  /// DELETE /addresses/:id — soft delete on the backend.
  Future<List<ShipAddress>> remove(String id) async {
    await _client.delete('/addresses/${Uri.encodeComponent(id)}');
    return list();
  }

  /// PATCH /addresses/:id/default
  Future<List<ShipAddress>> setDefault(String id) async {
    await _client.patch('/addresses/${Uri.encodeComponent(id)}/default');
    return list();
  }

  /// Public for testing: unwraps the address array from any supported
  /// response envelope.
  static List<Map<String, dynamic>> listFrom(dynamic data) => _listOf(data);

  /// Tolerates a bare list, a `data`/`addresses`/`results` envelope, or a
  /// single-object wrapper around one address.
  static List<Map<String, dynamic>> _listOf(dynamic data) {
    if (data == null) return const [];
    if (data is List) return _stringMaps(data);
    if (data is Map) {
      final map = _stringMap(data);
      for (final key in const ['addresses', 'data', 'results', 'items']) {
        final value = map[key];
        if (value is List) return _stringMaps(value);
        if (value is Map) {
          final nested = _stringMap(value);
          for (final nestedKey in const ['addresses', 'items', 'results']) {
            final nestedValue = nested[nestedKey];
            if (nestedValue is List) return _stringMaps(nestedValue);
          }
        }
      }
      // A single address object (e.g. from POST).
      if (map['address_line1'] != null || map['pincode'] != null) {
        return [map];
      }
    }
    return const [];
  }

  static List<Map<String, dynamic>> _stringMaps(List<dynamic> items) => items
      .whereType<Map>()
      .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
      .toList();

  static Map<String, dynamic> _stringMap(Map source) =>
      source.map((key, value) => MapEntry(key.toString(), value));
}
