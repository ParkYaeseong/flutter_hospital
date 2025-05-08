// lib/screens/room_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart'; // 인증 상태 확인용
import '../services/api_service.dart';   // API 서비스 호출용
import '../models/room_models.dart';     // Room, Bed 모델 사용
// import 'room_detail_screen.dart';    // 상세 화면 (다음 단계에서 생성)

class SimplePatient {
  final String id; // PatientProfile의 user ID 또는 PatientProfile 자체의 ID (Django 모델에 따라)
  final String username; // User 모델의 username
  final String? firstName;
  final String? lastName;

  SimplePatient({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
  });

  factory SimplePatient.fromJson(Map<String, dynamic> json) {
    // Django PatientProfileSerializer에서 'user' 필드가 UserSerializer로 중첩되어 있고,
    // 그 안에 id, username, first_name, last_name이 있다고 가정합니다.
    // 또는 PatientProfileSerializer가 직접 해당 필드들을 포함할 수도 있습니다.
    // API 응답 구조에 따라 이 부분을 정확히 맞춰야 합니다.
    final userJson = json['user'] as Map<String, dynamic>?; // PatientProfile.user 접근

    return SimplePatient(
      id: userJson?['id']?.toString() ?? json['id']?.toString() ?? 'N/A_PatientID',
      username: userJson?['username'] ?? json['username'] ?? 'Unknown Patient', // username이 user 객체 안에 있을 경우
      firstName: userJson?['first_name'],
      lastName: userJson?['last_name'],
    );
  }

  // 이름을 표시하기 위한 getter
  String get fullName {
    if (firstName != null && firstName!.isNotEmpty && lastName != null && lastName!.isNotEmpty) {
      return '$lastName$firstName'; // 한국식 이름 표시
    } else if (firstName != null && firstName!.isNotEmpty) {
      return firstName!;
    } else if (lastName != null && lastName!.isNotEmpty) {
      return lastName!;
    }
    return username; // 이름 정보 없으면 username 표시
  }
}

class Bed {
  final String id; // Bed 모델의 primary key (Django에서는 보통 UUID, 문자열로 처리)
  final String bedNumber; // 침상 번호 (예: "A", "101-1")
  final SimplePatient? patient; // 배정된 환자 정보 (null 일 수 있음 - 비어있는 침상)
  final bool isOccupied; // 현재 사용 중인지 여부
  final String? notes; // 침상 관련 메모
  final String roomId; // 이 침상이 속한 Room의 ID

  Bed({
    required this.id,
    required this.bedNumber,
    this.patient,
    required this.isOccupied,
    this.notes,
    required this.roomId,
  });

  // JSON 데이터를 Bed 객체로 변환하는 팩토리 생성자
  factory Bed.fromJson(Map<String, dynamic> json) {
    return Bed(
      id: json['id']?.toString() ?? 'N/A_BedID', // Django API 응답의 Bed ID 필드명 확인
      bedNumber: json['bed_number'] ?? 'N/A',
      patient: json['patient'] != null
          ? SimplePatient.fromJson(json['patient'] as Map<String, dynamic>)
          : null,
      isOccupied: json['is_occupied'] ?? false,
      notes: json['notes'],
      roomId: json['room']?.toString() ?? 'N/A_RoomID', // Django API 응답에서 Room ID 필드명 확인
    );
  }
}

class Room {
  final String id; // Room 모델의 primary key
  final String roomNumber; // 병실 번호
  final int? floor; // 층수 (null 가능)
  final String roomType; // 병실 타입 (예: "1인실", "ICU" - Django의 get_room_type_display 값)
  final int capacity; // 총 수용 가능 침상 수
  final int currentOccupancy; // 현재 사용 중인 침상 수
  final String? description; // 병실 설명 (null 가능)
  final List<Bed> beds; // 해당 병실에 속한 침상 목록

  Room({
    required this.id,
    required this.roomNumber,
    this.floor,
    required this.roomType,
    required this.capacity,
    required this.currentOccupancy,
    this.description,
    this.beds = const [], // 기본값은 빈 리스트
  });

