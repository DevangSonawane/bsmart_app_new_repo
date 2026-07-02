class LocationPlace {
  final String placeId;
  final String name;
  final String address;
  final String fullText;

  const LocationPlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.fullText,
  });

  factory LocationPlace.fromJson(Map<String, dynamic> json) {
    String s(dynamic value) => (value ?? '').toString().trim();
    return LocationPlace(
      placeId: s(json['placeId'] ?? json['place_id'] ?? json['id']),
      name: s(json['name']),
      address: s(json['address']),
      fullText: s(json['fullText'] ?? json['full_text']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      'address': address,
      'fullText': fullText,
    };
  }

  String get displayText => name.isNotEmpty ? name : fullText;

  String get searchText => fullText.isNotEmpty ? fullText : displayText;
}
