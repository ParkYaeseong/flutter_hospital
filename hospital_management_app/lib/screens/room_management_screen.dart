// lib/screens/room_management_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/room_models.dart';
import 'add_room_screen.dart';
import 'room_detail_screen.dart';
import '../pages/patient_detail_screen.dart'; // 환자 상세 화면 임포트 추가

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<Room> _rooms = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      setState(() {
        _isLoading = false;
        _errorMessage = "병실 정보를 보려면 로그인이 필요합니다.";
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getRoomList();
      if (response.statusCode == 200) {
        final responseData = response.data;
        List<dynamic> resultsList;
        if (responseData is Map && responseData.containsKey('results')) {
          resultsList = responseData['results'] as List<dynamic>;
        } else if (responseData is List) {
          resultsList = responseData;
        } else {
          throw Exception('병실 목록 API의 응답 형식이 올바르지 않습니다.');
        }

        setState(() {
          _rooms = resultsList.map((data) => Room.fromJson(data as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      } else {
        throw DioException(
            requestOptions: response.requestOptions,
            response: response,
            message: '병실 목록을 불러오지 못했습니다 (Status: ${response.statusCode})',
            type: DioExceptionType.badResponse);
      }
    } catch (e) {
      print("Fetch rooms error in RoomManagementScreen: $e");
      String detailMessage = "알 수 없는 오류";
      if (e is DioException) {
        if (e.response?.data != null) {
          if (e.response!.data is Map && e.response!.data['detail'] != null) {
            detailMessage = e.response!.data['detail'];
          } else {
            detailMessage = e.response!.data.toString();
          }
        } else {
          detailMessage = e.message ?? "Dio 오류 발생";
        }
      } else {
        detailMessage = e.toString();
      }
      if (mounted) {
        setState(() {
          _errorMessage = "병실 목록 로딩 실패: $detailMessage";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToAddRoom() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddRoomScreen()),
    );
    if (result == true && mounted) {
      _fetchRooms(); // 성공 시 목록 새로고침
    }
  }

  void _navigateToDetail(String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomDetailScreen(roomId: roomId),
      ),
    ).then((_) {
      if (mounted) {
        _fetchRooms();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('병실 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchRooms,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    FloatingActionButton.extended(
      onPressed: () {
        // 테스트용 임의 환자 상세 화면 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PatientDetailScreen(
              patientId: 'TCGA-B0-4713',
              patientName: '홍길동(테스트)',
            ),
          ),
        );
      },
      icon: const Icon(Icons.person),
      label: const Text('테스트 환자'),
      backgroundColor: Colors.deepPurpleAccent,
    ),
    const SizedBox(height: 12),
    FloatingActionButton(
      onPressed: _navigateToAddRoom,
      tooltip: '새 병실 추가',
      child: const Icon(Icons.add),
    ),
  ],
),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
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
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700], fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("다시 시도", style: TextStyle(fontSize: 16)),
                onPressed: _fetchRooms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              )
            ],
          ),
        ),
      );
    }
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
              onPressed: _fetchRooms,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            )
          ],
        ),
      );
    }
    // 병실 목록 표시
    return RefreshIndicator(
      onRefresh: _fetchRooms,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          String? targetPatientId;
          if (room.beds.isNotEmpty && room.beds.first.patient != null) {
            targetPatientId = room.beds.first.patient!.id; // 첫 침상 환자 ID 사용
          }
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            elevation: 3.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  room.floor?.toString() ?? '?',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text('${room.roomNumber} (${room.roomType})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text('수용: ${room.currentOccupancy} / ${room.capacity}명 | 설명: ${room.description ?? "없음"}'),
              onTap: () => _navigateToDetail(room.id),
              trailing: targetPatientId != null
                  ? IconButton(
                      icon: const Icon(Icons.person_outline),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientDetailScreen(
                              patientId: targetPatientId!,
                              patientName: room.beds.first.patient!.fullName, // 이름 전달
                            ),
                          ),
                        );
                      },
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
