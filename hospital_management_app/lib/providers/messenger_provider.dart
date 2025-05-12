// lib/providers/messenger_provider.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';

class MessengerProvider with ChangeNotifier {
  final Map<String, List<Message>> _chatMap = {}; // 복합 키: myId_otherId

  // 🔑 채팅 키 생성: 항상 정렬된 조합으로
  String _chatKey(String id1, String id2) {
    final sorted = [id1, id2]..sort();
    return 'chat_${sorted[0]}_${sorted[1]}';
  }

  // ✅ 메시지 불러오기 (로컬 SharedPreferences)
  List<Message> getMessagesFor(String myId, String otherId) {
    return _chatMap[_chatKey(myId, otherId)] ?? [];
  }

  // ✅ 메시지 추가 (WebSocket or API)
  void addMessage(String myId, String otherId, Message message) {
    final key = _chatKey(myId, otherId);
    _chatMap.putIfAbsent(key, () => []);
    _chatMap[key]!.add(message);
    _saveMessages(key); // 로컬에도 저장
    notifyListeners();
  }

  // ✅ 메시지 덮어쓰기 (API에서 여러 개 불러올 때)
  void setMessages(String myId, String otherId, List<Message> messages) {
    final key = _chatKey(myId, otherId);
    _chatMap[key] = messages;
    _saveMessages(key); // 로컬 저장
    notifyListeners();
  }

  // ✅ 로컬 저장
  Future<void> _saveMessages(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final messages = _chatMap[key] ?? [];
    final jsonList = messages.map((m) => m.toJson()).toList();
    prefs.setString(key, jsonEncode(jsonList));
  }

  // ✅ 로컬 불러오기
  Future<void> loadMessages(String myId, String otherId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _chatKey(myId, otherId);
    final rawJson = prefs.getString(key);
    if (rawJson != null) {
      final decoded = jsonDecode(rawJson) as List;
      _chatMap[key] = decoded.map((e) => Message.fromJson(e)).toList();
      notifyListeners();
    }
  }

  // ✅ 삭제
  void clearMessagesFor(String myId, String otherId) async {
    final key = _chatKey(myId, otherId);
    _chatMap.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    notifyListeners();
  }
}
