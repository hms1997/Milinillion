import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../screens/chats_list_screen.dart'; 


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
  final String yourComputerIp = "192.168.0.112"; 

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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF232526), Color(0xFF414345)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Decorative glowing circles
          Positioned(
            top: -60,
            left: -60,
            child: _buildGlowingCircle(180, Colors.deepPurpleAccent.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: -40,
            right: -40,
            child: _buildGlowingCircle(120, Colors.blueAccent.withValues(alpha: 0.25)),
          ),
          // Glassmorphism login card
          Center(
            child: _buildLoginCard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      width: 370,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App Icon
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.deepPurpleAccent, Colors.blueAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.6),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: const Icon(
              Icons.chat_bubble_rounded,
              size: 54,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          // Title
          Text(
            'Welcome Back',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Login to continue',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          // Name Field
          _buildDarkTextField(
            controller: _nameController,
            hint: 'Display Name',
            icon: Icons.person,
          ),
          const SizedBox(height: 18),
          // Mobile Field
          _buildDarkTextField(
            controller: _mobileController,
            hint: 'Mobile Number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 28),
          // Gradient Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  color: Colors.deepPurple[700], // Solid base for contrast
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F53AC), Color(0xFF647DEE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isLoading ? null : _login,
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text(
                            'Login / Register',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),
          // Error Message
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 15),
            ),
        ],
      ),
    );
  }

  Widget _buildDarkTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white, // Make cursor visible
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.10),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      ),
    );
  }


}
