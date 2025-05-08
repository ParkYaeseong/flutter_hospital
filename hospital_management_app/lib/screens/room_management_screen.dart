// lib/screens/room_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart'; // 인증 상태 확인용
import '../services/api_service.dart';   // API 서비스 호출용
import '../models/room_models.dart';     // Room, Bed 모델 사용
// import 'room_detail_screen.dart';    // 상세 화면 (다음 단계에서 생성)

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
        // API 응답은 성공했으나, HTTP 상태 코드가 200이 아닌 경우 (예: 403 Forbidden, 404 Not Found 등)
        throw Exception('병실 목록을 불러오지 못했습니다 (상태 코드: ${response.statusCode})');
      }
    } catch (e) {
      // 네트워크 오류, DioException, 또는 위에서 발생시킨 Exception 등 모든 예외 처리
      print("Fetch rooms error in RoomManagementScreen: $e");
      // DioException의 경우 e.response?.data 로 실제 서버 오류 메시지 확인 가능
      String detailMessage = "알 수 없는 오류";
      if (e is DioException && e.response?.data != null) {
        if (e.response!.data is Map && e.response!.data['detail'] != null) {
          detailMessage = e.response!.data['detail'];
        } else {
          detailMessage = e.response!.data.toString();
        }
      } else {
        detailMessage = e.toString();
      }
      setState(() {
        _errorMessage = "병실 목록 로딩 실패: $detailMessage";
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

    // 오류 발생 시 표시할 UI (스크린샷 image_f2285d.png 와 유사하게)
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 60),
              const SizedBox(height: 20),
              Text(
                _errorMessage!, // "병실 목록을 불러오는데 실패했습니다." 또는 더 상세한 메시지
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700], fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("다시 시도", style: TextStyle(fontSize: 16)),
                onPressed: _fetchRooms, // '다시 시도' 버튼 클릭 시 _fetchRooms 함수 호출
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              )
            ],
          ),
        )
      );
    }

    // 병실 데이터가 없을 때 표시할 UI
    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[600]),
            const SizedBox(height: 20),
            const Text("등록된 병실 정보가 없습니다.", style: TextStyle(fontSize: 18, color: Colors.grey)),
             const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("새로고침", style: TextStyle(fontSize: 16)),
              onPressed: _fetchRooms, // '새로고침' 버튼
               style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
            )
          ],
        )
      );
    }

    // 병실 목록을 ListView로 표시
    return RefreshIndicator( // 화면을 아래로 당겨서 새로고침 기능
      onRefresh: _fetchRooms,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return Card( // 각 병실을 카드 형태로 표시
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            elevation: 3.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(room.floor?.toString() ?? '?', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
              ),
              title: Text('${room.roomNumber} (${room.roomType})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text('수용: ${room.currentOccupancy} / ${room.capacity}명 | 설명: ${room.description ?? "없음"}'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16.0, color: Colors.grey[600]),
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
                  print("  Bed: ${bed.bedNumber}, Occupied: ${bed.isOccupied}, Patient: ${bed.patient?.fullName}");
                }
              },
            ),
          );
        },
      ),
    );
  }
}