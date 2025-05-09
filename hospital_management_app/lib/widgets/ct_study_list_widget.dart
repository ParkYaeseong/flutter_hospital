// lib/widgets/ct_study_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart'; // 외부 브라우저 실행 시 필요 (선택적)
import '../services/api_service.dart';
import '../models/ct_study_models.dart';
import '../providers/auth_provider.dart';
import '../screens/dicom_viewer_webview_screen.dart'; // WebView 화면 임포트

class CtStudyListWidget extends StatefulWidget {
  final String patientId; // 환자 ID (PatientProfile PK)

  const CtStudyListWidget({super.key, required this.patientId});

  @override
  State<CtStudyListWidget> createState() => _CtStudyListWidgetState();
}

class _CtStudyListWidgetState extends State<CtStudyListWidget> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<CtStudy> _studies = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCtStudies();
  }

  // 환자 ID가 변경될 경우 데이터 다시 로드
  @override
  void didUpdateWidget(covariant CtStudyListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.patientId != oldWidget.patientId) {
      _fetchCtStudies();
    }
  }

  Future<void> _fetchCtStudies() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      setState(() { _isLoading = false; _errorMessage = "로그인이 필요합니다."; });
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final response = await _apiService.getCtStudiesForPatient(widget.patientId);
      if (response.statusCode == 200) {
        final responseData = response.data;
        List<dynamic> resultsList;
         if (responseData is Map && responseData.containsKey('results')) {
           resultsList = responseData['results'] as List<dynamic>;
         } else if (responseData is List) {
           resultsList = responseData;
         } else { throw Exception('API 응답 형식이 올바르지 않습니다.'); }

        setState(() {
          _studies = resultsList.map((data) => CtStudy.fromJson(data as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      } else {
        throw DioException(requestOptions: response.requestOptions, response: response, message: 'Failed to load CT studies');
      }
    } catch (e) {
      print("Fetch CT studies error: $e");
      String detailMessage = "알 수 없는 오류";
      if (e is DioException) { /* ... 오류 메시지 처리 ... */ }
      else { detailMessage = e.toString(); }
      if(mounted) setState(() { _errorMessage = "CT 목록 로딩 실패: $detailMessage"; _isLoading = false; });
    }
  }

  // --- OHIF 뷰어를 WebView로 여는 함수 ---
  void _openDicomViewer(CtStudy study) {
    // Orthanc DICOMweb WADO URL (환경 변수 또는 설정 파일 사용 권장)
    const String orthancWadoUrl = 'http://34.70.190.178:8042/dicom-web'; // 실제 URL 확인!

    // 사용할 OHIF 뷰어 URL (자체 호스팅 또는 공개 데모)
    // viewer.ohif.org는 StudyInstanceUIDs 파라미터를 사용합니다.
    // 자체 호스팅 시에는 해당 뷰어의 URL 파라미터 규격 확인 필요
    final String viewerUrl = 'https://viewer.ohif.org/viewer?StudyInstanceUIDs=${study.studyInstanceUid}&wadoURL=${Uri.encodeComponent(orthancWadoUrl)}';

    print("Opening DICOM Viewer URL: $viewerUrl");

    // DicomViewerWebViewScreen으로 URL 전달하며 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DicomViewerWebViewScreen(initialUrl: viewerUrl),
      ),
    );
  }
  // ---------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null) {
      return Padding(padding: const EdgeInsets.all(16.0), child: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))));
    }
    if (_studies.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text("해당 환자의 CT 검사 기록이 없습니다.")));
    }

    // CT 스터디 목록 UI
    return ListView.builder(
      shrinkWrap: true, // 다른 스크롤 위젯 내부에 있을 경우
      physics: const NeverScrollableScrollPhysics(), // 다른 스크롤 위젯 내부에 있을 경우
      itemCount: _studies.length,
      itemBuilder: (context, index) {
        final study = _studies[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: const Icon(Icons.image_search, size: 30),
            title: Text(study.studyDescription, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('검사일: ${study.studyDate} | 환자ID: ${study.patientId}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _openDicomViewer(study), // 탭하면 뷰어 열기
          ),
        );
      },
    );
  }
}
