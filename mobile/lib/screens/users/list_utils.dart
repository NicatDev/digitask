List<dynamic> unwrapApiList(dynamic data) {
  if (data is Map && data.containsKey('results')) {
    final r = data['results'];
    if (r is List) return List<dynamic>.from(r);
    return [];
  }
  if (data is List) return List<dynamic>.from(data);
  return [];
}

int? asApiIntId(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
