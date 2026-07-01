import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const AiChessArenaApp());
}

class AiChessArenaApp extends StatelessWidget {
  const AiChessArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Arena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6572),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
