import 'package:flutter/material.dart';

Color taskTypeColorFromApi(Map<String, dynamic> task) {
  final details = task['task_type_details'];
  if (details is! Map) return Colors.blueGrey;
  final hex = details['color']?.toString().trim();
  if (hex == null || hex.isEmpty) return Colors.blueGrey;
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return Colors.blueGrey;
  try {
    return Color(int.parse(h, radix: 16));
  } catch (_) {
    return Colors.blueGrey;
  }
}

String taskTypeNameFromApi(Map<String, dynamic> task) {
  final details = task['task_type_details'];
  if (details is Map && details['name'] != null) {
    return details['name'].toString();
  }
  return 'Növ təyin edilməyib';
}

/// Prefer nested `task_services` names; else resolve `services` IDs via [allServices].
List<String> taskServiceLabels(Map<String, dynamic> task, List<dynamic> allServices) {
  final out = <String>[];
  final ts = task['task_services'];
  if (ts is List) {
    for (final e in ts) {
      if (e is Map) {
        final n = e['service_name']?.toString();
        if (n != null && n.isNotEmpty) out.add(n);
      }
    }
  }
  if (out.isNotEmpty) return out;
  final ids = task['services'];
  if (ids is! List || allServices.isEmpty) return out;
  for (final id in ids) {
    final sid = id is int ? id : int.tryParse(id.toString());
    if (sid == null) continue;
    for (final svc in allServices) {
      if (svc is! Map) continue;
      final rawId = svc['id'];
      final svcId = rawId is int ? rawId : int.tryParse(rawId.toString());
      if (svcId == sid) {
        final n = svc['name']?.toString();
        if (n != null && n.isNotEmpty) out.add(n);
        break;
      }
    }
  }
  return out;
}
