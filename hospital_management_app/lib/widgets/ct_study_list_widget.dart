// lib/widgets/ct_study_list_widget.dart
import 'package:flutter/material.dart';
import 'package:hospital_management_app/models/ct_study_models.dart';
import 'package:hospital_management_app/services/api_service.dart';
import 'package:hospital_management_app/screens/dicom_viewer_webview_screen.dart';
import 'package:hospital_management_app/screens/ct_ai_result_screen.dart';
// import 'package:dio/dio.dart'; // DioException을 사용하려면 필요할 수 있지만, ApiService에서 처리하므로 직접 필요 없을 수 있음

class CtStudyListWidget extends StatefulWidget {
  final String patientId; // PatientProfile의 PK (보통 UUID 문자열 또는 int)

  const CtStudyListWidget({Key? key, required this.patientId}) : super(key: key);

  @override
  _CtStudyListWidgetState createState() => _CtStudyListWidgetState();
}

class _CtStudyListWidgetState extends State<CtStudyListWidget> {
  late Future<CtStudiesResponse> _ctStudiesFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadCtStudies();
  }

  void _loadCtStudies() {
    setState(() {
      _ctStudiesFuture = _apiService.getCtStudiesForPatient(widget.patientId);
    });
  }

  // DICOM 이미지 보기 함수
  void _viewDicomImages(BuildContext context, CtStudy study) {
    if (study.orthancStudyId == null || study.orthancStudyId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orthanc 스터디 ID가 없어 DICOM 뷰어를 열 수 없습니다.')),
      );
      return;
    }

    // OHIF Viewer URL 구성 예시 (실제 Orthanc 및 WADO URL 설정에 맞게 수정 필요)
    // ApiService.mediaBaseUrl 또는 다른 방식으로 Orthanc 서버 주소를 가져와야 합니다.
    // 예시: final String orthancServerBaseUrl = 'http://YOUR_ORTHANC_IP_OR_DOMAIN:PORT';
    // final String wadoRoot = '$orthancServerBaseUrl/wado'; // 실제 WADO root 경로
    // final String dicomWebServerRoot = '$orthancServerBaseUrl/dicom-web'; // QIDO-RS, WADO-RS 등을 위함

    // OHIF Viewer는 StudyInstanceUID를 직접 사용합니다.
    // WADO URL은 Orthanc 설정에 따라 달라집니다.
    // 일반적으로 Orthanc는 /wado 라는 경로로 WADO 서비스를 제공합니다.
    // Django 서버를 통해 프록시하는 경우 해당 프록시 URL을 사용해야 합니다.

    // 여기서는 DicomViewerWebViewScreen이 study.orthancStudyId (Orthanc의 내부 ID)를
    // 사용하여 내부적으로 OHIF URL을 구성한다고 가정합니다.
    // 또는 study.studyInstanceUID를 전달하여 DicomViewerWebViewScreen에서 URL을 구성할 수도 있습니다.
    // DicomViewerWebViewScreen 구현에 따라 전달할 값을 결정해야 합니다.

    // 현재 DicomViewerWebViewScreen은 studyInstanceUID를 받도록 되어있으므로,
    // 해당 UID를 전달하고, DicomViewerWebViewScreen 내부에서 OHIF URL을 올바르게 생성해야 합니다.
    // OHIF Viewer는 StudyInstanceUID를 직접 사용합니다.
    // 예시 URL: https://viewer.ohif.org/viewer?StudyInstanceUIDs=STUDY_INSTANCE_UID
    // 만약 자체 Orthanc + OHIF를 사용한다면 해당 URL로 변경.

    // 전달하는 ID가 Orthanc의 내부 ID인지, DICOM StudyInstanceUID인지 명확히 해야 합니다.
    // Django API가 orthancStudyId를 반환한다면 이를 사용할 수 있습니다.
    // 아니면 study.studyInstanceUID를 사용합니다.
    // DicomViewerWebViewScreen에서 어떤 ID를 기대하는지 확인 필요.
    // 여기서는 study.studyInstanceUID를 사용한다고 가정합니다.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DicomViewerWebViewScreen(
          studyInstanceUID: study.studyInstanceUID, // DICOM StudyInstanceUID 전달
        ),
      ),
    );
  }

  // AI 분석 요청 함수
  void _getAiAnalysis(BuildContext context, String studyInstanceUID) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("AI 분석 중입니다..."),
            ],
          ),
        );
      },
    );

    try {
      final result = await _apiService.predictCtByStudyUid(studyInstanceUID);
      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (result.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI 분석 오류: ${result.errorMessage}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else if (result.overlayImageUrl != null || result.visualization3dHtmlUrl != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CtAiResultScreen(
              studyInstanceUID: studyInstanceUID,
              overlayImageUrl: result.overlayImageUrl,
              visualization3dHtmlUrl: result.visualization3dHtmlUrl,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 분석 결과를 받지 못했습니다 (이미지 및 3D 경로 없음).')),
        );
      }
    } catch (e) { // ApiService에서 DioException을 일반 Exception으로 rethrow 할 수 있음
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI 분석 요청 중 예외 발생: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CtStudiesResponse>(
      future: _ctStudiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          // ApiService에서 Exception으로 오류를 반환하므로, snapshot.error로 접근
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'CT 스터디 목록 로드 실패: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.studies.isEmpty) {
          // errorMessage가 있다면 그것을 먼저 표시
          if (snapshot.data?.errorMessage != null) {
             return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'CT 스터디 목록 로드 오류: ${snapshot.data!.errorMessage}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              );
          }
          return const Center(child: Text('해당 환자에 대한 CT 스터디 정보가 없습니다.'));
        }

        // 정상적으로 데이터를 받았을 때
        final ctStudiesResponse = snapshot.data!;
        final studies = ctStudiesResponse.studies;

        return ListView.builder(
          itemCount: studies.length,
          itemBuilder: (context, index) {
            final study = studies[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              elevation: 2,
              child: ListTile(
                title: Text(
                  study.studyDescription ?? '설명 없음',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('스터디 UID: ${study.studyInstanceUID}'),
                    if (study.studyDate != null && study.studyDate!.isNotEmpty)
                      Text('날짜: ${study.studyDate}'),
                    Text('시리즈 수: ${study.seriesCount}'),
                    if (study.orthancStudyId != null && study.orthancStudyId!.isNotEmpty)
                      Text('Orthanc ID: ${study.orthancStudyId}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image_search, color: Colors.blueAccent),
                      tooltip: 'DICOM 이미지 보기',
                      // _viewDicomImages에 CtStudy 객체 전체를 전달
                      onPressed: () => _viewDicomImages(context, study),
                    ),
                    IconButton(
                      icon: const Icon(Icons.insights, color: Colors.deepPurpleAccent),
                      tooltip: 'AI 분석 결과 보기',
                      // _getAiAnalysis에는 study.studyInstanceUID (String) 전달
                      onPressed: () => _getAiAnalysis(context, study.studyInstanceUID),
                    ),
                  ],
                ),
                onTap: () {
                  // 상세 정보 페이지로 이동하거나 다른 액션 수행 가능
                  print("Tapped on study: ${study.studyInstanceUID}");
                },
              ),
            );
          },
        );
      },
    );
  }
}