  // JSON 데이터를 Room 객체로 변환하는 팩토리 생성자
  factory Room.fromJson(Map<String, dynamic> json) {
    // API 응답에서 'beds' 필드가 침상 정보 리스트를 포함한다고 가정
    var bedListFromJson = json['beds'] as List<dynamic>?;
    List<Bed> parsedBedsList = bedListFromJson != null
        ? bedListFromJson.map((bedJson) => Bed.fromJson(bedJson as Map<String, dynamic>)).toList()
        : [];

    return Room(
      id: json['id']?.toString() ?? 'N/A_RoomID', // Django API 응답의 Room ID 필드명 확인
      roomNumber: json['room_number'] ?? 'N/A',
      floor: json['floor'], // int? 타입이므로 null 가능
      // Django Serializer에서 get_room_type_display 값을 room_type_display 등으로 내려주는 것이 좋음
      roomType: json['room_type_display'] ?? json['room_type'] ?? 'Unknown',
      capacity: json['capacity'] ?? 0,
      currentOccupancy: json['current_occupancy'] ?? 0,
      description: json['description'],
      beds: parsedBedsList,
    );
  }
}

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final ApiService _apiService = ApiService(); // ApiService 인스턴스 생성
  bool _isLoading = true; // 데이터 로딩 상태
  List<Room> _rooms = [];   // API로부터 받아올 병실 목록
  String? _errorMessage;    // 오류 메시지 저장

  @override
  void initState() {
    super.initState();
    _fetchRooms(); // 위젯이 처음 생성될 때 병실 목록 가져오기
  }

  // 병실 목록을 가져오는 비동기 함수
  Future<void> _fetchRooms() async {
    // AuthProvider를 통해 현재 로그인(인증) 상태 확인
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      setState(() {
        _isLoading = false;
        _errorMessage = "병실 정보를 보려면 로그인이 필요합니다.";
      });
      return;
    }

    // 데이터 로딩 시작 상태로 UI 업데이트
    setState(() {
      _isLoading = true;
      _errorMessage = null; // 이전 오류 메시지 초기화
    });

    try {
      // ApiService를 사용하여 병실 목록 API 호출
      final response = await _apiService.getRoomList(); // Django API: /api/v1/rooms/rooms/

      if (response.statusCode == 200) {
        // API 응답 성공
        final responseData = response.data;
        List<dynamic> resultsList;

        // Django REST Framework의 페이지네이션 응답 형식인지 확인
        // 페이지네이션 사용 시: {'count': ..., 'next': ..., 'previous': ..., 'results': [...]}
        // 페이지네이션 미사용 또는 직접 리스트 반환 시: [...]
        if (responseData is Map && responseData.containsKey('results')) {
          resultsList = responseData['results'] as List<dynamic>;
        } else if (responseData is List) {
          resultsList = responseData;
        } else {
          // 예상치 못한 응답 형식
          throw Exception('병실 목록 API의 응답 형식이 올바르지 않습니다.');
        }
        
        // 받아온 JSON 리스트를 Room 객체 리스트로 변환
        setState(() {
          _rooms = resultsList.map((data) => Room.fromJson(data as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      } else {
        // API 응답은 성공했으나, HTTP 상태 코드가 200이 아닌 경우 (예: 403 Forbidden 등)
        throw Exception('병실 목록을 불러오지 못했습니다 (상태 코드: ${response.statusCode})');
      }
    } catch (e) {
      // 네트워크 오류, DioException, 또는 위에서 발생시킨 Exception 등 모든 예외 처리
      print("Fetch rooms error in RoomManagementScreen: $e");
      setState(() {
        _errorMessage = "병실 목록을 불러오는 중 오류가 발생했습니다.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중일 때 표시할 UI
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 오류 발생 시 표시할 UI
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchRooms, // '다시 시도' 버튼 클릭 시 _fetchRooms 함수 호출
              child: const Text("다시 시도"),
            )
          ],
        )
      );
    }

    // 병실 데이터가 없을 때 표시할 UI
    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("등록된 병실 정보가 없습니다.", style: TextStyle(fontSize: 16)),
             const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchRooms, // '새로고침' 버튼
              child: const Text("새로고침"),
            )
          ],
        )
      );
    }

    // 병실 목록을 ListView로 표시
    return RefreshIndicator( // 화면을 아래로 당겨서 새로고침 기능
      onRefresh: _fetchRooms,
      child: ListView.builder(
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return Card( // 각 병실을 카드 형태로 표시
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            elevation: 2.0,
            child: ListTile(
              leading: CircleAvatar( // 병실 아이콘 또는 층 정보 표시
                backgroundColor: Theme.of(context).primaryColorLight,
                child: Text(room.floor?.toString() ?? '?', style: TextStyle(color: Theme.of(context).primaryColorDark)),
              ),
              title: Text('${room.roomNumber} (${room.roomType})', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('수용: ${room.currentOccupancy} / ${room.capacity}명 | 설명: ${room.description ?? "없음"}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16.0),
              onTap: () {
                // TODO: 병실 상세 화면으로 이동하는 로직 구현
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder: (context) => RoomDetailScreen(roomId: room.id),
                //   ),
                // );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${room.roomNumber} 선택됨 (상세 화면은 아직 구현되지 않았습니다)'))
                );
                print("Selected Room ID: ${room.id}, Beds: ${room.beds.length}");
                for (var bed in room.beds) {
                  print("  Bed: ${bed.bedNumber}, Occupied: ${bed.isOccupied}, Patient: ${bed.patient?.username}");
                }
              },
            ),
          );
        },
      ),
    );
  }
}