// lib/screens/chat_room_screen.dart
import 'package:flutter/material.dart';
import 'package:hospital_management_app/models/user_model.dart'; // Ensure this path is correct
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart'; // For IOWebSocketChannel
import 'dart:convert'; // For jsonEncode and jsonDecode

// Define a message model if you haven't already
class ChatMessage {
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });
}


class ChatRoomScreen extends StatefulWidget {
  // Changed constructor to accept currentUser and peerUser
  final User currentUser;
  final User peerUser;

  const ChatRoomScreen({
    super.key,
    required this.currentUser,
    required this.peerUser,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  late final WebSocketChannel channel;
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    // Replace with your actual WebSocket server URL
    // The URL should uniquely identify the chat room, e.g., using user IDs
    // Ensure user IDs are consistently ordered to avoid duplicate rooms (e.g., user1_user2 vs user2_user1)
    String chatRoomId;
    if (widget.currentUser.id.compareTo(widget.peerUser.id) < 0) {
      chatRoomId = '${widget.currentUser.id}_${widget.peerUser.id}';
    } else {
      chatRoomId = '${widget.peerUser.id}_${widget.currentUser.id}';
    }
    // Example WebSocket URL: ws://YOUR_DJANGO_SERVER_IP_OR_DOMAIN/ws/chat/{chat_room_id}/
    // Make sure your Django Channels routing is set up for this.
    // For local development with Android emulator: 'ws://10.0.2.2:8000/ws/chat/$chatRoomId/'
    final wsUrl = Uri.parse('ws://YOUR_DJANGO_WEBSOCKET_URL/ws/chat/$chatRoomId/?token=${widget.currentUser.id}'); // Example token, adjust as per your auth
    
    print("Connecting to WebSocket: $wsUrl");

    channel = IOWebSocketChannel.connect(wsUrl);

    channel.stream.listen(
      (message) {
        print("Received WebSocket message: $message");
        try {
          final decodedMessage = jsonDecode(message);
          // Assuming the server sends messages in a specific format
          // e.g., {"sender_id": "id1", "receiver_id": "id2", "text": "Hello"}
          // You might need to adjust this based on your backend's message structure
          if (decodedMessage is Map<String, dynamic> && decodedMessage.containsKey('text')) {
             final senderId = decodedMessage['sender_id']?.toString() ?? widget.peerUser.id.toString(); // Fallback if sender_id is missing
            setState(() {
              _messages.insert(0, ChatMessage(
                senderId: senderId,
                receiverId: widget.currentUser.id.toString(), // Assuming message is for current user
                text: decodedMessage['text'] as String,
                timestamp: DateTime.now(),
                isMe: senderId == widget.currentUser.id.toString(),
              ));
            });
          }
        } catch (e) {
          print("Error decoding WebSocket message: $e");
          // Handle non-JSON or malformed messages if necessary
           setState(() {
            _messages.insert(0, ChatMessage(
              senderId: widget.peerUser.id.toString(), // Assume it's from peer if format is unknown
              receiverId: widget.currentUser.id.toString(),
              text: message, // Show raw message
              timestamp: DateTime.now(),
              isMe: false,
            ));
          });
        }
      },
      onError: (error) {
        print("WebSocket error: $error");
        // Handle WebSocket errors (e.g., show a message to the user)
      },
      onDone: () {
        print("WebSocket connection closed");
        // Handle WebSocket connection closed (e.g., attempt to reconnect or notify user)
      },
    );
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      final messageText = _controller.text;
      // Construct the message payload as expected by your Django Channels consumer
      final messagePayload = jsonEncode({
        'text': messageText,
        'sender_id': widget.currentUser.id.toString(), // Or however your backend identifies sender
        'receiver_id': widget.peerUser.id.toString(), // Or however your backend identifies receiver
      });
      print("Sending WebSocket message: $messagePayload");
      channel.sink.add(messagePayload);
      
      // Add message to local list immediately for better UX
      // Backend should ideally echo the message back or send a confirmation
      // setState(() {
      //   _messages.insert(0, ChatMessage(
      //     senderId: widget.currentUser.id.toString(),
      //     receiverId: widget.peerUser.id.toString(),
      //     text: messageText,
      //     timestamp: DateTime.now(),
      //     isMe: true,
      //   ));
      // });
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerUser.username ?? widget.peerUser.email ?? 'Chat'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              reverse: true, // To show latest messages at the bottom
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    decoration: BoxDecoration(
                      color: message.isMe ? Theme.of(context).primaryColorLight : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(color: message.isMe ? Colors.black87 : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '메시지 입력...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
