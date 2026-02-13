import 'package:flutter/material.dart';
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/models/chat_model.dart';
import 'package:mobile/screens/chat/chat_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:mobile/screens/chat/create_group_modal.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _chatService.fetchGroups();
  }

  void _showCreateGroupModal() {
      showDialog(
          context: context, 
          builder: (context) => const CreateGroupModal()
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
            IconButton(
                icon: const Icon(Icons.group_add),
                onPressed: _showCreateGroupModal,
            )
        ],
      ),
      body: ValueListenableBuilder<List<ChatGroup>>(
        valueListenable: _chatService.groups,
        builder: (context, groups, child) {
          if (groups.isEmpty) {
            return const Center(child: Text('No active chats'));
          }
          return ListView.separated(
                itemCount: groups.length,
                separatorBuilder: (ctx, index) => const SizedBox(height: 12),
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                              )
                          ]
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(group.name[0].toUpperCase()),
                        ),
                        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: group.lastMessage != null 
                            ? Text(
                                '${group.lastMessageSender ?? "User"}: ${group.lastMessage}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : const Text('No messages yet'),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (group.lastMessageAt != null)
                              Text(
                                DateFormat('HH:mm').format(group.lastMessageAt!),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            if (group.unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${group.unreadCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatDetailScreen(
                                groupId: group.id,
                                groupName: group.name,
                              ),
                            ),
                          );
                          // Refresh groups when returning to update unread counts
                          _chatService.fetchGroups(); 
                        },
                      ),
                  );
                },
              );
        },
      ),
    );
  }
}
