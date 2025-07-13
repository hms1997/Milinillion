import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // Import to navigate to ChatsListScreen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  String? _errorMessage;

  // ✅ Hardcoded IP for the login call
  final String yourComputerIp = "192.168.0.109"; 

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_nameController.text.isEmpty || _mobileController.text.isEmpty) {
      setState(() {
        _errorMessage = "Please enter all details.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://$yourComputerIp:8080/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mobileNumber': _mobileController.text,
          'displayName': _nameController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token'];
        final userId = data['userId'];

        // ✅ Securely save the token and user ID
        await _storage.write(key: 'jwt_token', value: token);
        await _storage.write(key: 'user_id', value: userId);

        if (mounted) {
          // Navigate to the main app screen, replacing the login screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ChatsListScreen(token: token, currentUserId: userId),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = "Login failed. Please check your details.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Could not connect to the server.";
      });
      print(e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Your Details'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _mobileController,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Login / Register',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator()),
            if (_errorMessage != null)
              Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
