import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../models/conversation.dart';
import '../services/websocket_service.dart';
import '../models/message.dart';
import '../widgets/chat/message_bubbles.dart';
import '../widgets/chat/message_input_bar.dart';
import 'image_preview_screen.dart';

String formatLastSeen(BuildContext context, DateTime? lastSeen) {
  if (lastSeen == null) return 'last seen a long time ago';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final dateToFormat = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
  final time = TimeOfDay.fromDateTime(lastSeen).format(context);
  if (dateToFormat == today) { return 'last seen today at $time'; } 
  else if (dateToFormat == yesterday) { return 'last seen yesterday at $time'; } 
  else { return 'last seen on ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}'; }
}

class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final String? currentUserId;
  final String? token;
  final String yourComputerIp;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.token,
    required this.yourComputerIp,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoadingMore = false;
  bool _isLastPage = false;
  int _currentPage = 0;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _sentAckSubscription;
  StreamSubscription? _statusUpdateSubscription;
  StreamSubscription? _typingSubscription;

  String _typingIndicatorText = '';
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _listenToWebsocketStreams();
    _textController.addListener(_handleTyping);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        _fetchMessages(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _sentAckSubscription?.cancel();
    _statusUpdateSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _listenToWebsocketStreams() {
    final wsService = context.read<WebSocketService>();
    _messageSubscription = wsService.messageStream.listen((messageData) {
      final receivedMessage = Message.fromJson(messageData);
      if (receivedMessage.senderId == widget.conversation.contactId) {
        setState(() {
          _messages.insert(0, receivedMessage);
        });
        _sendBulkStatusUpdate([receivedMessage.id], 'READ', receivedMessage.senderId);
      }
    });
    _sentAckSubscription = wsService.sentAckStream.listen((ackData) {
      final tempId = ackData['tempId'];
      final permanentId = ackData['permanentId'];
      final messageIndex = _messages.indexWhere((m) => m.id == tempId);
      if (messageIndex != -1) {
        setState(() {
          _messages[messageIndex].id = permanentId;
          _messages[messageIndex].status = 'SENT';
        });
      }
    });
    _statusUpdateSubscription = wsService.statusUpdateStream.listen((statusData) {
      final List<String> messageIds = List<String>.from(statusData['messageIds']);
      final newStatus = statusData['status'];
      setState(() {
        for (var msg in _messages) {
          if (messageIds.contains(msg.id)) {
            msg.status = newStatus;
          }
        }
      });
    });
    _typingSubscription = wsService.typingIndicatorStream.listen((typingData) {
      final senderId = typingData['senderId'];
      final isTyping = typingData['isTyping'];
      final senderName = typingData['senderName'];
      if (senderId == widget.conversation.contactId) {
        setState(() {
          _typingIndicatorText = isTyping ? '$senderName is typing...' : '';
        });
      }
    });
  }

  void _handleTyping() {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _sendTypingIndicator(true);
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _sendTypingIndicator(false);
    });
  }

  void _sendTypingIndicator(bool isTyping) {
    final wsService = context.read<WebSocketService>();
    if (!wsService.isConnected || widget.currentUserId == null) return;
    final indicator = {
      'senderId': widget.currentUserId,
      'receiverId': widget.conversation.contactId,
      'isTyping': isTyping,
    };
    wsService.send('/app/chat.typing', indicator);
  }

  Future<void> _fetchMessages({bool loadMore = false}) async {
    if (_isLoadingMore || (loadMore && _isLastPage)) return;
    setState(() {
      _isLoadingMore = true;
      if (!loadMore) _messages.clear();
    });
    if (widget.token == null) return;
    try {
      final contactId = widget.conversation.contactId;
      final response = await http.get(
        Uri.parse('http://${widget.yourComputerIp}:8080/api/messages?userId=$contactId&page=$_currentPage&size=30'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> messageList = data['content'];
        final newMessages = messageList.map((json) => Message.fromJson(json)).toList();
        setState(() {
          _messages.addAll(newMessages);
          _isLastPage = data['last'];
          if (!_isLastPage) _currentPage++;
        });
        if (!loadMore) {
          final unreadMessageIds = newMessages
              .where((msg) => msg.senderId == widget.conversation.contactId && msg.status != 'READ')
              .map((msg) => msg.id)
              .toList();
          if (unreadMessageIds.isNotEmpty) {
            _sendBulkStatusUpdate(unreadMessageIds, 'READ', widget.conversation.contactId);
          }
        }
      } else {
        throw Exception('Failed to load messages. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print(e);
    } finally {
      if(mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _sendBulkStatusUpdate(List<String> messageIds, String status, String senderId) {
    if (messageIds.isEmpty) return;
    final wsService = context.read<WebSocketService>();
    if (!wsService.isConnected) return;
    final update = {'messageIds': messageIds, 'status': status, 'senderId': senderId};
    wsService.send('/app/chat.updateStatus', update);
  }

  void _sendMessage(WebSocketService wsService) {
    _typingTimer?.cancel();
    _sendTypingIndicator(false);
    final text = _textController.text;
    if (text.isEmpty) return;
    
    final tempId = 'unsent-${DateTime.now().millisecondsSinceEpoch}';
    final chatMessage = {
      'id': tempId,
      'senderId': widget.currentUserId,
      'receiverId': widget.conversation.contactId,
      'caption': text,
      'mediaUrl': null,
      'mediaType': 'TEXT',
      'timestamp': DateTime.now().toIso8601String()
    };
    wsService.send('/app/chat.sendMessage', chatMessage);
    
    final newMessage = Message(
      id: tempId,
      senderId: widget.currentUserId!,
      caption: text,
      mediaType: 'TEXT',
      status: 'UNSENT',
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.insert(0, newMessage);
    });
    _textController.clear();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && mounted) {
      // Navigate to the preview screen and wait for it to pop
      final result = await Navigator.of(context).push<Message>(
        MaterialPageRoute(
          builder: (context) => ImagePreviewScreen(
            imageFile: File(pickedFile.path),
            currentUserId: widget.currentUserId!,
            receiverId: widget.conversation.contactId,
          ),
        ),
      );

      // If the preview screen returned a message, add it to our list
      if (result != null) {
        setState(() {
          _messages.insert(0, result);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    final wsService = context.watch<WebSocketService>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 20,
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: widget.conversation.profilePictureUrl ?? 'https://picsum.photos/200',
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.person),
                  fit: BoxFit.cover,
                  width: 40,
                  height: 40,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Consumer<WebSocketService>(
              builder: (context, service, child) {
                final isOnline = service.onlineUserIds.contains(widget.conversation.contactId);
                final lastSeenTime = service.getLastSeenForUser(widget.conversation.contactId) ?? widget.conversation.lastSeen;
                final statusText = _typingIndicatorText.isNotEmpty
                    ? _typingIndicatorText
                    : (isOnline ? 'online' : formatLastSeen(context, lastSeenTime));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.conversation.displayName, style: const TextStyle(fontSize: 18)),
                    Text(
                      statusText, 
                      style: TextStyle(
                        fontSize: 13,
                        color: _typingIndicatorText.isNotEmpty ? Theme.of(context).colorScheme.secondary : Colors.white,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          Image.network(
            'https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png',
            height: double.infinity,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          _messages.isEmpty && !_isLoadingMore
              ? const Center(child: Text('No messages yet'))
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: _messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return _isLoadingMore && !_isLastPage
                          ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                          : const SizedBox.shrink();
                    }
                    final message = _messages[index];
                    final bool isMe = message.senderId == widget.currentUserId;
                    return isMe
                        ? SenderBubble(message: message)
                        : ReceiverBubble(message: message);
                  },
                ),
          Align(
            alignment: Alignment.bottomCenter,
            child: MessageInputBar(
              controller: _textController,
              onSend: () => _sendMessage(wsService),
              onAttach: _pickImage,
              isConnected: wsService.isConnected,
            ),
          ),
        ],
      ),
    );
  }
}
