import 'package:flutter/material.dart';
import 'package:mobile/core/services/chat_service.dart';

class CreateGroupModal extends StatefulWidget {
  const CreateGroupModal({super.key});

  @override
  State<CreateGroupModal> createState() => _CreateGroupModalState();
}

class _CreateGroupModalState extends State<CreateGroupModal> {
  final TextEditingController _nameController = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isLoading = false;

  Future<void> _create() async {
      if (_nameController.text.trim().isEmpty) return;
      
      setState(() { _isLoading = true; });
      try {
          await _chatService.createGroup(_nameController.text.trim());
          if (mounted) Navigator.pop(context);
      } catch (e) {
          print('Error creating group: $e');
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Failed to create group')),
             );
          }
      } finally {
          if (mounted) setState(() { _isLoading = false; });
      }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Group Name'),
        ),
        actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('Cancel')
            ),
            ElevatedButton(
                onPressed: _isLoading ? null : _create, 
                child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create')
            ),
        ],
    );
  }
}
