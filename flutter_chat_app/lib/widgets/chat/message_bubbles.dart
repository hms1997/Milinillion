import 'package:flutter/material.dart';
import '../../models/message.dart'; // ✅ FIX: Import the Message model

// Helper function to format the timestamp for the message bubble
String formatMessageTime(BuildContext context, DateTime timestamp) {
  return TimeOfDay.fromDateTime(timestamp).format(context);
}

class ReceiverBubble extends StatelessWidget {
  final Message message;
  const ReceiverBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(message.content, style: const TextStyle(color: Colors.black, fontSize: 16)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                formatMessageTime(context, message.timestamp),
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SenderBubble extends StatelessWidget {
  final Message message;
  const SenderBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xffE7FFDB), borderRadius: BorderRadius.circular(12)),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(message.content, style: const TextStyle(color: Colors.black, fontSize: 16)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatMessageTime(context, message.timestamp),
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  MessageStatusIndicator(status: message.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageStatusIndicator extends StatelessWidget {
  final String status;
  const MessageStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    IconData? iconData;
    Color? iconColor = Colors.grey[600];
    switch (status) {
      case 'SENT':
        iconData = Icons.done;
        break;
      case 'DELIVERED':
        iconData = Icons.done_all;
        break;
      case 'READ':
        iconData = Icons.done_all;
        iconColor = Colors.blue;
        break;
      case 'UNSENT':
        iconData = Icons.watch_later_outlined;
        break;
    }
    if (iconData == null) return const SizedBox.shrink();
    return Icon(iconData, size: 16, color: iconColor);
  }
}
