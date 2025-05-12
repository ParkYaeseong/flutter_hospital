// lib/services/api_service.dart
import 'dart:convert'; // 🔥 base64 decode용
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/chat_user.dart';

class ApiService {
  // Django API 기본 URL
  static const String apiBaseUrl =
      'http://34.70.190.178/api/v1'; // ✅ 호스팅된 서버 주소
  final Dio _dio;
  final _secureStorage = const FlutterSecureStorage();

  ApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: apiBaseUrl, // ✅ Dio 인스턴스 생성 시 baseUrl 설정
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          // validateStatus: (status) => status != null, // 이 줄은 보통 기본값(status >= 200 && status < 300)을 사용하거나, 필요시 커스텀합니다.
          // 현재 설정은 모든 상태 코드를 성공으로 간주하고 인터셉터에서 후처리하려는 의도로 보입니다.
          // 이는 일반적인 방식은 아니지만, 특정 로직이 있다면 유지할 수 있습니다.
          // 보통은 주석 처리하고 Dio의 기본 상태 코드 유효성 검사를 사용합니다.
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          String? accessToken = await _secureStorage.read(key: 'accessToken');
          if (accessToken != null && accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $accessToken';
            // 토큰이 너무 길 경우 로깅 시 일부만 표시하는 것이 좋습니다.
            // print('Request with Token: Bearer ${accessToken.length > 20 ? accessToken.substring(0, 20) : accessToken}...');
          } else {
            // print('Request without Token for ${options.uri}');
          }
          print('API Request: ${options.method} ${options.uri}'); // 요청 URI 로깅
          if (options.data != null) {
            // print('Request Data: ${options.data}'); // 요청 데이터 로깅 (민감 정보 주의)
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print(
            'API Response: ${response.statusCode} for ${response.requestOptions.uri}',
          );
          print(
            'Response Data: ${response.data}',
          ); // ✅ 이 부분의 주석을 해제하여 실제 응답 데이터 확인
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          print(
            'API Error Interceptor: URI: ${e.requestOptions.uri}, Status: ${e.response?.statusCode}, Message: ${e.message}',
          );
          if (e.response?.data != null) {
            // print('Error Data: ${e.response?.data}'); // 오류 응답 데이터 로깅
          }

          if (e.response?.statusCode == 401) {
            String? refreshToken = await _secureStorage.read(
              key: 'refreshToken',
            );
            if (refreshToken != null && refreshToken.isNotEmpty) {
              // refreshToken 유효성 추가
              try {
                print('Attempting to refresh token...');
                // 토큰 갱신을 위한 새 Dio 인스턴스 (기존 인터셉터의 무한 루프 방지)
                final refreshDio = Dio(
                  BaseOptions(baseUrl: ApiService.apiBaseUrl),
                );
                final refreshResponse = await refreshDio.post(
                  '/auth/token/refresh/', // ✅ 상대 경로 사용
                  data: {'refresh': refreshToken},
                );

                if (refreshResponse.statusCode == 200 &&
                    refreshResponse.data != null) {
                  final newAccessToken = refreshResponse.data['access'];
                  if (newAccessToken is String) {
                    // 타입 확인 추가
                    await _secureStorage.write(
                      key: 'accessToken',
                      value: newAccessToken,
                    );
                    print(
                      'Token refreshed successfully. Retrying original request.',
                    );

                    // 원래 요청 옵션에 새 토큰 설정 및 재시도
                    e.requestOptions.headers['Authorization'] =
                        'Bearer $newAccessToken';
                    final retriedResponse = await _dio.fetch(e.requestOptions);
                    return handler.resolve(retriedResponse);
                  } else {
                    print(
                      'Token refresh response did not contain a valid access token.',
                    );
                    await _logoutUser(); // 로그인 정보 삭제 및 로그아웃 처리
                  }
                } else {
                  print(
                    'Token refresh API call failed with status: ${refreshResponse.statusCode}',
                  );
                  await _logoutUser();
                }
              } catch (refreshError) {
                print('Failed to refresh token: $refreshError');
                await _logoutUser();
              }
            } else {
              print('No refresh token available. Logging out.');
              await _logoutUser();
            }
          }
          // 401 오류가 아니거나 토큰 갱신 실패 시, 원래 오류를 그대로 전달
          return handler.next(e);
        },
      ),
    );
  }

  // 로그아웃 처리 (토큰 삭제 및 필요시 Provider 상태 변경 알림)
  Future<void> _logoutUser() async {
    await _secureStorage.delete(key: 'accessToken');
    await _secureStorage.delete(key: 'refreshToken');
    // TODO: AuthProvider 등을 통해 앱 전체에 로그아웃 상태 전파
    // 예: context.read<AuthProvider>().logout(); (ApiService에서는 context 직접 사용 불가)
    // 필요하다면, 특정 예외를 발생시켜 호출부에서 로그아웃 처리하도록 유도
    print(
      "User logged out due to token refresh failure or missing refresh token.",
    );
  }

  // --- API 호출 함수들 ---

  Future<Response> loginUser(String username, String password) async {
    try {
      final response = await _dio.post(
        '/auth/token/',
        data: {'username': username, 'password': password},
      );
      return response;
    } on DioException catch (e) {
      rethrow;
    }
  }

  Future<Response> registerUser({
    required String username,
    required String email,
    required String password,
    required String password2,
    String? firstName,
    String? lastName,
    required String role,
  }) async {
    try {
      final response = await _dio.post(
        '/users/register/',
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
      print(
        'Registration Error: ${e.response?.statusCode} - ${e.response?.data ?? e.message}',
      );
      rethrow;
    }
  }

  Future<Response> getCurrentUserProfile() async {
    return await _dio.get('/users/me/'); // ✅ 상대 경로 사용
  }

  // --- 병실 관리 API 함수 ---
  Future<Response<dynamic>> getRoomList() async {
    const String endpoint =
        '/rooms/rooms'; // ✅ 올바른 상대 경로: /api/v1/rooms/ 에서 /api/v1은 baseUrl에 포함됨
    try {
      print('ApiService: Requesting room list from endpoint: $endpoint');
      // _dio.options.baseUrl에 apiBaseUrl이 설정되어 있으므로, 상대 경로만 사용
      final response = await _dio.get(endpoint);
      return response;
    } catch (e) {
      print('ApiService: Error in getRoomList for endpoint $endpoint: $e');
      rethrow;
    }
  }

  Future<Response> getPatientDashboardData(String patientId) async {
    try {
      final response = await _dio.get('/patients/$patientId/dashboard/');
      return response;
    } on DioException catch (e) {
      print(
        'Get Patient Dashboard Error for $patientId: ${e.response?.data ?? e.message}',
      );
      rethrow;
    }
  }

  Future<Response> createCtDiagnosisRequest(
    String patientProfileId,
    String sopInstanceUid,
  ) async {
    try {
      final response = await _dio.post(
        '/diagnosis/requests/',
        data: {'patient': patientProfileId, 'sop_instance_uid': sopInstanceUid},
      );
      return response;
    } on DioException catch (e) {
      print(
        'Create CT Diagnosis Request Error: ${e.response?.data ?? e.message}',
      );
      rethrow;
    }
  }

  Future<Response> getPatientList() async {
    try {
      final response = await _dio.get('/patients/profiles/');
      return response;
    } on DioException catch (e) {
      print('Get Patient List Error: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  Future<Response> getRoomDetails(String roomId) async {
    final String endpoint = '/rooms/rooms/$roomId/'; // ✅ 상대 경로 사용
    return await _dio.get(endpoint);
  }

  Future<Response> createRoom({
    required String roomNumber,
    int? floor,
    required String roomType,
    required int capacity,
    String? description,
  }) async {
    const String endpoint = '/rooms/rooms/'; // ✅ 상대 경로 사용
    return await _dio.post(
      endpoint,
      data: {
        'room_number': roomNumber,
        'floor': floor,
        'room_type': roomType, // Django RoomCreateUpdateSerializer의 필드명과 일치해야 함
        'capacity': capacity,
        'description': description ?? '',
      },
    );
  }

  Future<Response> assignPatientToBed(
    String roomId,
    String bedId,
    String patientProfileId,
  ) async {
    // ✅ 수정된 엔드포인트: Django Nested Router 설정을 정확히 반영
    final String endpoint =
        '/rooms/rooms/$roomId/beds/$bedId/'; // "rooms"가 두 번, bedId 포함

    print(
      'ApiService: Assigning patient $patientProfileId to bed $bedId in room $roomId at endpoint: $endpoint',
    );
    return await _dio.patch(
      endpoint,
      data: {
        'patient_id': patientProfileId,
      }, // BedSerializer의 patient_id (source='patient') 필드 사용
    );
  }

  Future<List<ChatUser>> getUserListIncludingMe() async {
    try {
      List<ChatUser> allUsers = [];
      String? nextUrl = '/users/';

      String? currentUserId;

      // accessToken에서 user_id 추출
      final token = await _secureStorage.read(key: 'accessToken');
      if (token != null) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = base64.normalize(parts[1]);
          final decoded = utf8.decode(base64Url.decode(payload));
          final payloadData = json.decode(decoded);
          currentUserId = payloadData['user_id'].toString();
        }
      }

      while (nextUrl != null) {
        final res = await _dio.get(nextUrl);
        final results = res.data['results'] as List;
        final users = results.map((json) => ChatUser.fromJson(json)).toList();
        allUsers.addAll(users);

        nextUrl = res.data['next']?.toString().replaceAll(
          ApiService.apiBaseUrl,
          '',
        );
      }

      return allUsers.where((user) => user.id != currentUserId).toList();
    } on DioException catch (e) {
      print('❌ 사용자 전체 목록 오류: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  Future<Response> dischargePatientFromBed(String roomId, String bedId) async {
    // ✅ 수정된 엔드포인트: Django Nested Router 설정을 정확히 반영
    final String endpoint =
        '/rooms/rooms/$roomId/beds/$bedId/'; // "rooms"가 두 번, bedId 포함
    print(
      'ApiService: Discharging patient from bed $bedId in room $roomId at endpoint: $endpoint',
    );
    return await _dio.patch(
      endpoint,
      data: {'patient_id': null}, // patient_id를 null로 보내 환자 해제
    );
  }

  Future<Response> createBedInRoom({
    required String roomId, // 이 침상이 속할 병실의 ID (예: "2")
    required String bedNumber,
    String? notes,
    String? patientId, // 새로 생성되는 침상에 바로 환자를 배정할 경우 (PatientProfile의 PK)
  }) async {
    // ✅ 수정된 엔드포인트: Django Nested Router 설정을 정확히 반영
    final String endpoint = '/rooms/rooms/$roomId/beds/'; // "rooms"가 두 번 들어갑니다.

    print(
      'ApiService: Creating bed in room $roomId at endpoint: $endpoint with patientId: $patientId',
    );
    return await _dio.post(
      endpoint,
      data: {
        'bed_number': bedNumber,
        'notes': notes ?? '',
        // patientId는 PatientProfile의 PK여야 하며, BedSerializer의 'patient_id' 필드가 이를 처리합니다.
        'patient_id': patientId,
      },
    );
  }

  Future<Response> getCtStudiesForPatient(String patientProfilePk) async {
    // Django URL이 /api/v1/patients/{patient_profile_pk}/ct-studies/ 형태일 경우 (Nested Router 사용)
    final String endpoint =
        '/patients/$patientProfilePk/ct-studies/'; // ✅ 상대 경로 사용
    // 만약 /api/v1/pacs/ct-studies/?patient_id={patient_profile_pk} 형태라면 아래처럼 수정
    // const String endpoint = '/pacs/ct-studies/';
    // return await _dio.get(endpoint, queryParameters: {'patient_id': patientProfilePk});
    print(
      'ApiService: Requesting CT studies for patient $patientProfilePk from: $endpoint',
    ); // 로그 추가
    return await _dio.get(endpoint);
  }
}
