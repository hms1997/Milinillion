import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'websocket_service.dart';
import 'package:provider/provider.dart';

// Helper function to format the timestamp
String formatTimestamp(BuildContext context, DateTime timestamp) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final dateToFormat = DateTime(timestamp.year, timestamp.month, timestamp.day);

  if (dateToFormat == today) {
    return TimeOfDay.fromDateTime(timestamp).format(context);
  } else if (dateToFormat == yesterday) {
    return 'Yesterday';
  } else {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

// Conversation model is unchanged
class Conversation {
  final String contactId;
  final String displayName;
  final String? profilePictureUrl;
  String lastMessage;
  String status;
  DateTime timestamp;
  final DateTime? lastSeen;
  int unreadCount;
  Conversation({ required this.contactId, required this.displayName, this.profilePictureUrl, required this.lastMessage, required this.status, required this.timestamp, this.lastSeen, this.unreadCount = 0 });
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(contactId: json['contactId'], displayName: json['displayName'], profilePictureUrl: json['profilePictureUrl'], lastMessage: json['lastMessage'], status: json['status'], timestamp: DateTime.parse(json['timestamp']), lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null);
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => WebSocketService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Clone',
      theme: ThemeData(
        primaryColor: const Color(0xff075E54),
        colorScheme: ColorScheme.fromSwatch().copyWith(primary: const Color(0xff075E54), secondary: const Color(0xff25D366)),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Color(0xff25D366)),
      ),
      debugShowCheckedModeBanner: false,
      home: const ChatsListScreen(),
    );
  }
}

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});
  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String? _token;
  String? _currentUserId;
  
  final Map<String, bool> _typingStatus = {};
  
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;

  final String yourComputerIp = "192.168.0.109"; 
  final String loginMobileNumber = "111";
  final String loginDisplayName = "Himangshu";

  @override
  void initState() {
    super.initState();
    _loginAndFetchData();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loginAndFetchData() async {
    try {
      final loginResponse = await http.post(
        Uri.parse('http://$yourComputerIp:8080/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'mobileNumber': loginMobileNumber, 'displayName': loginDisplayName}),
      );
      if (loginResponse.statusCode != 200) throw Exception('Failed to log in');
      
      final loginData = json.decode(loginResponse.body);
      final token = loginData['token'];
      final currentUserId = loginData['userId'];
      setState(() {
        _token = token;
        _currentUserId = currentUserId;
      });

      final wsService = context.read<WebSocketService>();
      wsService.activate(token, yourComputerIp, currentUserId);
      await wsService.syncInitialPresence(token, yourComputerIp);

      final convResponse = await http.get(
        Uri.parse('http://$yourComputerIp:8080/api/conversations'),
        headers: { 'Authorization': 'Bearer $token' },
      );
      if (convResponse.statusCode != 200) throw Exception('Failed to load conversations');
      
      final List<dynamic> data = json.decode(convResponse.body);
      final conversations = data.map((json) => Conversation.fromJson(json)).toList();
      
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });

      _listenForRealtimeUpdates();

    } catch (e) {
      print("Error during login/fetch: $e");
      setState(() {
        _isLoading = false;
      });
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversation: conversation,
          currentUserId: _currentUserId,
          token: _token,
          yourComputerIp: yourComputerIp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Watch the service to get live presence updates
    final wsService = context.watch<WebSocketService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: Icon(
              wsService.isConnected ? Icons.wifi : Icons.wifi_off,
              color: wsService.isConnected ? Colors.white : Colors.red[300],
            ),
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
                // ✅ Determine online status from the service's live cache
                final isOnline = wsService.onlineUserIds.contains(conversation.contactId);
                
                return ChatListItem(
                  conversation: conversation,
                  isTyping: isTyping,
                  isOnline: isOnline, // ✅ Pass the live status down
                  onTap: () => _onConversationTapped(conversation),
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

class ChatListItem extends StatelessWidget {
  final Conversation conversation;
  final bool isTyping;
  final bool isOnline; // ✅ Receive the live online status
  final VoidCallback onTap;

  const ChatListItem({
    super.key, 
    required this.conversation,
    required this.isTyping,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: conversation.profilePictureUrl ?? 'https://picsum.photos/200',
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) => const Icon(Icons.person, size: 28),
            fit: BoxFit.cover,
            width: 56,
            height: 56,
          ),
        ),
      ),
      // ✅ The title is now a Column to structure the two rows of text
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Name, Online Status, and Timestamp
          Row(
            children: [
              Text(conversation.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(width: 6),
              // ✅ Conditionally show the green "online" text
              if (isOnline && !isTyping)
                Text(
                  'online',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              const Spacer(), // Pushes the timestamp to the far right
              Text(
                formatTimestamp(context, conversation.timestamp),
                style: TextStyle(
                  color: conversation.unreadCount > 0 ? Theme.of(context).colorScheme.secondary : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Bottom Row: Last Message/Typing and Unread Count
          Row(
            children: [
              Expanded(
                child: Text(
                  isTyping ? 'typing...' : conversation.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isTyping ? Theme.of(context).colorScheme.secondary : Colors.grey[600],
                    fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              if (conversation.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    conversation.unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                )
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
