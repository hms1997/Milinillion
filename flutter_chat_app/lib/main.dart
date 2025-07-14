import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart'; // Import the splash screen
import 'services/websocket_service.dart';
import 'package:firebase_core/firebase_core.dart';

// ✅ Modify the main function to be async and initialize Firebase
Future<void> main() async {
  // Ensure that Flutter's binding is initialized before calling native code
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp();
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => WebSocketService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Milinillion',
      theme: ThemeData(
        primaryColor: const Color(0xff075E54),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xff075E54),
          secondary: const Color(0xff25D366),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xff25D366),
        ),
      ),
      debugShowCheckedModeBanner: false,
      // The app always starts with the SplashScreen, which handles auth logic
      home: const SplashScreen(),
    );
  }
}
