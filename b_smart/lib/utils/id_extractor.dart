String? extractEntityId(dynamic value) {
  return _extractEntityId(value, const <String>{
    '_id',
    'id',
    'user_id',
    'userId',
    'vendorId',
    'vendor_id',
    'ownerId',
    'owner_id',
  });
}

String? _extractEntityId(dynamic value, Set<String> keys) {
  if (value == null) return null;

  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('{') || trimmed.contains(':')) {
      final match = RegExp(
        r'(?<!\w)(?:_id|id|user_id|userId|vendorId|vendor_id|ownerId|owner_id)\s*[:=]\s*([^,}]+)',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (match != null) {
        final candidate = match.group(1)?.trim().replaceAll('"', '');
        if (candidate != null && candidate.isNotEmpty) return candidate;
      }
    }
    return trimmed;
  }

  if (value is num) {
    return value.toString();
  }

  if (value is Map) {
    final map = Map<String, dynamic>.from(value);

    for (final key in keys) {
      final direct = map[key];
      final extracted = _extractEntityId(direct, keys);
      if (extracted != null && extracted.isNotEmpty) return extracted;
    }

    for (final entry in map.values) {
      final extracted = _extractEntityId(entry, keys);
      if (extracted != null && extracted.isNotEmpty) return extracted;
    }
    return null;
  }

  if (value is Iterable) {
    for (final item in value) {
      final extracted = _extractEntityId(item, keys);
      if (extracted != null && extracted.isNotEmpty) return extracted;
    }
    return null;
  }

  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
