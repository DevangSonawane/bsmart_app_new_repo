/// A structured delivery address.
///
/// Lives in `models/` rather than `screens/store/` so the REST layer can use
/// it without importing UI code. `store_address_book.dart` re-exports it, so
/// existing imports keep working.
class ShipAddress {
  final String id;
  final String label;
  final String name;
  final String phone;
  final String line1;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;

  const ShipAddress({
    required this.id,
    required this.label,
    required this.name,
    required this.phone,
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    this.isDefault = false,
  });

  String get summaryLine =>
      [line1, city, state, pincode].where((e) => e.trim().isNotEmpty).join(', ');

  /// `shipping_address` for `POST /api/orders/checkout` (Phase 2 md).
  Map<String, String> toShippingJson() => {
        'name': name,
        'phone': phone,
        'address_line1': line1,
        'city': city,
        'state': state,
        'pincode': pincode,
      };

  /// `customer_address` for `POST /api/service-bookings` (Phase 2 md).
  /// Only line1/city/pincode are required by the spec.
  Map<String, String> toCustomerJson() => {
        'address_line1': line1,
        'city': city,
        'pincode': pincode,
      };

  /// Request body for `POST /api/addresses`.
  Map<String, String> toApiJson() => {
        'label': label,
        'name': name,
        'phone': phone,
        'address_line1': line1,
        'city': city,
        'state': state,
        'pincode': pincode,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'name': name,
        'phone': phone,
        'line1': line1,
        'city': city,
        'state': state,
        'pincode': pincode,
        'isDefault': isDefault,
      };

  /// Parses an address from the API.
  ///
  /// `address_line1` is the wire name; `line1` is accepted for compatibility
  /// with previously cached payloads. [fallbackDefault] marks the first entry
  /// as default — `GET /addresses` always returns the default first, and the
  /// backend does not guarantee an explicit flag.
  factory ShipAddress.fromApiJson(
    Map<String, dynamic> json, {
    bool fallbackDefault = false,
  }) {
    return ShipAddress(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Home',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      line1: (json['address_line1'] ?? json['line1'] ?? '').toString(),
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      isDefault: json['is_default'] == true ||
          json['isDefault'] == true ||
          json['default'] == true ||
          fallbackDefault,
    );
  }

  factory ShipAddress.fromJson(Map<String, dynamic> json) => ShipAddress(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? 'Home',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        line1: json['line1']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        pincode: json['pincode']?.toString() ?? '',
        isDefault: json['isDefault'] == true,
      );

  ShipAddress copyWith({
    String? label,
    String? name,
    String? phone,
    String? line1,
    String? city,
    String? state,
    String? pincode,
    bool? isDefault,
  }) {
    return ShipAddress(
      id: id,
      label: label ?? this.label,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      line1: line1 ?? this.line1,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
