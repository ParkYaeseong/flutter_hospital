   // lib/screens/dicom_viewer_webview_screen.dart
   import 'package:flutter/material.dart';
   import 'package:webview_flutter/webview_flutter.dart'; // WebView 패키지 임포트

   class DicomViewerWebViewScreen extends StatefulWidget {
     final String initialUrl; // 이전 화면에서 전달받을 OHIF 뷰어 URL

     const DicomViewerWebViewScreen({super.key, required this.initialUrl});

     @override
     State<DicomViewerWebViewScreen> createState() => _DicomViewerWebViewScreenState();
   }

   class _DicomViewerWebViewScreenState extends State<DicomViewerWebViewScreen> {
     late final WebViewController _controller; // WebView 컨트롤러
     bool _isLoadingPage = true; // 페이지 로딩 상태
     double _loadingProgress = 0; // 로딩 진행률 (0.0 ~ 1.0)

     @override
     void initState() {
       super.initState();

       // WebView 컨트롤러 초기화
       _controller = WebViewController()
         ..setJavaScriptMode(JavaScriptMode.unrestricted) // JavaScript 활성화 (OHIF 필수)
         ..setBackgroundColor(const Color(0x00000000)) // 배경 투명 (선택적)
         ..setNavigationDelegate(
           NavigationDelegate(
             onProgress: (int progress) {
               // 페이지 로딩 진행률 업데이트
               setState(() { _loadingProgress = progress / 100.0; });
               print('WebView loading progress: $progress%');
             },
             onPageStarted: (String url) {
               print('Page started loading: $url');
               setState(() { _isLoadingPage = true; _loadingProgress = 0; });
             },
             onPageFinished: (String url) {
               print('Page finished loading: $url');
               setState(() { _isLoadingPage = false; });
               // TODO: 필요시 JavaScript 채널 설정 또는 초기 스크립트 실행
             },
             onWebResourceError: (WebResourceError error) {
               // 웹 리소스 로딩 오류 처리
               print('''
   Page resource error:
     code: ${error.errorCode}
     description: ${error.description}
     errorType: ${error.errorType}
     isForMainFrame: ${error.isForMainFrame}
                 ''');
               setState(() { _isLoadingPage = false; });
               // 사용자에게 오류 메시지 표시 (예: SnackBar)
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('뷰어 로딩 중 오류 발생: ${error.description}')),
               );
             },
             onNavigationRequest: (NavigationRequest request) {
               // 특정 URL 로의 이동 제어 (필요시)
               print('allowing navigation to ${request.url}');
               return NavigationDecision.navigate; // 모든 네비게이션 허용
             },
           ),
         )
         ..loadRequest(Uri.parse(widget.initialUrl)); // 전달받은 URL 로드
     }

     @override
     Widget build(BuildContext context) {
       return Scaffold(
         appBar: AppBar(
           title: const Text('CT 뷰어'),
           // WebView 컨트롤 버튼 (선택적)
           actions: <Widget>[
             IconButton(
               icon: const Icon(Icons.arrow_back_ios),
               onPressed: () async {
                 if (await _controller.canGoBack()) {
                   await _controller.goBack();
                 } else {
                   // ignore: use_build_context_synchronously
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('더 이상 뒤로 갈 수 없습니다.')),
                   );
                 }
               },
             ),
             IconButton(
               icon: const Icon(Icons.replay),
               onPressed: () => _controller.reload(),
             ),
           ],
         ),
         // Stack을 사용하여 로딩 인디케이터를 WebView 위에 표시
         body: Stack(
           children: [
             WebViewWidget(controller: _controller),
             // 로딩 중일 때 화면 상단에 진행률 표시
             if (_isLoadingPage)
               Positioned(
                 top: 0,
                 left: 0,
                 right: 0,
                 child: LinearProgressIndicator(
                   value: _loadingProgress,
                   backgroundColor: Colors.white.withOpacity(0.5),
                   valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                 ),
               ),
           ],
         ),
       );
     }
   }
   