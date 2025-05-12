// lib/models/ct_study_models.dart

class CtStudy {
  final String studyInstanceUID; // API 응답 키와 일치하도록 (대소문자 주의)
  final String? studyDescription;
  final String? studyDate;
  final int seriesCount;
  final String? orthancStudyId;
  // 기타 필요한 필드들 추가

  CtStudy({
    required this.studyInstanceUID,
    this.studyDescription,
    this.studyDate,
    required this.seriesCount,
    this.orthancStudyId,
  });

  factory CtStudy.fromJson(Map<String, dynamic> json) {
    return CtStudy(
      // API 응답의 실제 키 이름과 정확히 일치해야 합니다.
      // Django serializers.py 에서 `study_instance_uid`로 정의했다면 json['study_instance_uid'] 사용
      studyInstanceUID: json['study_instance_uid'] ?? json['StudyInstanceUID'] ?? '',
      studyDescription: json['study_description'] ?? json['StudyDescription'],
      studyDate: json['study_date'] ?? json['StudyDate'],
      seriesCount: json['series_count'] is int
          ? json['series_count']
          : (json['series_count'] is String
              ? int.tryParse(json['series_count']) ?? 0
              : 0),
      orthancStudyId: json['orthanc_study_id'] ?? json['ParentStudy'],
    );
  }

  // toJson 메서드 추가 (lib/models/patient_models.dart 에서 필요)
  Map<String, dynamic> toJson() {
    return {
      'study_instance_uid': studyInstanceUID,
      'study_description': studyDescription,
      'study_date': studyDate,
      'series_count': seriesCount,
      'orthanc_study_id': orthancStudyId,
    };
  }
}

class CtStudiesResponse {
  final List<CtStudy> studies;
  final String? errorMessage;
  // 페이지네이션 정보가 있다면 추가 (예: next, previous, count)
  final String? next;
  final String? previous;
  final int? count;


  CtStudiesResponse({
    required this.studies,
    this.errorMessage,
    this.next,
    this.previous,
    this.count,
  });

  factory CtStudiesResponse.fromJson(dynamic json) {
    if (json == null) {
      return CtStudiesResponse(studies: [], errorMessage: 'Null response data');
    }
    if (json is List) {
      // 응답이 Study 목록 List로 바로 오는 경우
      try {
        return CtStudiesResponse(
          studies: json
              .map((studyJson) =>
                  CtStudy.fromJson(studyJson as Map<String, dynamic>))
              .toList(),
        );
      } catch (e) {
        print("Error parsing list of studies: $e");
        return CtStudiesResponse(studies: [], errorMessage: 'Error parsing list of studies: $e');
      }
    } else if (json is Map<String, dynamic>) {
      // 응답이 {'studies': [...]} 또는 DRF 페이지네이션 형태인 경우
      List<dynamic>? studiesList;
      if (json.containsKey('studies') && json['studies'] is List) {
        studiesList = json['studies'] as List;
      } else if (json.containsKey('results') && json['results'] is List) { // DRF 페이지네이션 응답
        studiesList = json['results'] as List;
      } else if (json.containsKey('data') && json['data'] is List) { // 가끔 {'data': []} 형태로 올 때
         studiesList = json['data'] as List;
      }


      if (studiesList != null) {
        try {
          return CtStudiesResponse(
            studies: studiesList
                .map((studyJson) =>
                    CtStudy.fromJson(studyJson as Map<String, dynamic>))
                .toList(),
            next: json['next'] as String?,
            previous: json['previous'] as String?,
            count: json['count'] as int?,
          );
        } catch (e) {
          print("Error parsing studies from map: $e");
          return CtStudiesResponse(studies: [], errorMessage: 'Error parsing studies from map: $e');
        }
      }
    }
    // 예상치 못한 형식의 응답
    print("Unexpected CT studies response format: $json");
    return CtStudiesResponse(studies: [], errorMessage: 'Unexpected CT studies response format');
  }
}
