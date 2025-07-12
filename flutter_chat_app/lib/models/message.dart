// This file defines the data structure for a single message.
class Message {
  String id;
  final String senderId;
  final String content;
  String status;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.status,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['senderId'],
      content: json['content'],
      status: json['status'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
