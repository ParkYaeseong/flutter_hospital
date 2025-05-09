// hospital_management_app/lib/models/ct_study_models.dart

class CtStudy {
  final String studyInstanceUid;
  final String studyDate; // API 응답이 문자열 형태의 날짜일 경우
  // final DateTime? studyDate; // 만약 studyDate가 ISO8601 형식이라면 DateTime으로 파싱하는 것이 좋습니다.
  final String studyDescription;
  final String patientId; // 이 study가 속한 환자의 ID

  CtStudy({
    required this.studyInstanceUid,
    required this.studyDate,
    // this.studyDate, // DateTime? 타입일 경우
    required this.studyDescription,
    required this.patientId,
  });

  factory CtStudy.fromJson(Map<String, dynamic> json) {
    return CtStudy(
      studyInstanceUid: json['study_instance_uid'] as String? ?? 'Unknown UID',
      studyDate: json['study_date'] as String? ?? 'Unknown Date',
      // studyDate: json['study_date'] != null
      //     ? DateTime.parse(json['study_date'] as String)
      //     : null, // DateTime 타입으로 파싱할 경우
      studyDescription: json['study_description'] as String? ?? 'No Description',
      patientId: json['patient_id'] as String? ?? 'Unknown Patient ID', // patient_id는 필수일 가능성이 높습니다. null 처리 확인 필요
    );
  }

  /// 객체를 JSON 맵으로 변환합니다.
  /// Django Serializer 필드 이름과 일치하도록 키를 설정합니다.
  Map<String, dynamic> toJson() {
    return {
      'study_instance_uid': studyInstanceUid,
      'study_date': studyDate, // 현재 String 타입이므로 그대로 전달
      // 'study_date': studyDate?.toIso8601String(), // DateTime 타입일 경우
      'study_description': studyDescription,
      'patient_id': patientId,
    };
  }

  // (선택 사항) 객체 복사를 위한 copyWith 메소드
  CtStudy copyWith({
    String? studyInstanceUid,
    String? studyDate,
    // DateTime? studyDate, // DateTime? 타입일 경우
    String? studyDescription,
    String? patientId,
  }) {
    return CtStudy(
      studyInstanceUid: studyInstanceUid ?? this.studyInstanceUid,
      studyDate: studyDate ?? this.studyDate,
      studyDescription: studyDescription ?? this.studyDescription,
      patientId: patientId ?? this.patientId,
    );
  }
}