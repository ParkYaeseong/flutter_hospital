// lib/screens/messenger_screen.dart
import 'package:flutter/material.dart';

class MessengerScreen extends StatelessWidget {
  const MessengerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '메신저 화면입니다.',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}