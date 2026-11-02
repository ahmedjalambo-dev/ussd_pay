/// Hive returns `Map<dynamic, dynamic>` when reading back a map it wrote,
/// even though we always write `Map<String, dynamic>`. Casting at the boundary
/// keeps every `fromMap` free of defensive casts.
Map<String, dynamic> asStringMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

/// Reads a `String` field, or `null` if absent or of the wrong type.
String? optString(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is String && value.isNotEmpty ? value : null;
}

/// Reads a `num` field, or `null` if absent or of the wrong type.
num? optNum(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}
