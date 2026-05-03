import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/api/api_client.dart'; // To get current user id? Or store it?
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/models/chat_model.dart';
import 'package:intl/intl.dart';
import 'package:mobile/screens/chat/group_settings_modal.dart';
import 'package:mobile/screens/chat/reply_codec.dart';
import 'package:mobile/screens/chat/task_message_codec.dart';
import 'package:mobile/screens/tasks/widgets/task_detail_modal.dart';

class ChatDetailScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const ChatDetailScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoadingMore = false;
  int? _currentUserId;
  ChatMessage? _replyTo;
  final List<String> _emojis = const ['😀', '😁', '😂', '😊', '😍', '👍', '🙏', '👏', '🔥', '✅', '⚠️', '❤️'];

  @override
  void initState() {
    super.initState();
    _fetchCurrentUser();
    _chatService.connectToGroup(widget.groupId);
    _chatService.fetchMessages(widget.groupId);
    _chatService.markAsRead(widget.groupId);
    
    _scrollController.addListener(() {
        if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
            _loadMore();
        }
    });
  }

// ... existing methods ...

  Future<void> _fetchCurrentUser() async {
      try {
          final response = await ApiClient().dio.get('/users/me/');
          if (mounted) {
              setState(() {
                  _currentUserId = response.data['id'];
              });
          }
      } catch (e) {
          print(e);
      }
  }

  Future<void> _loadMore() async {
      if (_isLoadingMore) return;
      setState(() { _isLoadingMore = true; });
      _currentPage++;
      await _chatService.fetchMessages(widget.groupId, page: _currentPage);
      if (mounted) {
          setState(() { _isLoadingMore = false; });
      }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    String payload = text;
    final r = _replyTo;
    if (r != null) {
      final decoded = decodeReply(r.content);
      final snippet = stripTaskChatMessage(decoded.body).trim();
      payload = encodeReply(
        body: text,
        replyId: r.id,
        replySender: r.senderName,
        replySnippet: snippet.length > 80 ? snippet.substring(0, 80) : snippet,
      );
    }

    _chatService.sendMessage(widget.groupId, payload);
    _controller.clear();
    setState(() => _replyTo = null);
  }

  Future<void> _openTaskFromChat(dynamic taskId) async {
    final id = int.tryParse(taskId?.toString() ?? '');
    if (id == null) return;
    try {
      final res = await ApiClient().dio.get('/tasks/tasks/$id/');
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => TaskDetailModal(
          task: Map<String, dynamic>.from(res.data),
          canCommentActivity: false,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tapşırıq açılmadı')));
      }
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emojis
                .map(
                  (emoji) => InkWell(
                    onTap: () {
                      _controller.text = '${_controller.text}$emoji';
                      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Bu gün';
    if (d == yesterday) return 'Dünən';
    return DateFormat('dd.MM.yyyy').format(date);
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _dayLabel(date),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _chatService.disconnect();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
            IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                    showDialog(
                        context: context,
                        builder: (context) => GroupSettingsModal(
                            groupId: widget.groupId, 
                            groupName: widget.groupName
                        )
                    );
                },
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<List<ChatMessage>>(
              valueListenable: _chatService.currentMessages,
              builder: (context, messages, child) {
                if (messages.isEmpty && _isLoadingMore) {
                    return const Center(child: CircularProgressIndicator());
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, 
                  itemCount: messages.length + 1, 
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: _isLoadingMore 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                                : const SizedBox.shrink(), 
                          ),
                        );
                    }
                    
                    final message = messages[index];
                    final isMe = message.senderId == _currentUserId;
                    final bool showDateSeparator = index == messages.length - 1 ||
                        !_isSameDay(message.createdAt, messages[index + 1].createdAt);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDateSeparator) _buildDateSeparator(message.createdAt),
                        _buildMessageBubble(message, isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyTo != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Cavab: ${_replyTo!.senderName} #${_replyTo!.id} — ${stripReply(_replyTo!.content)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _replyTo = null),
                          icon: const Icon(Icons.close, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      ],
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.blueGrey),
                      onPressed: _showEmojiPicker,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
      final decoded = decodeReply(message.content);
      final taskPayload = decodeTaskChatMessage(decoded.body);
      final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.82;
      return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Dismissible(
            key: ValueKey('msg_${message.id}'),
            direction: DismissDirection.endToStart, // swipe left
            confirmDismiss: (dir) async {
              setState(() => _replyTo = message);
              return false;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: Colors.transparent,
              child: const Icon(Icons.reply, color: Colors.blue),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue : Colors.white,
                    boxShadow: [
                      if (!isMe)
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        )
                    ],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                      bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isMe)
                        Text(
                          message.senderName,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (decoded.reply != null) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 6, bottom: 8),
                          padding: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: isMe ? Colors.white70 : Colors.black26,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cavab: ${decoded.reply?['sender'] ?? ''} #${decoded.reply?['id'] ?? ''}',
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                (decoded.reply?['snippet'] ?? '').toString(),
                                softWrap: true,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isMe ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (taskPayload != null)
                        _buildTaskMessageCard(taskPayload, isMe)
                      else
                        Text(
                          decoded.body,
                          softWrap: true,
                          style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                        ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(message.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.reply, size: 16),
                            color: isMe ? Colors.white70 : Colors.blueGrey,
                            onPressed: () => setState(() => _replyTo = message),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            visualDensity: VisualDensity.compact,
                            splashRadius: 14,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      );
  }

  Widget _buildTaskMessageCard(Map<String, dynamic> payload, bool isMe) {
    final task = payload['task'] is Map ? payload['task'] as Map : const {};
    final assignees = task['assignees'] is List ? (task['assignees'] as List).join(', ') : '';
    final note = (payload['note'] ?? '').toString();
    return InkWell(
      onTap: () => _openTaskFromChat(task['id']),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.12) : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isMe ? Colors.white30 : Colors.blue.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${task['id'] ?? ''} ${task['title'] ?? 'Tapşırıq'}',
              style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 6),
            _taskLine('Status', task['status'], isMe),
            _taskLine('Qeydiyyat', task['register_number'], isMe),
            _taskLine('Müştəri', task['customer'], isMe),
            _taskLine('İcraçılar', assignees.isEmpty ? '-' : assignees, isMe),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(note, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _taskLine(String label, dynamic value, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label, style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : Colors.black54)),
          ),
          Expanded(
            child: Text(
              (value == null || value.toString().isEmpty) ? '-' : value.toString(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isMe ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
