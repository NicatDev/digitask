import 'dart:convert';

class ReplyDecoded {
  final Map<String, dynamic>? reply;
  final String body;
  const ReplyDecoded({required this.reply, required this.body});
}

ReplyDecoded decodeReply(String raw) {
  const prefix = '@@reply:';
  if (!raw.startsWith(prefix)) {
    return ReplyDecoded(reply: null, body: raw);
  }
  final end = raw.indexOf('@@', prefix.length);
  if (end == -1) return ReplyDecoded(reply: null, body: raw);
  final jsonPart = raw.substring(prefix.length, end);
  var body = raw.substring(end + 2);
  if (body.startsWith('\n')) body = body.substring(1);
  try {
    final obj = jsonDecode(jsonPart);
    if (obj is Map<String, dynamic>) {
      return ReplyDecoded(reply: obj, body: body);
    }
    return ReplyDecoded(reply: null, body: raw);
  } catch (_) {
    return ReplyDecoded(reply: null, body: raw);
  }
}

String stripReply(String raw) => decodeReply(raw).body;

String encodeReply({
  required String body,
  required int replyId,
  required String replySender,
  required String replySnippet,
}) {
  final meta = <String, dynamic>{
    'id': replyId,
    'sender': replySender,
    'snippet': replySnippet,
  };
  return '@@reply:${jsonEncode(meta)}@@\n$body';
}

