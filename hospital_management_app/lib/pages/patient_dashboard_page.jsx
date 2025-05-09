// 예시: lib/pages/patient_dashboard_page.jsx (또는 다른 페이지)
// ... (다른 import) ...
import '../widgets/ct_study_list_widget.dart'; // CT 목록 위젯 임포트

class PatientDashboardPage extends StatelessWidget {
  final String patientId; // 이 페이지로 전달된 환자 ID
  const PatientDashboardPage({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('환자 대시보드 ($patientId)')),
      body: SingleChildScrollView( // 내용이 길어질 수 있으므로 스크롤 가능하게
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (기존 환자 정보, 다른 카드 등) ...

            const SizedBox(height: 20),
            Text('CT 검사 목록', style: Theme.of(context).textTheme.headlineSmall),
            const Divider(),
            // --- CT 스터디 목록 위젯 추가 ---
            CtStudyListWidget(patientId: patientId),
            // -----------------------------

            // ... (다른 정보 섹션) ...
          ],
        ),
      ),
    );
  }
}