import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/api/api_client.dart'; // To get current user id? Or store it?
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/models/chat_model.dart';
import 'package:intl/intl.dart';
import 'package:mobile/screens/chat/group_settings_modal.dart';

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
    if (_controller.text.trim().isEmpty) return;
    _chatService.sendMessage(widget.groupId, _controller.text.trim());
    _controller.clear();
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
                    
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
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
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
      return Align(
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
                  children: [
                      if (!isMe) 
                          Text(message.senderName, style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                          )),
                      Text(
                          message.content,
                          style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 2),
                      Text(
                          DateFormat('HH:mm').format(message.createdAt),
                          style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white70 : Colors.black54,
                          ),
                      ),
                  ],
              ),
          ),
      );
  }
}
