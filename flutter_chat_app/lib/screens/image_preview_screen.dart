import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';
import '../models/message.dart'; 

class ImagePreviewScreen extends StatefulWidget {
  final File imageFile;
  final String currentUserId;
  final String receiverId;

  const ImagePreviewScreen({
    super.key,
    required this.imageFile,
    required this.currentUserId,
    required this.receiverId,
  });

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final _captionController = TextEditingController();
  bool _isUploading = false;

  Future<void> _sendImage() async {
    setState(() {
      _isUploading = true;
    });

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('chat_images/$fileName');

      final uploadTask = storageRef.putFile(widget.imageFile);
      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final tempId = 'unsent-${DateTime.now().millisecondsSinceEpoch}';
      final caption = _captionController.text;

      final messagePayload = {
        'id': tempId,
        'senderId': widget.currentUserId,
        'receiverId': widget.receiverId,
        'mediaUrl': downloadUrl,
        'mediaType': 'IMAGE',
        'caption': caption,
        'timestamp': DateTime.now().toIso8601String(),
      };

      context.read<WebSocketService>().send('/app/chat.sendMessage', messagePayload);

      if (mounted) {
        // ✅ FIX: Create a local Message object and pass it back to the previous screen.
        final sentMessage = Message(
          id: tempId,
          senderId: widget.currentUserId,
          caption: caption,
          mediaUrl: downloadUrl, // For local display, we can use the file path
          mediaType: 'IMAGE',
          status: 'UNSENT',
          timestamp: DateTime.now(),
        );
        Navigator.of(context).pop(sentMessage); // Pass the message as a result
      }

    } catch (e) {
      print("Failed to upload image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send image. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.file(widget.imageFile),
            ),
          ),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          if (!_isUploading)
            Container(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: _captionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Add a caption...',
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _sendImage,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
