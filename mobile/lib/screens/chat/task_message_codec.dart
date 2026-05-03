import 'dart:convert';

const String taskMessagePrefix = '[[DIGITASK_TASK_V1:';
const String taskMessageSuffix = ']]';

String encodeTaskChatMessage(Map<String, dynamic> payload) {
  final encoded = base64Encode(utf8.encode(jsonEncode(payload)));
  return '$taskMessagePrefix$encoded$taskMessageSuffix';
}

Map<String, dynamic>? decodeTaskChatMessage(String content) {
  final text = content.trim();
  if (!text.startsWith(taskMessagePrefix) || !text.endsWith(taskMessageSuffix)) {
    return null;
  }
  try {
    final raw = text.substring(taskMessagePrefix.length, text.length - taskMessageSuffix.length);
    final parsed = jsonDecode(utf8.decode(base64Decode(raw)));
    if (parsed is Map<String, dynamic> && parsed['kind'] == 'task') return parsed;
  } catch (_) {}
  return null;
}

String stripTaskChatMessage(String content) {
  final decoded = decodeTaskChatMessage(content);
  if (decoded == null) return content;
  final task = decoded['task'] is Map ? decoded['task'] as Map : const {};
  return 'Tapşırıq #${task['id'] ?? ''}: ${task['title'] ?? ''}'.trim();
}

Map<String, dynamic> buildTaskChatPayload(Map<String, dynamic> task, String note) {
  return {
    'kind': 'task',
    'version': 1,
    'note': note.trim(),
    'task': {
      'id': task['id'],
      'title': task['title'] ?? '',
      'status': task['status'] ?? '',
      'register_number': task['customer_register_number'] ?? '',
      'customer': task['customer_name'] ?? '',
      'assignees': task['assigned_to_names'] is List ? task['assigned_to_names'] : [],
    },
  };
}
