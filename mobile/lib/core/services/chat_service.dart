import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/models/chat_model.dart';
import 'package:mobile/models/user_model.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();

  factory ChatService() {
    return _instance;
  }

  ChatService._internal();

  final _storage = const FlutterSecureStorage();
  
  // State
  final ValueNotifier<List<ChatGroup>> groups = ValueNotifier<List<ChatGroup>>([]);
  final ValueNotifier<List<ChatMessage>> currentMessages = ValueNotifier<List<ChatMessage>>([]);
  final ValueNotifier<int> totalUnreadCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isLoadingMessages = ValueNotifier<bool>(false);

  // WebSocket
  WebSocketChannel? _channel;
  int? _currentGroupId;
  // int? _currentUserId; // Removed in favor of currentUser.value.id getter below

  final ValueNotifier<User?> currentUser = ValueNotifier<User?>(null);

  int? get currentUserId => currentUser.value?.id;

  void setCurrentUser(User user) {
      currentUser.value = user;
  }

  Future<void> fetchGroups() async {
    try {
      final response = await ApiClient().dio.get('/chat/groups/');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        groups.value = data.map((json) => ChatGroup.fromJson(json)).toList();
        _updateTotalUnreadCount();
      }
    } catch (e) {
      print('Error fetching groups: $e');
    }
  }

  Future<void> fetchMessages(int groupId, {int page = 1}) async {
    if (page == 1) {
      currentMessages.value = [];
      isLoadingMessages.value = true;
    }

    try {
      final response = await ApiClient().dio.get(
          '/chat/messages/', 
          queryParameters: {'group': groupId, 'page': page}
      );
      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> results = data['results'];
        final newMessages = results.map((json) => ChatMessage.fromJson(json)).toList();
        
        if (page == 1) {
          currentMessages.value = newMessages; // Backend returns newest first. UI reverses it?
          // Wait, UI ListView.builder usually builds top-down. 
          // If we want newest at bottom, we usually use reverse: true in ListView
          // and have list ordered [newest, ..., oldest].
          // Let's check UI. UI likely uses reverse: true.
          // If backend returns [newest, 2nd newest...], and UI reverse:true, 
          // then index 0 (bottom) is newest. That works.
          
        } else {
          // Append older messages to the END of the list (which is the TOP of the UI)
          currentMessages.value = [...currentMessages.value, ...newMessages];
        }
      }
    } catch (e) {
      print('Error fetching messages: $e');
    } finally {
      if (page == 1) isLoadingMessages.value = false;
    }
  }

  Future<void> markAsRead(int groupId) async {
      try {
          await ApiClient().dio.post('/chat/messages/mark-read/', data: {'group_id': groupId});
          // Decrement unread count locally? 
          // Better to re-fetch groups to get accurate count or just set it to 0 for this group.
          final updatedGroups = groups.value.map((g) {
              if (g.id == groupId) {
                  return ChatGroup(
                      id: g.id, 
                      name: g.name, 
                      ownerId: g.ownerId, 
                      createdAt: g.createdAt,
                      image: g.image,
                      isActive: g.isActive,
                      onlyOwnerCanSend: g.onlyOwnerCanSend,
                      unreadCount: 0,
                      lastMessage: g.lastMessage,
                      lastMessageSender: g.lastMessageSender,
                      lastMessageAt: g.lastMessageAt
                  );
              }
              return g;
          }).toList();
          groups.value = updatedGroups;
          _updateTotalUnreadCount();
      } catch (e) {
          print('Error marking as read: $e');
      }
  }

  Future<void> sendMessage(int groupId, String content) async {
    // Optimistic update could happen here, but for now we rely on WebSocket echo or API response
    // Actually, backend seems to save via WebSocket receive() or we can post via API
    // Let's use WebSocket for sending if connected, or API if not. 
    // Usually API is safer for "send and confirmation", WebSocket for broadcasting.
    // Based on backend consumers.py: "Receive message from WebSocket ... Save message to database"
    // So we can send via WebSocket.
    
    if (_channel != null && _currentGroupId == groupId) {
      _channel!.sink.add(jsonEncode({
        'message': content,
      }));
      // Mark as read after sending so our own message doesn't count as unread
      await markAsRead(groupId);
    } else {
      // Fallback or initialization error
      print('WebSocket not connected for this group');
    }
  }
  
  Future<void> createGroup(String name) async {
      try {
          await ApiClient().dio.post('/chat/groups/', data: {'name': name});
          await fetchGroups();
      } catch (e) {
          print('Error creating group: $e');
          rethrow;
      }
  }

  Future<void> deleteGroup(int groupId) async {
      try {
          await ApiClient().dio.delete('/chat/groups/$groupId/');
          await fetchGroups();
      } catch (e) {
          print('Error deleting group: $e');
          rethrow;
      }
  }

  Future<ChatGroup> getGroupDetails(int groupId) async {
    try {
      final response = await ApiClient().dio.get('/chat/groups/$groupId/');
      return ChatGroup.fromJson(response.data);
    } catch (e) {
      print('Error fetching group details: $e');
      rethrow;
    }
  }

  Future<void> addMember(int groupId, int userId) async {
    try {
      await ApiClient().dio.post('/chat/groups/$groupId/add-member/', data: {'user_id': userId});
      await fetchGroups(); // Refresh list to update counts/members if needed
    } catch (e) {
      print('Error adding member: $e');
      rethrow;
    }
  }

  Future<void> removeMember(int groupId, int userId) async {
    try {
      await ApiClient().dio.post('/chat/groups/$groupId/remove-member/', data: {'user_id': userId});
      await fetchGroups();
    } catch (e) {
      print('Error removing member: $e');
      rethrow;
    }
  }

  Future<List<User>> searchUsers(String query) async {
    try {
      final response = await ApiClient().dio.get('/users/', queryParameters: {'search': query});
      // Assuming paginated response or list, check structure. 
      // Account api "getUsers" usually returns paginated results.
      // Adjust based on typical API response.
      final data = response.data;
      List<dynamic> results = [];
      if (data is Map && data.containsKey('results')) {
          results = data['results'];
      } else if (data is List) {
          results = data;
      }
      
      return results.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      print('Error searching users: $e');
      rethrow;
    }
  }


  Timer? _reconnectTimer;
  bool _isConnecting = false;

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    if (_currentGroupId == null) return; // Don't reconnect if we left the chat

    print('Scheduling chat reconnect in 5 seconds...');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      print('Attempting to reconnect Chat WebSocket...');
      if (_currentGroupId != null) {
          connectToGroup(_currentGroupId!);
      }
    });
  }

  // Connect to Specific Group Chat
  Future<void> connectToGroup(int groupId) async {
    if (_isConnecting) return;
    // If we are already connected to this group, return
    if (_currentGroupId == groupId && _channel != null && _channel!.closeCode == null) return;
    
    _isConnecting = true;
    
    // Clean up previous connection if switching groups
    if (_currentGroupId != null && _currentGroupId != groupId) {
        disconnect();
    }
    
    _currentGroupId = groupId;
    
    final token = await _storage.read(key: 'access_token');
    if (token == null) {
        _isConnecting = false;
        return;
    }
    
    // Construct WebSocket URL from AppConstants.baseUrl
    final uri = Uri.parse(AppConstants.baseUrl);
    String host = uri.host;
    
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final portPart = (uri.port != 80 && uri.port != 443 && uri.hasPort) ? ':${uri.port}' : '';
    final wsUrl = '$wsScheme://$host$portPart/ws/chat/groups/$groupId/';
    
    try {
      print('Connecting to Chat Socket: $wsUrl');
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl?token=$token'),
      );

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('Chat WebSocket Error: $error');
          _scheduleReconnect();
        },
        onDone: () {
            print('Chat WebSocket Closed');
            _scheduleReconnect();
        },
      );
      print('Chat Socket Connected');
      
      // Fetch latest messages on connect/reconnect to ensure sync
      fetchMessages(groupId, page: 1);
      
    } catch (e) {
      print('Chat WebSocket Connection Error: $e');
      _scheduleReconnect();
    } finally {
        _isConnecting = false;
    }
  }
  
  void disconnect() {
      _reconnectTimer?.cancel();
      final groupId = _currentGroupId;
      if (_channel != null) {
          _channel!.sink.close();
          _channel = null;
      }
      _currentGroupId = null;
      _isConnecting = false;
      // Mark messages as read when leaving chat to prevent stale unread counts
      if (groupId != null) {
          markAsRead(groupId);
      }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      // Backend definition:
      // 'message': message, 'sender': sender_name, 'sender_id': self.user.id, ...
      
      final chatMessage = ChatMessage(
          id: data['id'],
          groupId: _currentGroupId!,
          senderId: data['sender_id'],
          senderName: data['sender'],
          content: data['message'],
          createdAt: DateTime.parse(data['created_at']),
          isRead: currentUserId != null && data['sender_id'] == currentUserId, 
      );
      // Append to current messages
      if (_currentGroupId == chatMessage.groupId) {
          final list = List<ChatMessage>.from(currentMessages.value);
          list.insert(0, chatMessage);
          currentMessages.value = list;
      }
      
      // Update Group List (Last Message & Unread Count)
      final List<ChatGroup> currentGroups = List.from(groups.value);
      final index = currentGroups.indexWhere((g) => g.id == chatMessage.groupId);
      
      if (index != -1) {
          final group = currentGroups[index];
          // If we are in the chat, unread count doesn't increase (or we mark read instantly)
          // But here let's assume if it matches _currentGroupId, we don't increment.
          final bool isCurrentChat = _currentGroupId == chatMessage.groupId;
          
          // Also check if I am the sender, unread shouldn't increase
          final bool isMe = currentUserId != null && chatMessage.senderId == currentUserId;
          
          final int newUnread = (isCurrentChat || isMe) ? group.unreadCount : group.unreadCount + 1;
          
          final updatedGroup = ChatGroup(
              id: group.id,
              name: group.name,
              image: group.image,
              ownerId: group.ownerId,
              isActive: group.isActive,
              onlyOwnerCanSend: group.onlyOwnerCanSend,
              createdAt: group.createdAt,
              unreadCount: newUnread,
              lastMessage: chatMessage.content,
              lastMessageSender: chatMessage.senderName,
              lastMessageAt: chatMessage.createdAt
          );
          
          currentGroups.removeAt(index);
          currentGroups.insert(0, updatedGroup); // Move to top
          groups.value = currentGroups;
          _updateTotalUnreadCount();
      }
      
    } catch (e) {
      print('Error parsing chat message: $e');
    }
  }

  void handleGlobalNotification(Map<String, dynamic> data) {
      try {
          final int groupId = data['group_id'];
          
          // If we are currently in this chat
          if (_currentGroupId == groupId) {
              // If socket is disconnected, fetch messages to sync what we missed
              if (_channel == null || _channel!.closeCode != null) {
                  print('Global notification received for current group but socket disconnected. Fetching messages...');
                  fetchMessages(groupId, page: 1);
              }
              return;
          }
          
          // If I am the sender, don't increment unread count
          final int? senderId = data['sender_id'];
          if (senderId != null && currentUserId != null && senderId == currentUserId) return;
          
          final List<ChatGroup> currentGroups = List.from(groups.value);
          final index = currentGroups.indexWhere((g) => g.id == groupId);
          
          if (index != -1) {
              final group = currentGroups[index];
              final updatedGroup = ChatGroup(
                  id: group.id,
                  name: group.name,
                  image: group.image,
                  ownerId: group.ownerId,
                  isActive: group.isActive,
                  onlyOwnerCanSend: group.onlyOwnerCanSend,
                  createdAt: group.createdAt,
                  unreadCount: group.unreadCount + 1, // Increment unread
                  lastMessage: data['message_content'],
                  lastMessageSender: data['sender_name'],
                  lastMessageAt: DateTime.parse(data['created_at'])
              );
              
              currentGroups.removeAt(index);
              currentGroups.insert(0, updatedGroup);
              groups.value = currentGroups;
              _updateTotalUnreadCount();
          } else {
              // New group or not in list? Fetch all to be safe.
              fetchGroups();
          }
      } catch (e) {
          print('Error handling global chat notification: $e');
      }
  }
  
  void _updateTotalUnreadCount() {
      int count = 0;
      for (var group in groups.value) {
          count += group.unreadCount;
      }
      totalUnreadCount.value = count;
  }
  
  // Call this when entering a chat to mark as read (local update mostly, backend needs explicit call?)
  // Backend likely marks read when fetched? Or we need an endpoint.
  // Checking views... usually fetching messages marks them as read or there is a specific endpoint.
  // We'll assume for now fetching updates the status on backend or we'll add a mark_read call if we find one.
}
