// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Provider 임포트
import 'providers/auth_provider.dart'; // AuthProvider 임포트
import 'screens/room_management_screen.dart';
import 'screens/messenger_screen.dart';
import 'screens/login_screen.dart'; // 로그인 화면 임포트 (생성 필요)

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(), // AuthProvider 제공
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '병원 관리 앱',
      theme: ThemeData(
        primarySwatch: Colors.teal, // 또는 원하는 색상
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Consumer<AuthProvider>( // AuthProvider의 상태를 구독
        builder: (context, auth, child) {
          // 앱 초기 로딩 중 (저장된 토큰 확인 등)
          if (auth.isInitialLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // 인증된 사용자라면 메인 화면으로
          if (auth.isAuthenticated) {
            return const MainScaffold();
          }
          // 인증되지 않았다면 로그인 화면으로
          return const LoginScreen(); // LoginScreen 구현 필요
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// MainScaffold 클래스는 이전 답변과 동일하게 유지
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    RoomManagementScreen(),
    MessengerScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 로그아웃 버튼 등을 위해 AuthProvider 접근 가능
    // final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? '병실 관리' : '메신저'),
        actions: [ // 로그아웃 버튼 추가 예시
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Provider를 통해 logout 함수 호출
              Provider.of<AuthProvider>(context, listen: false).logout();
              // 로그인 화면으로 자동 이동 (MyApp의 Consumer에 의해)
            },
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.king_bed_outlined),
            label: '병실 관리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            label: '메신저',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColorDark, // 테마 색상 사용
        onTap: _onItemTapped,
      ),
    );
  }
}