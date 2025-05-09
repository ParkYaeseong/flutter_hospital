// hospital_management_app/lib/models/patient_models.dart

import 'ct_study_models.dart'; // CtStudy 모델을 가져옵니다.

class PatientProfile {
  final String id; // 서버에서 발급하는 고유 ID (예: Django DB ID)
  final String patientId; // 병원에서 사용하는 환자 ID
  final String name;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? contact;
  final String? address;
  final String? notes; // 기타 환자 관련 메모
  final List<CtStudy>? ctStudies; // 환자의 CT 스터디 목록
  final DateTime createdAt;
  final DateTime updatedAt;

  PatientProfile({
    required this.id,
    required this.patientId,
    required this.name,
    this.dateOfBirth,
    this.gender,
    this.contact,
    this.address,
    this.notes,
    this.ctStudies,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      name: json['name'] as String,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      gender: json['gender'] as String?,
      contact: json['contact'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      ctStudies: json['ct_studies'] != null
          ? (json['ct_studies'] as List<dynamic>)
              .map((studyJson) =>
                  CtStudy.fromJson(studyJson as Map<String, dynamic>))
              .toList()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'name': name,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'contact': contact,
      'address': address,
      'notes': notes,
      'ct_studies': ctStudies?.map((study) => study.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // 필요한 경우copyWith 메소드 추가
  PatientProfile copyWith({
    String? id,
    String? patientId,
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? contact,
    String? address,
    String? notes,
    List<CtStudy>? ctStudies,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PatientProfile(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      contact: contact ?? this.contact,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      ctStudies: ctStudies ?? this.ctStudies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}