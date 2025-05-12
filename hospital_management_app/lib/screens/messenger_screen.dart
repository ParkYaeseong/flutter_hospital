// lib/screens/messenger_screen.dart
import 'package:flutter/material.dart';
import 'package:hospital_management_app/models/user_model.dart'; // Ensure this path is correct
import 'package:hospital_management_app/services/api_service.dart'; // Ensure this path is correct
import 'package:hospital_management_app/screens/chat_room_screen.dart'; // Ensure this path is correct
import 'package:hospital_management_app/providers/auth_provider.dart'; // Ensure this path is correct
import 'package:provider/provider.dart';

class MessengerScreen extends StatefulWidget {
  const MessengerScreen({super.key});

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen> {
  // Initialize with a completed future of an empty list to avoid late initialization errors in FutureBuilder
  Future<List<User>> _futureUsers = Future.value([]); 
  final ApiService _apiService = ApiService();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback to ensure context is available for Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentUserAndUsers();
    });
  }

  Future<void> _loadCurrentUserAndUsers() async {
    // Ensure context is available and mounted before using Provider
    if (!mounted) return; 
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    dynamic userDataFromProvider = authProvider.user;

    if (userDataFromProvider != null) {
      if (userDataFromProvider is User) {
        _currentUser = userDataFromProvider;
      } else if (userDataFromProvider is Map<String, dynamic>) {
        try {
          _currentUser = User.fromJson(userDataFromProvider);
          // Optionally, update AuthProvider with the fully typed User object
          // if (authProvider.user is Map) authProvider.setUserObject(_currentUser);
        } catch (e) {
          print("Error converting authProvider.user map to User object: $e");
          // Fallback: try to fetch if conversion fails and user is authenticated
          if (authProvider.isAuthenticated && _currentUser == null) {
             await _fetchCurrentUserProfile();
          }
        }
      } else {
         print("AuthProvider.user is of unexpected type: ${userDataFromProvider.runtimeType}");
         if (authProvider.isAuthenticated && _currentUser == null) {
            await _fetchCurrentUserProfile();
         }
      }
    } else if (authProvider.isAuthenticated) {
      // If user data is null but authenticated, try fetching
      await _fetchCurrentUserProfile();
    }

    // Now load the user list
    // This ensures _apiService is an instance of ApiService
    if (mounted) {
      setState(() {
        _futureUsers = _apiService.getUserListIncludingMe();
      });
    }
  }

  Future<void> _fetchCurrentUserProfile() async {
    try {
      print("Fetching current user profile for messenger...");
      final profileResponse = await _apiService.getCurrentUserProfile();
      if (profileResponse.statusCode == 200 && profileResponse.data != null) {
        if (mounted) {
          setState(() {
            _currentUser = User.fromJson(profileResponse.data as Map<String, dynamic>);
          });
          // Optionally update AuthProvider
          // Provider.of<AuthProvider>(context, listen: false).setUserObject(_currentUser);
        }
      } else {
        print("Failed to fetch current user profile: ${profileResponse.statusCode}");
      }
    } catch (e) {
      print("Error fetching current user profile for messenger: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메신저'),
      ),
      body: FutureBuilder<List<User>>(
        future: _futureUsers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _currentUser == null) {
            // Show a general loading indicator if current user info is also loading
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: Text("사용자 목록 로딩 중..."));
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('사용자 목록 로드 실패: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('대화 가능한 사용자가 없습니다.'));
          }

          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userToList = users[index];

              if (_currentUser != null && userToList.id == _currentUser!.id) {
                return Container(); // Don't show current user in the list to chat with themselves
              }

              return ListTile(
                leading: CircleAvatar(
                  child: (userToList.username != null && userToList.username!.isNotEmpty)
                      ? Text(userToList.username![0].toUpperCase())
                      : const Icon(Icons.person_outline),
                ),
                title: Text(userToList.username ?? userToList.email ?? '알 수 없는 사용자'),
                subtitle: Text(userToList.role ?? '역할 정보 없음'),
                onTap: () {
                  if (_currentUser != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatRoomScreen(
                          currentUser: _currentUser!,
                          peerUser: userToList,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('현재 사용자 정보를 가져올 수 없어 채팅방을 열 수 없습니다. 먼저 로그인해주세요.')),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
