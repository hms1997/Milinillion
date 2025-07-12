import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:http/http.dart' as http;

enum ConnectionStatus { connecting, connected, disconnected }

class WebSocketService with ChangeNotifier {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  StompClient? _stompClient;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;
  bool get isConnected => _status == ConnectionStatus.connected;

  final Set<String> _onlineUserIds = {};
  Set<String> get onlineUserIds => _onlineUserIds;
  final Map<String, DateTime?> _lastSeenCache = {};
  DateTime? getLastSeenForUser(String userId) => _lastSeenCache[userId];

  // Streams for broadcasting all real-time events
  final _messageStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  final _sentAckStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get sentAckStream => _sentAckStreamController.stream;
  final _statusUpdateStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusUpdateStream => _statusUpdateStreamController.stream;
  final _presenceStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get presenceStream => _presenceStreamController.stream;
  final _typingIndicatorStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get typingIndicatorStream => _typingIndicatorStreamController.stream;

  void activate(String token, String ipAddress, String userId) {
    if (isConnected || _status == ConnectionStatus.connecting) return;
    
    _status = ConnectionStatus.connecting;
    notifyListeners();

    _stompClient = StompClient(
      config: StompConfig(
        url: 'ws://$ipAddress:8080/ws',
        onConnect: (StompFrame frame) {
          _status = ConnectionStatus.connected;
          print('WebSocket Service: Connection successful.');
          
          // Subscribe to all necessary queues once connected
          _stompClient!.subscribe(
            destination: '/user/$userId/queue/messages',
            callback: (frame) {
              if (frame.body != null) {
                final messageData = json.decode(frame.body!);
                final messageId = messageData['id'];
                final senderId = messageData['senderId'];
                if (messageId != null && senderId != null) {
                  _sendBulkStatusUpdate([messageId], 'DELIVERED', senderId);
                }
                _messageStreamController.add(messageData);
              }
            },
          );
          _stompClient!.subscribe(
            destination: '/user/$userId/queue/sent-ack',
            callback: (frame) {
              if (frame.body != null) _sentAckStreamController.add(json.decode(frame.body!));
            },
          );
          _stompClient!.subscribe(
            destination: '/user/$userId/queue/status',
            callback: (frame) {
              if (frame.body != null) _statusUpdateStreamController.add(json.decode(frame.body!));
            },
          );
          _stompClient!.subscribe(
            destination: '/user/$userId/queue/typing',
            callback: (frame) {
              if (frame.body != null) _typingIndicatorStreamController.add(json.decode(frame.body!));
            }
          );
          _stompClient!.subscribe(
            destination: '/topic/presence',
            callback: (frame) {
              if (frame.body != null) {
                final presenceData = json.decode(frame.body!);
                final userId = presenceData['userId'];
                final status = presenceData['status'];
                if (status == 'ONLINE') {
                  _onlineUserIds.add(userId);
                } else {
                  _onlineUserIds.remove(userId);
                  if (presenceData['lastSeen'] != null) {
                    _lastSeenCache[userId] = DateTime.parse(presenceData['lastSeen']);
                  }
                }
                _presenceStreamController.add(presenceData); // Broadcast the full event
                notifyListeners();
              }
            }
          );

          notifyListeners();
        },
        onWebSocketError: (error) {
          _status = ConnectionStatus.disconnected;
          print('WebSocket Service Error: $error');
          notifyListeners();
        },
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );
    _stompClient!.activate();
  }

  Future<void> syncInitialPresence(String token, String ipAddress) async {
    try {
      final response = await http.get(
        Uri.parse('http://$ipAddress:8080/api/users/presence'),
        headers: { 'Authorization': 'Bearer $token' },
      );
      if (response.statusCode == 200) {
        final List<dynamic> onlineIds = json.decode(response.body);
        _onlineUserIds.clear();
        _onlineUserIds.addAll(onlineIds.cast<String>());
        print('Initial presence synced. Online users: $_onlineUserIds');
        notifyListeners();
      }
    } catch (e) {
      print('Could not sync initial presence: $e');
    }
  }

  void _sendBulkStatusUpdate(List<String> messageIds, String status, String senderId) {
    if (messageIds.isEmpty || !isConnected) return;
    final update = { 'messageIds': messageIds, 'status': status, 'senderId': senderId };
    send('/app/chat.updateStatus', update);
  }

  void send(String destination, dynamic body) {
    if (!isConnected) return;
    _stompClient!.send(destination: destination, body: json.encode(body));
  }

  void deactivate() {
    _stompClient?.deactivate();
    _stompClient = null;
    _status = ConnectionStatus.disconnected;
    _messageStreamController.close();
    _sentAckStreamController.close();
    _statusUpdateStreamController.close();
    _presenceStreamController.close();
    _typingIndicatorStreamController.close();
    print('WebSocket Service: Deactivated.');
    notifyListeners();
  }
}
