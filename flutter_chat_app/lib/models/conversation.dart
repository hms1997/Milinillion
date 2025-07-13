// This file defines the data structure for a single conversation.
class Conversation {
  final String contactId;
  final String displayName;
  final String? profilePictureUrl;
  String lastMessage;
  String status;
  DateTime timestamp;
  final DateTime? lastSeen;
  int unreadCount;

  Conversation({
    required this.contactId,
    required this.displayName,
    this.profilePictureUrl,
    required this.lastMessage,
    required this.status,
    required this.timestamp,
    this.lastSeen,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      contactId: json['contactId'],
      displayName: json['displayName'],
      profilePictureUrl: json['profilePictureUrl'],
      lastMessage: json['lastMessage'],
      status: json['status'],
      timestamp: DateTime.parse(json['timestamp']),
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    );
  }
}
