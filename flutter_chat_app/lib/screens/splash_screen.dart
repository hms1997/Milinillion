import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart'; // Import to navigate to LoginScreen
import '../../screens/chats_list_screen.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(); // Looping for ring rotation

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    // ✅ Check authentication status after the animation
    Timer(const Duration(seconds: 3), _checkAuthStatus);
  }

  Future<void> _checkAuthStatus() async {
    // Try to read the token and user ID from secure storage
    final token = await _storage.read(key: 'jwt_token');
    final userId = await _storage.read(key: 'user_id');

    if (mounted) {
      if (token != null && userId != null) {
        // If we have a token, go directly to the chat list
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatsListScreen(token: token, currentUserId: userId),
          ),
        );
      } else {
        // If no token, go to the login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Glowing Ring Background Painter
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: GlowingRingPainter(progress: _controller.value),
                size: MediaQuery.of(context).size,
              );
            },
          ),
          // Center Text with Fade and Scale
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'Milinillion',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Helvetica', // Use SF Pro Display if imported
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class GlowingRingPainter extends CustomPainter {
  final double progress;
  GlowingRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = min(size.width, size.height) * 0.48;
    final center = Offset(size.width / 2, size.height / 2);

    // Glowing gradient effect
    final glowPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * pi,
        colors: [
          Colors.transparent,
          Colors.blueAccent.withValues(alpha: 0.8),
          Colors.blue.withValues(alpha: 0.5),
          Colors.transparent,
        ],
        stops: [0.0, 0.2, 0.5, 1.0],
        transform: GradientRotation(2 * pi * progress),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawCircle(center, radius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant GlowingRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
