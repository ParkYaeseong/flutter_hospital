// lib/services/api_service.dart
import 'dart:convert'; // For jsonEncode if used, though Dio handles it.
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hospital_management_app/models/ct_study_models.dart';
import 'package:hospital_management_app/models/user_model.dart'; // Ensure this path is correct

// AI 분석 결과 모델
class CtStudyAiResult {
  final String? overlayImageUrl;
  final String? visualization3dHtmlUrl;
  final String? errorMessage;

  CtStudyAiResult({
    this.overlayImageUrl,
    this.visualization3dHtmlUrl,
    this.errorMessage,
  });

  factory CtStudyAiResult.fromJson(Map<String, dynamic> json, String baseUrlForMedia) {
    String? fullOverlayUrl;
    // baseUrlForMedia should be the pure server address (e.g., http://34.70.190.178)
    final String mediaBaseOnlyUrl = baseUrlForMedia.replaceAll('/api/v1', ''); // Ensure it's just the base

    if (json['overlay_image'] != null && json['overlay_image'].toString().isNotEmpty) {
      final imagePath = json['overlay_image'].toString();
      fullOverlayUrl = '$mediaBaseOnlyUrl/media/${imagePath.startsWith('/') ? imagePath.substring(1) : imagePath}';
    }

    String? full3dVisUrl;
    if (json['visualization_3d_html'] != null && json['visualization_3d_html'].toString().isNotEmpty) {
      final htmlPath = json['visualization_3d_html'].toString();
      full3dVisUrl = '$mediaBaseOnlyUrl/media/${htmlPath.startsWith('/') ? htmlPath.substring(1) : htmlPath}';
    }
    
    return CtStudyAiResult(
      overlayImageUrl: fullOverlayUrl,
      visualization3dHtmlUrl: full3dVisUrl,
      errorMessage: json['message'] ?? json['error'],
    );
  }
}

class ApiService {
  static const String apiBaseUrl = 'http://34.70.190.178/api/v1'; 
  static const String mediaBaseUrl = 'http://34.70.190.178'; // For constructing media URLs

  final Dio _dio;
  final _secureStorage = const FlutterSecureStorage();

  ApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: apiBaseUrl,
            connectTimeout: const Duration(seconds: 20), 
            receiveTimeout: const Duration(minutes: 2), 
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
          }
          print('API Request: ${options.method} ${options.uri}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('API Response: ${response.statusCode} for ${response.requestOptions.uri}');
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          print('API Error Interceptor: URI: ${e.requestOptions.uri}, Status: ${e.response?.statusCode}, Message: ${e.message}');
          if (e.response?.statusCode == 401) {
            String? refreshToken = await _secureStorage.read(key: 'refreshToken');
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                print('Attempting to refresh token...');
                final refreshDio = Dio(BaseOptions(baseUrl: ApiService.apiBaseUrl));
                final refreshResponse = await refreshDio.post(
                  '/auth/token/refresh/', 
                  data: {'refresh': refreshToken},
                );
                if (refreshResponse.statusCode == 200 && refreshResponse.data != null) {
                  final newAccessToken = refreshResponse.data['access'];
                  if (newAccessToken is String) {
                    await _secureStorage.write(key: 'accessToken', value: newAccessToken);
                    print('Token refreshed successfully. Retrying original request.');
                    e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                    final retriedResponse = await _dio.fetch(e.requestOptions);
                    return handler.resolve(retriedResponse);
                  } else {
                    await _logoutUser();
                  }
                } else {
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
          return handler.next(e);
        },
      ),
    );
  }

  Future<void> _logoutUser() async {
    await _secureStorage.delete(key: 'accessToken');
    await _secureStorage.delete(key: 'refreshToken');
    // Consider notifying AuthProvider or navigating to login screen
    print("User logged out due to token issue or explicit call.");
  }

  Future<Response> loginUser(String username, String password) async {
    return await _dio.post('/auth/token/', data: {'username': username, 'password': password});
  }

  Future<Response> registerUser({
    required String username, required String email, required String password,
    required String password2, String? firstName, String? lastName, required String role,
  }) async {
    return await _dio.post('/users/register/', data: {
      'username': username, 'email': email, 'password': password, 'password2': password2,
      'first_name': firstName ?? '', 'last_name': lastName ?? '', 'role': role,
    });
  }

  Future<Response> getCurrentUserProfile() async {
    return await _dio.get('/users/me/');
  }

  Future<Response<dynamic>> getRoomList() async {
    return await _dio.get('/rooms/rooms/');
  }

  Future<Response> getRoomDetails(String roomId) async {
    return await _dio.get('/rooms/rooms/$roomId/');
  }

  Future<Response> createRoom({
    required String roomNumber, int? floor, required String roomType,
    required int capacity, String? description,
  }) async {
    return await _dio.post('/rooms/rooms/', data: {
      'room_number': roomNumber, 'floor': floor, 'room_type': roomType,
      'capacity': capacity, 'description': description ?? '',
    });
  }

  Future<Response> assignPatientToBed(String roomId, String bedId, String patientProfileId) async {
    return await _dio.patch('/rooms/rooms/$roomId/beds/$bedId/', data: {'patient_id': patientProfileId});
  }

  Future<Response> dischargePatientFromBed(String roomId, String bedId) async {
    return await _dio.patch('/rooms/rooms/$roomId/beds/$bedId/', data: {'patient_id': null});
  }

  Future<Response> createBedInRoom({
    required String roomId, required String bedNumber, String? notes, String? patientId,
  }) async {
    return await _dio.post('/rooms/rooms/$roomId/beds/', data: {
      'bed_number': bedNumber, 'notes': notes ?? '', 'patient_id': patientId,
    });
  }

  Future<CtStudiesResponse> getCtStudiesForPatient(String patientProfilePk) async {
    final String endpoint = '/patients/$patientProfilePk/ct-studies/';
    try {
      final response = await _dio.get(endpoint);
      if (response.statusCode == 200 && response.data != null) {
        return CtStudiesResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to load CT studies. Status code: ${response.statusCode}, Data: ${response.data}');
      }
    } on DioException catch (e) {
      String errorMessage = 'Failed to load CT studies';
      if (e.response?.data != null && e.response!.data is Map) {
        errorMessage = e.response!.data['detail'] ?? e.response!.data['message'] ?? errorMessage;
      } else if (e.message != null){
        errorMessage = e.message!;
      }
      print('Error loading CT studies: $errorMessage, DioException: $e');
      throw Exception(errorMessage);
    } catch (e) {
      print('Unexpected error loading CT studies: $e');
      throw Exception('Unexpected error loading CT studies.');
    }
  }

  Future<CtStudyAiResult> predictCtByStudyUid(String studyUid) async {
    const String endpoint = '/diagnosis/ct-by-study/';
    try {
      final response = await _dio.post(endpoint, data: {'study_uid': studyUid});
      if (response.statusCode == 200 && response.data != null) {
        if (response.data['status'] == 'success') {
          return CtStudyAiResult.fromJson(response.data, mediaBaseUrl); // Pass mediaBaseUrl
        } else {
          return CtStudyAiResult(errorMessage: response.data['message'] ?? 'AI 분석 실패 (서버 응답 오류)');
        }
      } else {
        return CtStudyAiResult(errorMessage: 'AI 분석 요청 실패 (Status: ${response.statusCode}, Data: ${response.data})');
      }
    } on DioException catch (e) {
      String errorMessage = 'AI 분석 중 서버 오류 발생';
       if (e.response?.data != null && e.response!.data is Map) {
        errorMessage = e.response!.data['message'] ?? e.response!.data['error'] ?? errorMessage;
      } else if (e.message != null){
        errorMessage = e.message!;
      }
      print('DioException during AI prediction: $errorMessage, DioException: $e');
      return CtStudyAiResult(errorMessage: errorMessage);
    } catch (e) {
      print('Unexpected error during AI prediction: $e');
      return CtStudyAiResult(errorMessage: 'AI 분석 중 예상치 못한 오류 발생: ${e.toString()}');
    }
  }

  // 사용자 목록 가져오기 (메신저용)
  Future<List<User>> getUserListIncludingMe() async {
    const String endpoint = '/users/'; // Ensure this is your Django user list endpoint
    try {
      final response = await _dio.get(endpoint);
      if (response.statusCode == 200 && response.data != null) {
        if (response.data is List) {
          return (response.data as List)
              .map((userJson) => User.fromJson(userJson as Map<String, dynamic>))
              .toList();
        } else if (response.data is Map<String, dynamic> && response.data['results'] is List) {
           return (response.data['results'] as List)
              .map((userJson) => User.fromJson(userJson as Map<String, dynamic>))
              .toList();
        }
        print("Unexpected user list format from API: ${response.data}");
        throw Exception('Invalid user list format from API');
      } else {
        throw Exception('Failed to load users. Status code: ${response.statusCode}, Data: ${response.data}');
      }
    } on DioException catch (e) {
      String errorMessage = 'Failed to load users';
      if (e.response?.data != null && e.response!.data is Map) {
        errorMessage = e.response!.data['detail'] ?? e.response!.data['message'] ?? errorMessage;
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      print('Error loading users: $errorMessage, DioException: $e');
      throw Exception(errorMessage);
    } catch (e) {
      print('Unexpected error loading users: $e');
      throw Exception('Unexpected error loading users.');
    }
  }
}
