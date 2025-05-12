// lib/models/user_model.dart 예시
class User {
  final String id;
  final String? username;
  final String? email;
  final String? role;
  final String? profileImageUrl; // 프로필 이미지 URL 필드 (선택적)

  User({
    required this.id,
    this.username,
    this.email,
    this.role,
    this.profileImageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(), // API 응답에 따라 id 필드 키 확인
      username: json['username'],
      email: json['email'],
      role: json['role'],
      profileImageUrl: json['profile_image_url'], // API 응답에 따라 키 확인
    );
  }

  // AuthProvider에서 토큰 payload로부터 사용자 정보를 만들 때 사용할 수 있는 생성자
  factory User.fromTokenPayload(Map<String, dynamic> payload) {
    return User(
      id: payload['user_id'].toString(), // 토큰 payload의 사용자 ID 키 확인
      username: payload['username'],
      // email, role 등 토큰에 포함된 다른 정보도 여기서 추출 가능
    );
  }
}