import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/chat_user.dart';
import '../models/message.dart';
import '../providers/messenger_provider.dart';
import '../providers/auth_provider.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatUser chatUser;

  const ChatRoomScreen({super.key, required this.chatUser});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  late final WebSocketChannel channel;
  String? myId;

  @override
  void initState() {
    super.initState();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    myId = authProvider.user?['id']?.toString();
    print('🪪 내 ID는: $myId');

    final roomName =
        myId!.compareTo(widget.chatUser.id.toString()) < 0
            ? '${myId}_${widget.chatUser.id}'
            : '${widget.chatUser.id}_${myId}';
    print("🧩 WebSocket 방 이름: $roomName");

    channel = WebSocketChannel.connect(
      Uri.parse('ws://34.70.190.178:8001/ws/chat/$roomName/'),
    );

    channel.stream.listen((data) {
      final decoded = json.decode(data);
      final messageText = decoded['message'];
      final senderId = decoded['sender'].toString();
      final receiverId = decoded['receiver'].toString();

      // 내 ID가 존재할 때만 처리
      if (myId != null) {
        // 대화 상대 ID 결정
        final chatPartnerId = (myId == senderId) ? receiverId : senderId;

        final message = Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: senderId,
          content: messageText,
          timestamp: DateTime.now(),
        );

        Provider.of<MessengerProvider>(
          context,
          listen: false,
        ).addMessage(myId!, chatPartnerId, message);
      }
    });

    // ✅ SharedPreferences에서 불러오기
    Provider.of<MessengerProvider>(
      context,
      listen: false,
    ).loadMessages(myId!, widget.chatUser.id).then((_) {
      // 🔥 Django API에서도 추가로 불러오기
      fetchMessagesFromServer();
    });
  }

  Future<void> fetchMessagesFromServer() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    final receiverId = widget.chatUser.id;

    try {
      final response = await http.get(
        Uri.parse(
          'http://34.70.190.178:8000/api/v1/messenger/history/${widget.chatUser.id}/',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> messagesJson = json.decode(response.body);
        final messages =
            messagesJson
                .map(
                  (msg) => Message(
                    id: msg['timestamp'],
                    senderId: msg['sender'].toString(),
                    content: msg['content'],
                    timestamp: DateTime.parse(msg['timestamp']),
                  ),
                )
                .toList();

        final messengerProvider = Provider.of<MessengerProvider>(
          context,
          listen: false,
        );
        for (final msg in messages) {
          messengerProvider.addMessage(myId!, receiverId, msg);
        }
      } else {
        print('메시지 불러오기 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('메시지 불러오기 오류: $e');
    }
  }

  @override
  void dispose() {
    channel.sink.close();
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage(BuildContext context) async {
    final text = _controller.text.trim();
    if (text.isNotEmpty && myId != null) {
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: myId!,
        content: text,
        timestamp: DateTime.now(),
      );

      // ① UI에 먼저 추가
      Provider.of<MessengerProvider>(
        context,
        listen: false,
      ).addMessage(myId!, widget.chatUser.id, message);

      // ② WebSocket으로 전송
      channel.sink.add(
        json.encode({
          'sender': myId,
          'receiver': widget.chatUser.id,
          'message': text,
        }),
      );

      // ③ Django API로 저장 요청
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      try {
        final response = await http.post(
          Uri.parse(
            'http://34.70.190.178:8000/api/v1/messenger/history/${widget.chatUser.id}/',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({'content': text}),
        );

        if (response.statusCode == 201) {
          print('✅ 메시지 저장 성공');
        } else {
          print('❌ 메시지 저장 실패: ${response.statusCode} / ${response.body}');
        }
      } catch (e) {
        print('❌ 메시지 저장 중 오류: $e');
      }

      // ✅ try-catch 밖에서 호출
      _resetInputField();
    }
  }

  // ✅ sendMessage 함수 바깥에서 따로 정의!
  void _resetInputField() {
    _controller.clear();
    FocusScope.of(context).requestFocus(FocusNode());
  }

  @override
  Widget build(BuildContext context) {
    if (myId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.chatUser.name)),
      body: Consumer<MessengerProvider>(
        builder: (context, messenger, child) {
          final messages = messenger.getMessagesFor(myId!, widget.chatUser.id);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final isMe = message.senderId == myId;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.teal[100] : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(message.content),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: '메시지를 입력하세요',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.teal),
                      onPressed: () => _sendMessage(context),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
