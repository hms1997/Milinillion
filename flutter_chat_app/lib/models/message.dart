// This file defines the data structure for a single message.
// It now supports both text and media messages.
class Message {
  String id;
  final String senderId;
  final String? caption; // Changed from 'content', now nullable
  final String? mediaUrl; // New field for image URL
  final String? mediaType; // New field: 'TEXT' or 'IMAGE'
  String status;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.senderId,
    this.caption,
    this.mediaUrl,
    required this.mediaType,
    required this.status,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['senderId'],
      caption: json['caption'],
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'],
      status: json['status'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
