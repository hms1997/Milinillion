import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../services/websocket_service.dart';
import '../widgets/chat_list_item.dart';

class ChatsListScreen extends StatefulWidget {
  final String token;
  final String currentUserId;
  const ChatsListScreen({super.key, required this.token, required this.currentUserId});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  final Map<String, bool> _typingStatus = {};
  
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;

  final String yourComputerIp = "192.168.0.109"; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDataAndConnect();
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchDataAndConnect() async {
    try {
      final wsService = context.read<WebSocketService>();
      wsService.activate(widget.token, yourComputerIp, widget.currentUserId);
      await wsService.syncInitialPresence(widget.token, yourComputerIp);

      final convResponse = await http.get(
        Uri.parse('http://$yourComputerIp:8080/api/conversations'),
        headers: { 'Authorization': 'Bearer ${widget.token}' },
      );
      if (convResponse.statusCode != 200) throw Exception('Failed to load conversations');
      
      final List<dynamic> data = json.decode(convResponse.body);
      final conversations = data.map((json) => Conversation.fromJson(json)).toList();
      
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
        _listenForRealtimeUpdates();
      }
    } catch (e) {
      print("Error during fetch/connect: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenForRealtimeUpdates() {
    final wsService = context.read<WebSocketService>();

    _messageSubscription = wsService.messageStream.listen((messageData) {
      final senderId = messageData['senderId'];
      final content = messageData['content'];
      final index = _conversations.indexWhere((c) => c.contactId == senderId);
      if (index != -1) {
        setState(() {
          final conversation = _conversations[index];
          conversation.lastMessage = content;
          conversation.timestamp = DateTime.now();
          conversation.unreadCount++;
          _conversations.removeAt(index);
          _conversations.insert(0, conversation);
        });
      }
    });

    _typingSubscription = wsService.typingIndicatorStream.listen((typingData) {
      final senderId = typingData['senderId'];
      final isTyping = typingData['isTyping'];
      setState(() {
        _typingStatus[senderId] = isTyping;
      });
    });
  }
  
  void _onConversationTapped(Conversation conversation) {
    final index = _conversations.indexWhere((c) => c.contactId == conversation.contactId);
    if (index != -1) {
      setState(() {
        _conversations[index].unreadCount = 0;
      });
    }
    // Navigation is now handled inside the ChatListItem widget
  }

  @override
  Widget build(BuildContext context) {
    final wsService = context.watch<WebSocketService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Milinillion'),
        elevation: 0,
        actions: [
          Consumer<WebSocketService>(
            builder: (context, wsService, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: Icon(
                  wsService.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: wsService.isConnected ? Colors.white : Colors.red[300],
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final conversation = _conversations[index];
                final isTyping = _typingStatus[conversation.contactId] ?? false;
                final isOnline = wsService.onlineUserIds.contains(conversation.contactId);
                
                return ChatListItem(
                  conversation: conversation,
                  isTyping: isTyping,
                  isOnline: isOnline,
                  onTap: () => _onConversationTapped(conversation),
                  currentUserId: widget.currentUserId,
                  token: widget.token,
                  yourComputerIp: yourComputerIp,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.chat, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.update), label: 'Updates'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Communities'),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Calls'),
        ],
      ),
    );
  }
}
