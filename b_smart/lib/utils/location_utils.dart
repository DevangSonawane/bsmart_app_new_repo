import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/location_place.dart';

LocationPlace? locationPlaceFromDynamic(dynamic raw) {
  if (raw is LocationPlace) return raw;
  if (raw is Map) {
    return LocationPlace.fromJson(Map<String, dynamic>.from(raw));
  }
  if (raw is String) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return LocationPlace(
      placeId: '',
      name: value,
      address: '',
      fullText: value,
    );
  }
  return null;
}

String locationLabelFromDynamic(dynamic raw) {
  final place = locationPlaceFromDynamic(raw);
  if (place != null) return place.displayText;
  return (raw ?? '').toString().trim();
}

Future<void> openLocationInMaps(LocationPlace place) async {
  final query = place.searchText;
  if (query.isEmpty) return;
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1'
    '&query=${Uri.encodeComponent(query)}'
    '${place.placeId.isNotEmpty ? '&query_place_id=${Uri.encodeComponent(place.placeId)}' : ''}',
  );
  if (kDebugMode) {
    debugPrint('Opening maps: $uri');
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
