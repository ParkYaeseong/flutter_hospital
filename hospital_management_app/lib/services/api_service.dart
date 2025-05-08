// lib/services/api_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String apiBaseUrl = 'http://34.70.190.178/api/v1'; // Django API 기본 URL
  final Dio _dio;

  final _secureStorage = const FlutterSecureStorage();

  ApiService() : _dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          String? accessToken = await _secureStorage.read(key: 'accessToken');

          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
            print('Request with Token (ApiService): Bearer ${accessToken.length > 10 ? accessToken.substring(0, 10) : "short"}...');
          } else {
            print('Request without Token (ApiService): No access token for ${options.uri}');
          }

          if (options.data != null) print('Request Data: ${options.data}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('API Response: ${response.statusCode} for ${response.requestOptions.uri}');
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          print('API Error: ${e.requestOptions.uri} - ${e.response?.statusCode} ${e.message}');
          if (e.response?.statusCode == 401) {
            String? refreshToken; // TODO: 실제 리프레시 토큰 가져오는 로직
            if (refreshToken != null) {
              try {
                print('Attempting to refresh token...');
                final refreshDio = Dio(BaseOptions(baseUrl: ApiService.apiBaseUrl));
                final refreshResponse = await refreshDio.post(
                  '/auth/token/refresh/',
                  data: {'refresh': refreshToken},
                );
                if (refreshResponse.statusCode == 200) {
                  final newAccessToken = refreshResponse.data['access'];
                  // await _secureStorage.write(key: 'accessToken', value: newAccessToken);
                  // TODO: AuthProvider 등 상태 관리자에 새 토큰 업데이트
                  print('Token refreshed. Retrying original request.');
                  e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                  final retriedResponse = await _dio.fetch(e.requestOptions);
                  return handler.resolve(retriedResponse);
                }
              } catch (refreshError) {
                print('Failed to refresh token: $refreshError');
                // TODO: AuthProvider 등에서 logout 처리
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // --- 로그인 API 호출 함수 ---
  Future<Response> loginUser(String username, String password) async {
    try {
      final response = await _dio.post(
        '/auth/token/',
        data: {'username': username, 'password': password},
      );
      // 로그인 성공 시 토큰 저장 로직은 AuthProvider에서 처리하는 것이 더 일반적일 수 있음
      // 또는 여기서 바로 저장하고 AuthProvider는 상태만 업데이트
      // if (response.statusCode == 200 && response.data != null) {
      //   await _secureStorage.write(key: 'accessToken', value: response.data['access']);
      //   await _secureStorage.write(key: 'refreshToken', value: response.data['refresh']);
      // }
      return response;
    } on DioException catch (e) {
      rethrow;
    }
  }

  // --- !!! 회원가입 API 호출 함수 추가 !!! ---
  Future<Response> registerUser({
    required String username,
    required String email,
    required String password,
    required String password2,
    String? firstName,
    String? lastName,
    required String role, // 'PATIENT' 또는 'CLINICIAN'
  }) async {
    try {
      final response = await _dio.post(
        '/users/register/', // Django users 앱의 UserRegistrationView 엔드포인트
        data: {
          'username': username,
          'email': email,
          'password': password,
          'password2': password2,
          'first_name': firstName ?? '',
          'last_name': lastName ?? '',
          'role': role,
        },
      );
      return response;
    } on DioException catch (e) {
      // DioException은 response, error, type 등의 정보를 포함하여 더 자세한 오류 분석 가능
      print('Registration Error: ${e.response?.statusCode} - ${e.response?.data ?? e.message}');
      rethrow; // 호출한 곳에서 상세 오류를 처리할 수 있도록 예외를 다시 던짐
    }
  }

  // --- 현재 사용자 정보 조회 API 호출 함수 ---
  // 중복 선언되었던 함수 중 하나를 남김
  Future<Response> getCurrentUserProfile() async {
    try {
      // Django users 앱의 /users/me/ 엔드포인트 가정
      final response = await _dio.get('/users/me/');
      return response;
    } on DioException catch (e) {
      print('Get User Profile Error: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  // --- 환자 대시보드 데이터 조회 API ---
  Future<Response> getPatientDashboardData(String patientId) async {
    try {
      // Django의 apps.cdss_api (가칭) 또는 다른 앱의 엔드포인트
      final response = await _dio.get('/patients/$patientId/dashboard/');
      return response;
    } on DioException catch (e) {
      print(
        'Get Patient Dashboard Error for $patientId: ${e.response?.data ?? e.message}',
      );
      rethrow;
    }
  }

  // --- CT 진단 요청 생성 API ---
  Future<Response> createCtDiagnosisRequest(
    String patientProfileId,
    String sopInstanceUid,
  ) async {
    try {
      final response = await _dio.post(
        '/diagnosis/requests/', // Django diagnosis 앱의 ViewSet 엔드포인트
        data: {
          'patient':
              patientProfileId, // PatientProfile 모델의 PK (User ID와 다를 수 있음)
          'sop_instance_uid': sopInstanceUid,
        },
      );
      return response;
    } on DioException catch (e) {
      print(
        'Create CT Diagnosis Request Error: ${e.response?.data ?? e.message}',
      );
      rethrow;
    }
  }

  // --- (예시) 환자 목록 조회 API ---
  Future<Response> getPatientList() async {
    try {
      // Django patients 앱의 PatientProfileViewSet 엔드포인트 가정
      final response = await _dio.get('/patients/profiles/');
      return response;
    } on DioException catch (e) {
      print('Get Patient List Error: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  // --- (예시) 특정 환자의 CT 스터디 목록 조회 API (Weasis 연동용) ---
  Future<Response> getCtStudiesForPatient(String patientProfileId) async {
    try {
      // 이 API는 Django에서 Orthanc를 조회하여 StudyInstanceUID, SeriesInstanceUID 등을 반환해야 함
      final response = await _dio.get(
        '/diagnosis/requests/?patient=${patientProfileId}',
      ); // 필터링 파라미터는 Django API 설계에 따름
      return response;
    } on DioException catch (e) {
      print(
        'Get CT Studies Error for patient $patientProfileId: ${e.response?.data ?? e.message}',
      );
      rethrow;
    }
  }

 // --- !!! 병실 관리 API 함수 추가 !!! ---
  // 1. 병실 목록 조회
  Future<Response> getRoomList({Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get('/rooms/', queryParameters: queryParams); // Django rooms 앱의 RoomViewSet 엔드포인트
      return response;
    } on DioException catch (e) {
      print('Get Room List Error: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  // 2. 특정 병실 상세 정보 조회 (침상 목록 포함)
  Future<Response> getRoomDetails(String roomId) async {
    try {
      final response = await _dio.get('/rooms/rooms/$roomId/');
      return response;
    } on DioException catch (e) {
      print('Get Room Details Error for $roomId: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  // 3. 침상에 환자 배정 (BedViewSet의 update (PATCH) 사용 가정)
  Future<Response> assignPatientToBed(String bedId, String patientProfileId) async {
    try {
      final response = await _dio.patch(
        '/rooms/beds/$bedId/', // Django rooms 앱의 BedViewSet 상세 엔드포인트
        data: {'patient_id': patientProfileId}, // patient_id 필드를 통해 환자 배정
      );
      return response;
    } on DioException catch (e) {
      print('Assign Patient to Bed Error for Bed $bedId: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  // 4. 침상에서 환자 퇴실 (BedViewSet의 update (PATCH) 사용 가정 - patient_id를 null로)
  Future<Response> dischargePatientFromBed(String bedId) async {
    try {
      final response = await _dio.patch(
        '/rooms/beds/$bedId/',
        data: {'patient_id': null}, // patient_id를 null로 보내 퇴실 처리
      );
      return response;
    } on DioException catch (e) {
      print('Discharge Patient from Bed Error for Bed $bedId: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  // TODO: 새 병실/침상 생성, 정보 수정 등 필요한 API 함수 추가
  // ------------------------------------
}