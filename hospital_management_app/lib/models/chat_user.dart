// lib/models/chat_user.dart

class ChatUser {
  final String id;
  final String name;
  final String role;
  final String? profileUrl;

  ChatUser({
    required this.id,
    required this.name,
    required this.role,
    this.profileUrl,
  });

  // JSON → ChatUser
  factory ChatUser.fromJson(Map<String, dynamic> json) {
    print('🧩 ChatUser JSON: $json');

    return ChatUser(
      id: json['id'].toString(), // 혹시 모르니 문자열로 변환
      name: json['username'] ?? '이름없음',
      role: json['role'], // 'PATIENT', 'CLINICIAN'
      profileUrl: json['profile_url'], // 없으면 null
    );
  }

  // ChatUser → JSON
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'role': role, 'profile_url': profileUrl};
  }
}
