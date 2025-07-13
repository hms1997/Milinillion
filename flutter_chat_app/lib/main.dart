import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart'; // Import the splash screen
import 'services/websocket_service.dart';

void main() {
  runApp(
    // The Provider makes the WebSocketService available to the entire app
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
