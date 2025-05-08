// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart'; // 경로 확인

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final _secureStorage = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user; // 사용자 정보 (예: id, username, email, role 등)

  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialLoading = true; // 앱 시작 시 토큰 로드 중인지 여부

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialLoading => _isInitialLoading;

  // 인증 상태 확인 (accessToken 유무로 간단히 판단)
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  AuthProvider() {
    _loadUserFromStorage(); // 앱 시작 시 저장된 토큰 및 사용자 정보 로드 시도
  }

  Future<void> _loadUserFromStorage() async {
    _isInitialLoading = true;
    notifyListeners(); // 로딩 상태 UI 업데이트

    try {
      _accessToken = await _secureStorage.read(key: 'accessToken');
      _refreshToken = await _secureStorage.read(key: 'refreshToken');

      if (_accessToken != null && _accessToken!.isNotEmpty) {
        print(
          "AuthProvider: Found access token in storage. Fetching user profile...",
        );
        // 토큰이 있으면 사용자 프로필 정보 가져오기
        // 이 과정에서 토큰 유효성 검사도 간접적으로 수행됨
        await fetchUserProfile();
        if (_user == null && _accessToken != null) {
          // fetchUserProfile에서 401 등으로 토큰이 무효화되었을 수 있음
          // 만약 _user가 null인데 _accessToken이 여전히 있다면, 토큰은 유효하지만 프로필 로드 실패
          // 혹은 access token은 만료되었지만 refresh token 시도 전일 수 있음
          // 여기서는 일단 _accessToken이 있는데 _user가 없으면 토큰이 유효하지 않다고 간주하고 로그아웃
          print(
            "AuthProvider: Access token found but user profile fetch failed or token invalid. Logging out.",
          );
          await logout(); // 이 경우 자동 로그아웃
        }
      } else {
        print("AuthProvider: No access token found in storage.");
      }
    } catch (e) {
      print("AuthProvider: Error loading tokens from storage: $e");
      // 오류 발생 시 토큰 초기화
      _accessToken = null;
      _refreshToken = null;
    } finally {
      _isInitialLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.loginUser(
        username,
        password,
      ); // ApiService의 로그인 함수 호출
      if (response.statusCode == 200 && response.data != null) {
        _accessToken = response.data['access'];
        _refreshToken = response.data['refresh'];

        await _secureStorage.write(key: 'accessToken', value: _accessToken);
        await _secureStorage.write(key: 'refreshToken', value: _refreshToken);
        print("AuthProvider: Tokens saved to secure storage.");


        await fetchUserProfile(); // 로그인 성공 후 사용자 프로필 정보 가져오기
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // API 응답은 200이지만, 예상치 못한 데이터 형식일 경우
        _errorMessage = "로그인 응답이 올바르지 않습니다.";
      }
    } on DioException catch (e) {
      // Dio에서 발생한 네트워크 또는 서버 오류
      if (e.response != null &&
          e.response?.data != null &&
          e.response?.data['detail'] != null) {
        _errorMessage = e.response?.data['detail'].toString();
      } else if (e.response != null) {
        _errorMessage =
            "로그인 실패: ${e.response?.statusCode} - ${e.response?.statusMessage}";
      } else {
        _errorMessage = "로그인 중 네트워크 오류가 발생했습니다: ${e.message}";
      }
      print("AuthProvider: Login error - $_errorMessage");
    } catch (e) {
      // 기타 예외
      _errorMessage = "알 수 없는 오류가 발생했습니다: $e";
      print("AuthProvider: Unknown login error - $_errorMessage");
    }

    _isLoading = false;
    _accessToken = null; // 실패 시 토큰들 초기화
    _refreshToken = null;
    _user = null; // 사용자 정보도 초기화
    notifyListeners();
    return false;
  }

  Future<void> fetchUserProfile() async {
    // ApiService의 인터셉터에서 이미 토큰을 헤더에 추가하므로 별도 전달 X
    if (!isAuthenticated) {
      print("AuthProvider: Not authenticated, cannot fetch user profile.");
      _user = null;
      notifyListeners();
      return;
    }
    try {
      final response =
          await _apiService.getCurrentUserProfile(); // ApiService의 함수 호출
      if (response.statusCode == 200) {
        _user = response.data; // 사용자 정보(Map<String, dynamic>) 저장
        print(
          "AuthProvider: User profile fetched successfully: ${_user?['username']}",
        );
      } else {
        // 이 경우는 인터셉터에서 401 처리 후에도 발생 가능 (예: 서버 로직 오류)
        print(
          "AuthProvider: Failed to fetch user profile, status: ${response.statusCode}",
        );
        _user = null;
      }
    } on DioException catch (e) {
      print(
        "AuthProvider: Error fetching user profile (DioException): ${e.response?.data ?? e.message}",
      );
      if (e.response?.statusCode == 401) {
        // 토큰이 만료되었거나 유효하지 않은 경우
        print(
          "AuthProvider: User profile fetch returned 401. Attempting token refresh or logging out.",
        );
        // 인터셉터에서 토큰 갱신 시도가 있었을 것이므로, 여기서 또 호출하기보다는
        // 인터셉터에서 갱신 실패 시 logout을 호출하도록 하거나, 여기서 logout 처리.
        // 여기서는 logout() 을 호출하여 토큰을 정리합니다.
        await logout(); // 인증 실패 시 로그아웃
      }
      _user = null;
    } catch (e) {
      print("AuthProvider: Unknown error fetching user profile: $e");
      _user = null;
    }
    notifyListeners(); // 사용자 정보 변경 알림
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    // TODO: Django 백엔드에 토큰 블랙리스트 API 호출 (simplejwt 설정에 따름)
    // try {
    //   if (_refreshToken != null) {
    //     await _apiService.logoutUser(_refreshToken!); // ApiService에 logoutUser(refreshToken) 구현 필요
    //   }
    // } catch (e) {
    //   print("Error during server-side logout: $e");
    // }

    _accessToken = null;
    _refreshToken = null;
    _user = null;
    await _secureStorage.delete(key: 'accessToken');
    await _secureStorage.delete(key: 'refreshToken');
    print("AuthProvider: User logged out and tokens cleared.");
    _isLoading = false;
    notifyListeners();
  }

  // (선택 사항) Access Token 갱신 함수 (ApiService 인터셉터에서 주로 처리)
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) {
      print(
        "AuthProvider: No refresh token available to refresh access token.",
      );
      await logout();
      return false;
    }
    _isLoading = true;
    notifyListeners();
    _isLoading = true;
    notifyListeners();
    try {
      // --- !!! ApiService의 public static 상수 사용 !!! ---
      final refreshDio = Dio(BaseOptions(baseUrl: ApiService.apiBaseUrl));
      // ----------------------------------------------
      final response = await refreshDio.post(
        '/auth/token/refresh/',
        data: {'refresh': _refreshToken},
      );
      if (response.statusCode == 200) {
        _accessToken = response.data['access'];
        await _secureStorage.write(key: 'accessToken', value: _accessToken);
        await fetchUserProfile(); // 새 토큰으로 프로필 다시 가져오기
        _isLoading = false;
        notifyListeners();
        print("AuthProvider: Access token refreshed successfully.");
        return true;
      }
    } on DioException catch (e) {
      print("AuthProvider: Failed to refresh access token: ${e.response?.data ?? e.message}");
      await logout(); // 리프레시 실패 시 로그아웃
    } catch (e) {
      print("AuthProvider: Unknown error refreshing token: $e");
      await logout();
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  // --- !!! 회원가입 함수 추가 !!! ---
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String password2,
    String? firstName,
    String? lastName,
    required String role, // 'PATIENT' or 'CLINICIAN'
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.registerUser(
        username: username,
        email: email,
        password: password,
        password2: password2,
        firstName: firstName,
        lastName: lastName,
        role: role,
      );

      if (response.statusCode == 201) { // 회원가입 성공 (HTTP 201 Created)
        print("AuthProvider: Registration successful for ${response.data?['username']}");
        _isLoading = false;
        notifyListeners();
        // 회원가입 성공 후 바로 로그인 시도 또는 로그인 페이지로 안내
        // 여기서는 성공 메시지와 함께 사용자 데이터를 반환하여 UI에서 처리하도록 함
        return {'success': true, 'data': response.data};
      } else {
        // API는 2xx를 반환했지만 예상치 못한 경우 (거의 없음)
        _errorMessage = "회원가입 응답이 올바르지 않습니다 (Status: ${response.statusCode}).";
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        // Django DRF Validation Error 처리
        final errors = e.response?.data as Map<String, dynamic>;
        String specificError = "알 수 없는 오류가 발생했습니다.";
        if (errors.containsKey('username')) {
          specificError = '사용자 이름: ${errors['username'][0]}';
        } else if (errors.containsKey('email')) {
          specificError = '이메일: ${errors['email'][0]}';
        } else if (errors.containsKey('password')) {
          specificError = '비밀번호: ${errors['password'][0]}';
        } else if (errors.containsKey('role')) {
          specificError = '역할: ${errors['role'][0]}';
        } else if (errors.containsKey('detail')) {
            specificError = errors['detail'];
        }
        _errorMessage = "회원가입 실패: $specificError";
      } else {
        _errorMessage = "회원가입 중 네트워크 오류 또는 서버 오류가 발생했습니다.";
      }
      print("AuthProvider: Registration error - $_errorMessage");
    } catch (e) {
      _errorMessage = "알 수 없는 오류가 발생했습니다: $e";
      print("AuthProvider: Unknown registration error - $_errorMessage");
    }

    _isLoading = false;
    notifyListeners();
    return {'success': false, 'message': _errorMessage};
  }
}
