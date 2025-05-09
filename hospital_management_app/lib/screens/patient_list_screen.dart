// lib/screens/patient_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/patient_models.dart'; // PatientProfile, SimpleUser 모델 정의 필요
import '../pages/patient_detail_screen.dart'; // 환자 상세 화면 임포트

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<PatientProfile> _patients = []; // PatientProfile 모델 리스트
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPatients();
  }

  Future<void> _fetchPatients() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      setState(() { _isLoading = false; _errorMessage = "환자 목록을 보려면 로그인이 필요합니다."; });
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // ApiService에 getPatientList 함수가 정의되어 있어야 함
      final response = await _apiService.getPatientList();
      if (response.statusCode == 200) {
        final responseData = response.data;
        List<dynamic> resultsList;
         if (responseData is Map && responseData.containsKey('results')) {
           resultsList = responseData['results'] as List<dynamic>;
         } else if (responseData is List) {
           resultsList = responseData;
         } else { throw Exception('API 응답 형식이 올바르지 않습니다.'); }

        setState(() {
          // PatientProfile.fromJson 구현 필요
          _patients = resultsList.map((data) => PatientProfile.fromJson(data as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      } else {
        throw DioException(requestOptions: response.requestOptions, response: response, message: 'Failed to load patients');
      }
    } catch (e) {
      print("Fetch patients error: $e");
      String detailMessage = "알 수 없는 오류";
      if (e is DioException) { /* ... 오류 메시지 처리 ... */ }
      else { detailMessage = e.toString(); }
      if(mounted) setState(() { _errorMessage = "환자 목록 로딩 실패: $detailMessage"; _isLoading = false; });
    }
  }

  // --- !!! 환자 상세 화면으로 이동하는 함수 !!! ---
  void _navigateToPatientDetail(PatientProfile patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(
          // PatientProfile 모델의 user 객체에서 id와 이름을 가져온다고 가정
          patientId: patient.user.id.toString(), // User ID 전달
          patientName: patient.user.fullName, // User 이름 전달
        ),
      ),
    );
    // 상세 화면에서 돌아왔을 때 목록 새로고침은 일단 불필요
  }
  // -----------------------------------------

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      body = Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))));
    } else if (_patients.isEmpty) {
      body = const Center(child: Text("등록된 환자가 없습니다."));
    } else {
      body = RefreshIndicator(
        onRefresh: _fetchPatients,
        child: ListView.builder(
          itemCount: _patients.length,
          itemBuilder: (context, index) {
            final patient = _patients[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                // User 모델에 fullName getter가 있다고 가정
                title: Text(patient.user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('환자 ID: ${patient.user.username} | 생년월일: ${patient.dateOfBirth ?? "N/A"}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                // --- !!! 탭하면 환자 상세 화면으로 이동 !!! ---
                onTap: () => _navigateToPatientDetail(patient),
                // ------------------------------------
              ),
            );
          },
        ),
      );
    }

    return Scaffold( // 환자 목록 화면 자체도 Scaffold 사용
       appBar: AppBar(title: const Text("환자 목록")),
       body: body,
       // 필요시 환자 추가 버튼 등 추가 가능
    );
  }
}
