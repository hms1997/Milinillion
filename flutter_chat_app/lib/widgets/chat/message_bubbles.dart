import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/message.dart';

// Helper function to format the timestamp for the message bubble
String formatMessageTime(BuildContext context, DateTime timestamp) {
  return TimeOfDay.fromDateTime(timestamp).format(context);
}

// ✅ FIX: The ReceiverBubble now has its own simple content layout
class ReceiverBubble extends StatelessWidget {
  final Message message;
  const ReceiverBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isImage = message.mediaType == 'IMAGE';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: isImage ? const EdgeInsets.all(5) : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isImage
            ? ImageMessageContent(message: message, isMe: false)
            : TextMessageContent(message: message, isMe: false),
      ),
    );
  }
}

class SenderBubble extends StatelessWidget {
  final Message message;
  const SenderBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isImage = message.mediaType == 'IMAGE';
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: isImage ? const EdgeInsets.all(5) : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xffE7FFDB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: isImage
            ? ImageMessageContent(message: message, isMe: true)
            : TextMessageContent(message: message, isMe: true),
      ),
    );
  }
}

class TextMessageContent extends StatelessWidget {
  final Message message;
  final bool isMe; // To know if we should show the status indicator
  const TextMessageContent({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Text(message.caption ?? '', style: const TextStyle(color: Colors.black, fontSize: 16)),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          // ✅ Conditionally show the status indicator only for sent messages
          child: isMe
              ? MessageStatusIndicator(status: message.status, timestamp: message.timestamp)
              : Text(
                  formatMessageTime(context, message.timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
        ),
      ],
    );
  }
}

class ImageMessageContent extends StatelessWidget {
  final Message message;
  final bool isMe; // To know if we should show the status indicator
  const ImageMessageContent({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: message.mediaUrl!,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
        if (message.caption != null && message.caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 8, right: 8),
            child: Text(message.caption!, style: const TextStyle(color: Colors.black)),
          ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0, right: 4),
            // ✅ Conditionally show the status indicator only for sent messages
            child: isMe
                ? MessageStatusIndicator(status: message.status, timestamp: message.timestamp)
                : Text(
                    formatMessageTime(context, message.timestamp),
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
          ),
        ),
      ],
    );
  }
}

class MessageStatusIndicator extends StatelessWidget {
  final String status;
  final DateTime timestamp;
  const MessageStatusIndicator({super.key, required this.status, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    IconData? iconData;
    Color? iconColor = Colors.grey[600];
    switch (status) {
      case 'SENT': iconData = Icons.done; break;
      case 'DELIVERED': iconData = Icons.done_all; break;
      case 'READ': iconData = Icons.done_all; iconColor = Colors.blue; break;
      case 'UNSENT': iconData = Icons.watch_later_outlined; break;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatMessageTime(context, timestamp),
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
        if (iconData != null) ...[
          const SizedBox(width: 4),
          Icon(iconData, size: 16, color: iconColor),
        ]
      ],
    );
  }
}
