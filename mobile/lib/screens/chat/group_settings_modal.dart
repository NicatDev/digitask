import 'package:flutter/material.dart';
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/models/chat_model.dart';
// import 'package:mobile/core/api/api_client.dart'; // If needed for member search

class GroupSettingsModal extends StatefulWidget {
  final int groupId;
  final String groupName;

  const GroupSettingsModal({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupSettingsModal> createState() => _GroupSettingsModalState();
}

class _GroupSettingsModalState extends State<GroupSettingsModal> {
  final ChatService _chatService = ChatService();
  bool _isLoading = false;

  Future<void> _deleteGroup() async {
      setState(() { _isLoading = true; });
      try {
          await _chatService.deleteGroup(widget.groupId);
          if (mounted) {
              Navigator.pop(context); // Close modal
              Navigator.pop(context); // Close chat screen, back to list
          }
      } catch (e) {
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting group: $e')),
              );
          }
      } finally {
          if (mounted) setState(() { _isLoading = false; });
      }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text('Settings: ${widget.groupName}'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete Group', style: TextStyle(color: Colors.red)),
                    onTap: _isLoading ? null : () {
                        // Confirm dialog
                        showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                                title: const Text('Confirm Delete'),
                                content: const Text('Are you sure you want to delete this group?'),
                                actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx), 
                                        child: const Text('Cancel')
                                    ),
                                    TextButton(
                                        onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteGroup();
                                        }, 
                                        child: const Text('Delete', style: TextStyle(color: Colors.red))
                                    ),
                                ],
                            )
                        );
                    },
                ),
            ],
        ),
        actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('Close')
            ),
        ],
    );
  }
}
