import 'package:flutter/material.dart';
import 'package:mobile/core/services/chat_service.dart';
import 'package:mobile/models/chat_model.dart';
import 'package:mobile/models/user_model.dart';

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
  ChatGroup? _groupDetails;
  int? _currentUserId; // Need to fetch current user to know if owner

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails();
    // In a real app, current user might be stored in a provider or singleton
    // For now, we might not know who "I" am unless we fetch "me" or pass it down.
    // ChatDetailScreen fetches it. We could pass it in. 
    // Or just check if I can remove members (backend blocks it anyway).
    // Let's rely on backend error for permission, or try to hide buttons if not owner?
    // The frontend checks `group.owner.id === currentUser.id`.
    // We can fetch details which includes ownerId. But we don't know our own ID here easily without prop.
    // Let's assume for now everyone sees the delete button but it fails if not owner.
  }

  Future<void> _fetchGroupDetails() async {
    setState(() { _isLoading = true; });
    try {
      final group = await _chatService.getGroupDetails(widget.groupId);
      if (mounted) {
        setState(() {
          _groupDetails = group;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading details: $e')));
      }
    }
  }

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

  Future<void> _addMember() async {
      // Show search dialog
      final User? selectedUser = await showDialog<User>(
          context: context,
          builder: (ctx) => UserSearchDialog(
              existingMemberIds: _groupDetails?.members?.map((m) => m.id).toList() ?? []
          ),
      );

      if (selectedUser != null) {
          setState(() { _isLoading = true; });
          try {
              await _chatService.addMember(widget.groupId, selectedUser.id);
              await _fetchGroupDetails(); // Refresh list
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User added')));
              }
          } catch (e) {
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding member: $e')));
              }
          } finally {
              if (mounted) setState(() { _isLoading = false; });
          }
      }
  }

  Future<void> _removeMember(int userId) async {
       setState(() { _isLoading = true; });
          try {
              await _chatService.removeMember(widget.groupId, userId);
              await _fetchGroupDetails(); // Refresh list
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User removed')));
              }
          } catch (e) {
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing member: $e')));
              }
          } finally {
              if (mounted) setState(() { _isLoading = false; });
          }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text('Settings: ${widget.groupName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: _isLoading && _groupDetails == null 
              ? const Center(child: CircularProgressIndicator())
              : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Add Member Button
                    SizedBox(
                        width: double.infinity,
                        height: 50, // Increased height
                        child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add Member', style: TextStyle(fontSize: 16)),
                            onPressed: _addMember,
                            style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                        ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Members:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    
                    // Members List
                    if (_groupDetails?.members != null && _groupDetails!.members!.isNotEmpty)
                        Flexible(
                            child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _groupDetails!.members!.length,
                                itemBuilder: (context, index) {
                                    final member = _groupDetails!.members![index];
                                    final isOwner = member.id == _groupDetails!.ownerId;
                                    return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                            backgroundImage: member.avatar != null ? NetworkImage(member.avatar!) : null,
                                            child: member.avatar == null ? Text(member.fullName[0].toUpperCase()) : null,
                                        ),
                                        title: Text(member.fullName),
                                        subtitle: Text(member.email),
                                        trailing: isOwner 
                                            ? null 
                                            : IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                                onPressed: () => _removeMember(member.id),
                                            ),
                                    );
                                },
                            ),
                        )
                    else 
                        const Text('No members found'),

                    const Divider(),
                    
                    // Delete Group Option
                    ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text('Delete Group', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                             showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                    title: const Text('Confirm Delete'),
                                    content: const Text('Are you sure you want to delete this group?'),
                                    actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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

class UserSearchDialog extends StatefulWidget {
    final List<int> existingMemberIds;
    const UserSearchDialog({super.key, this.existingMemberIds = const []});

    @override
    State<UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<UserSearchDialog> {
    final TextEditingController _searchController = TextEditingController();
    final ChatService _chatService = ChatService();
    List<User> _allUsers = [];
    List<User> _filteredUsers = []; // For local filtering or results
    bool _isLoading = false;

    @override
    void initState() {
        super.initState();
        _fetchAllUsers();
        _searchController.addListener(_onSearchChanged);
    }

    @override
    void dispose() {
        _searchController.removeListener(_onSearchChanged);
        _searchController.dispose();
        super.dispose();
    }

    Future<void> _fetchAllUsers() async {
        setState(() { _isLoading = true; });
        try {
            // Passing empty string to get all (or first page of) users
            final results = await _chatService.searchUsers(''); 
            
            // Filter out existing members
            final availableUsers = results.where((u) => !widget.existingMemberIds.contains(u.id)).toList();

            if (mounted) {
                setState(() { 
                    _allUsers = availableUsers;
                    _filteredUsers = availableUsers;
                    _isLoading = false;
                });
            }
        } catch (e) {
            if (mounted) setState(() { _isLoading = false; });
            print('Error fetching users: $e');
        }
    }

    void _onSearchChanged() {
        final query = _searchController.text.toLowerCase().trim();
        setState(() {
            if (query.isEmpty) {
                _filteredUsers = _allUsers;
            } else {
                _filteredUsers = _allUsers.where((user) {
                    return user.fullName.toLowerCase().contains(query) || 
                           user.email.toLowerCase().contains(query);
                }).toList();
            }
        });
    }

    @override
    Widget build(BuildContext context) {
        return AlertDialog(
            title: const Text('Add Member'),
            content: SizedBox(
                width: double.maxFinite,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                                hintText: 'Search by name or email',
                                prefixIcon: Icon(Icons.search),
                            ),
                        ),
                        const SizedBox(height: 10),
                        _isLoading 
                            ? const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(),
                              )
                            : Flexible(
                                child: _filteredUsers.isEmpty 
                                    ? const Padding(
                                        padding: EdgeInsets.all(20.0),
                                        child: Text('No users found'),
                                      )
                                    : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _filteredUsers.length,
                                    itemBuilder: (context, index) {
                                        final user = _filteredUsers[index];
                                        return ListTile(
                                            leading: CircleAvatar(
                                                backgroundImage: user.avatar != null ? NetworkImage(user.avatar!) : null,
                                                child: user.avatar == null ? Text(user.fullName[0].toUpperCase()) : null,
                                            ),
                                            title: Text(user.fullName),
                                            subtitle: Text(user.email),
                                            onTap: () {
                                                Navigator.pop(context, user);
                                            },
                                        );
                                    },
                                ),
                            ),
                    ],
                ),
            ),
            actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ],
        );
    }
}
