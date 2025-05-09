    // lib/pages/patient_detail_screen.dart
    import 'package:flutter/material.dart';
    // import 'package:provider/provider.dart'; // 필요시 사용
    // import '../providers/auth_provider.dart'; // 필요시 사용
    // import '../services/api_service.dart'; // 필요시 사용
    import '../models/patient_models.dart'; // TODO: PatientProfile 모델 정의 필요
    import '../widgets/ct_study_list_widget.dart'; // CT 목록 위젯 임포트

    class PatientDetailScreen extends StatefulWidget {
      final String patientId; // 이전 화면에서 전달받을 환자 ID (User ID 또는 PatientProfile PK)
      final String? patientName; // 선택적으로 환자 이름도 전달받을 수 있음

      const PatientDetailScreen({
        super.key,
        required this.patientId,
        this.patientName,
      });

      @override
      State<PatientDetailScreen> createState() => _PatientDetailScreenState();
    }

    class _PatientDetailScreenState extends State<PatientDetailScreen> {
      // TODO: 환자 상세 정보 로딩 로직 추가 (ApiService.getPatientProfile 등)
      // PatientProfile? _patientProfile;
      // bool _isLoadingProfile = true;

      @override
      void initState() {
        super.initState();
        // _fetchPatientProfile();
      }

      // Future<void> _fetchPatientProfile() async { ... }

      @override
      Widget build(BuildContext context) {
        // 전달받은 이름 사용 또는 ID 기반 임시 이름 사용
        final String patientDisplayName = widget.patientName ?? "환자 ${widget.patientId}";

        return Scaffold(
          appBar: AppBar(title: Text('$patientDisplayName 상세 정보')),
          body: ListView( // 다양한 섹션을 보여주기 위해 ListView 사용
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- 환자 기본 정보 섹션 ---
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text("환자 기본 정보", style: Theme.of(context).textTheme.titleLarge),
                        const Divider(),
                        const SizedBox(height: 8),
                        // TODO: 실제 환자 정보 표시 (예: 이름, 생년월일 등)
                        Text("이름: $patientDisplayName"),
                        Text("ID: ${widget.patientId}"),
                        // ... (API 연동 후 추가 정보 표시) ...
                     ]
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- !!! CT 검사 목록 섹션 !!! ---
              Text('CT 검사 목록 (뷰어 열기)', style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              const SizedBox(height: 8),
              // CtStudyListWidget에 patientId 전달하여 목록 표시
              CtStudyListWidget(patientId: widget.patientId),
              // -----------------------------

              // --- 다른 정보 섹션들 (병실 정보, 진단 이력 등) ---
              // ...
            ],
          ),
        );
      }
    }
    