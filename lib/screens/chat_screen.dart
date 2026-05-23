import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Чат с диспетчером',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          Text(
            'Здесь будет реализован Realtime чат',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}