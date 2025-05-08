// lib/screens/room_detail_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/room_models.dart'; // Room, Bed 모델 임포트
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';


class RoomDetailScreen extends StatefulWidget {
  final String roomId; // 이전 화면에서 전달받을 병실 ID

  const RoomDetailScreen({super.key, required this.roomId});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final ApiService _apiService = ApiService();
  Room? _roomDetails;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRoomDetails();
  }

  Future<void> _fetchRoomDetails() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
         setState(() { _isLoading = false; _errorMessage = "로그인이 필요합니다."; });
         return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final response = await _apiService.getRoomDetails(widget.roomId);
      if (response.statusCode == 200) {
        setState(() {
          _roomDetails = Room.fromJson(response.data as Map<String, dynamic>);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load room details (Status: ${response.statusCode})');
      }
    } catch (e) {
      print("Fetch room details error: $e");
      setState(() {
        _errorMessage = "병실 상세 정보를 불러오는데 실패했습니다.";
        _isLoading = false;
      });
    }
  }

  // TODO: 환자 배정/해제 UI 및 로직 함수 추가 (ApiService 호출)
  // Future<void> _assignPatient(String bedId, String patientId) async { ... }
  // Future<void> _dischargePatient(String bedId) async { ... }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: Text('병실 상세 정보 로딩 중...')), body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Scaffold(appBar: AppBar(title: Text('오류')), body: Center(child: Text(_errorMessage!)));
    }
    if (_roomDetails == null) {
      return Scaffold(appBar: AppBar(title: Text('정보 없음')), body: Center(child: Text('병실 정보를 찾을 수 없습니다.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_roomDetails!.roomNumber} 상세 정보'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('병실 번호: ${_roomDetails!.roomNumber}', style: Theme.of(context).textTheme.headlineSmall),
            Text('층: ${_roomDetails!.floor ?? 'N/A'}층'),
            Text('병실 타입: ${_roomDetails!.roomType}'),
            Text('총 수용 인원: ${_roomDetails!.capacity}명'),
            Text('현재 인원: ${_roomDetails!.currentOccupancy}명'),
            Text('설명: ${_roomDetails!.description ?? '없음'}'),
            const SizedBox(height: 20),
            Text('침상 목록:', style: Theme.of(context).textTheme.titleLarge),
            if (_roomDetails!.beds.isEmpty)
              const Text('이 병실에는 침상이 없습니다.')
            else
              ListView.builder(
                shrinkWrap: true, // SingleChildScrollView 안에서는 필수
                physics: const NeverScrollableScrollPhysics(), // 부모 스크롤 사용
                itemCount: _roomDetails!.beds.length,
                itemBuilder: (context, index) {
                  final bed = _roomDetails!.beds[index];
                  return Card(
                    child: ListTile(
                      title: Text('침상 번호: ${bed.bedNumber}'),
                      subtitle: Text(bed.isOccupied && bed.patient != null
                          ? '사용 중: ${bed.patient!.fullName} (ID: ${bed.patient!.id})'
                          : '비어있음'),
                      trailing: bed.isOccupied
                          ? ElevatedButton(onPressed: () { /* TODO: 퇴실 처리 */ }, child: Text('퇴실'))
                          : ElevatedButton(onPressed: () { /* TODO: 환자 배정 */ }, child: Text('환자 배정')),
                    ),
                  );
                },
              ),
            // TODO: 환자 배정/해제 위한 UI 요소들 (예: 버튼, 다이얼로그) 추가
          ],
        ),
      ),
    );
  }
}