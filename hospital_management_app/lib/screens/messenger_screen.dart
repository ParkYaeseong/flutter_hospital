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
}import 'package:flutter/material.dart';
import '../models/chat_user.dart';
import '../services/api_service.dart';
import 'chat_room_screen.dart';

class MessengerScreen extends StatefulWidget {
  const MessengerScreen({super.key});

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen> {
  late Future<List<ChatUser>> _futureUsers;

  @override
  void initState() {
    super.initState();
    _futureUsers = ApiService().getUserListIncludingMe(); // Django API 호출
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChatUser>>(
      future: _futureUsers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          print('🔥 snapshot error: ${snapshot.error}');
          return Center(child: Text('사용자 목록을 불러오는 데 실패했어요 😢'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('표시할 사용자가 없어요.'));
        }

        final users = snapshot.data!;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            print('🔥 사용자: ${user.name}, ID: ${user.id}');
            return ListTile(
              leading: CircleAvatar(
                child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
              ),
              title: Text(user.name),
              subtitle: Text(user.role),
              trailing: const Icon(Icons.chat_bubble_outline),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatRoomScreen(chatUser: user),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
