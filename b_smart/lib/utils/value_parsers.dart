int? tryParseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  final normalized = raw.replaceAll(',', '');
  return int.tryParse(normalized) ?? double.tryParse(normalized)?.toInt();
}

int parseInt(dynamic value, {int fallback = 0}) {
  return tryParseInt(value) ?? fallback;
}

int? tryReadInt(Map<dynamic, dynamic>? map, List<String> keys) {
  if (map == null) return null;
  for (final k in keys) {
    if (!map.containsKey(k)) continue;
    final parsed = tryParseInt(map[k]);
    if (parsed != null) return parsed;
  }
  return null;
}

