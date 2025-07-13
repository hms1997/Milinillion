import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/conversation.dart'; // Import the Conversation model
import '../screens/chat_screen.dart'; // Import the ChatScreen for navigation

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

class ChatListItem extends StatelessWidget {
  final Conversation conversation;
  final bool isTyping;
  final bool isOnline;
  final VoidCallback onTap;
  
  // We need to pass these down to the ChatScreen
  final String? currentUserId;
  final String? token;
  final String yourComputerIp;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.isTyping,
    required this.isOnline,
    required this.onTap,
    required this.currentUserId,
    required this.token,
    required this.yourComputerIp,
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(conversation.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(width: 6),
              if (isOnline && !isTyping)
                Text(
                  'online',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              const Spacer(),
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
      onTap: () {
        // The onTap logic now calls the passed-in function first, then navigates.
        onTap();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversation: conversation,
              currentUserId: currentUserId,
              token: token,
              yourComputerIp: yourComputerIp,
            ),
          ),
        );
      },
    );
  }
}
