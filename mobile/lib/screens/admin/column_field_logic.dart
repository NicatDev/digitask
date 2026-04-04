// Slug logic parity with web admin ColumnTab (frontend).

const Map<String, String> columnSlugCharMap = {
  'ə': 'e',
  'Ə': 'E',
  'ı': 'i',
  'İ': 'I',
  'ö': 'o',
  'Ö': 'O',
  'ü': 'u',
  'Ü': 'U',
  'ş': 's',
  'Ş': 'S',
  'ç': 'c',
  'Ç': 'C',
  'ğ': 'g',
  'Ğ': 'G',
};

String generateColumnSlug(String name) {
  if (name.isEmpty) return '';
  var slug = name.toLowerCase();
  columnSlugCharMap.forEach((k, v) {
    slug = slug.replaceAll(k, v);
  });
  slug = slug
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_-]'), '')
      .replaceAll(RegExp(r'_+'), '_');
  slug = slug.replaceFirst(RegExp(r'^_+'), '').replaceFirst(RegExp(r'_+$'), '');
  return slug;
}

int? _serviceIdOf(Map<String, dynamic> col) {
  final s = col['service'];
  if (s is int) return s;
  if (s is num) return s.toInt();
  return int.tryParse(s?.toString() ?? '');
}

/// Unique key per service; [excludeColumnId] skips current row when editing.
String generateUniqueColumnKey({
  required String name,
  required int serviceId,
  required List<Map<String, dynamic>> allColumns,
  int? excludeColumnId,
}) {
  var baseKey = generateColumnSlug(name);
  if (baseKey.isEmpty) return '';

  final existingKeys = <String>{};
  for (final col in allColumns) {
    if (_serviceIdOf(col) != serviceId) continue;
    final id = col['id'];
    if (excludeColumnId != null && id == excludeColumnId) continue;
    final k = col['key']?.toString();
    if (k != null && k.isNotEmpty) existingKeys.add(k);
  }

  if (!existingKeys.contains(baseKey)) return baseKey;

  var counter = 2;
  while (existingKeys.contains('${baseKey}_$counter')) {
    counter++;
  }
  return '${baseKey}_$counter';
}
