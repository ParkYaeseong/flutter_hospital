// lib/screens/ct_ai_result_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// import 'dart:io'; // Platform.isAndroid 등을 사용하려면 필요

class CtAiResultScreen extends StatefulWidget {
  final String studyInstanceUID;
  final String? overlayImageUrl;
  final String? visualization3dHtmlUrl;

  const CtAiResultScreen({
    Key? key,
    required this.studyInstanceUID,
    this.overlayImageUrl,
    this.visualization3dHtmlUrl,
  }) : super(key: key);

  @override
  State<CtAiResultScreen> createState() => _CtAiResultScreenState();
}

class _CtAiResultScreenState extends State<CtAiResultScreen> {
  // WebViewController는 _build3dVisualizationWebView 내에서 초기화됩니다.
  // 특정 컨트롤러 인스턴스를 상태로 유지할 필요는 적습니다.
  // late final WebViewController _controller; // 만약 controller를 여러 곳에서 참조해야 한다면 상태 변수로 선언

  bool _isWebViewLoading = true;
  bool _showOverlay = true; // 초기에는 오버레이 이미지를 보여줌

  @override
  void initState() {
    super.initState();

    // 최신 webview_flutter (예: 4.x 이상)에서는 아래와 같은 명시적 플랫폼 설정이
    // 필요하지 않거나, 각 플랫폼 인터페이스 패키지(webview_flutter_android, webview_flutter_wkwebview)를
    // pubspec.yaml에 추가하고 자동으로 처리되도록 하는 것이 일반적입니다.
    // 만약 아래 코드로 인해 오류가 발생한다면 주석 처리하거나 삭제하세요.
    /*
    if (Platform.isAndroid) {
      try {
        // Android 특정 설정을 위한 컨트롤러 생성 방식 (필요한 경우)
        // 예: final WebViewController controller = WebViewController.fromPlatformCreationParams(
        //   AndroidWebViewControllerCreationParams(
        //     useHybridComposition: true, // 필요에 따라 설정
        //   ),
        // );
        // _controller = controller; // 위에서 _controller를 상태변수로 선언했다면 할당
      } catch (e) {
        print("Error initializing Android WebView platform specifics: $e");
      }
    } else if (Platform.isIOS) {
      // iOS 특정 설정을 위한 컨트롤러 생성 방식 (필요한 경우)
      // 예: final WebViewController controller = WebViewController.fromPlatformCreationParams(
      //   WebKitWebViewControllerCreationParams(
      //     allowsInlineMediaPlayback: true,
      //     mediaTypesRequiringUserAction: const <PlaybackMediaType>{},
      //   ),
      // );
       // _controller = controller; // 위에서 _controller를 상태변수로 선언했다면 할당
    }
    */
     // 만약 _controller를 initState에서 초기화하고 싶다면 아래와 같이 할 수 있습니다.
     // 하지만 _build3dVisualizationWebView가 호출될 때마다 새 controller를 만들 것이므로,
     // 이 방식이 더 적절할 수 있습니다.
     /*
     if (widget.visualization3dHtmlUrl != null && !_showOverlay) {
        _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {},
            onPageStarted: (String url) {
              setState(() { _isWebViewLoading = true; });
            },
            onPageFinished: (String url) {
              setState(() { _isWebViewLoading = false; });
            },
            onWebResourceError: (WebResourceError error) {
              setState(() { _isWebViewLoading = false; });
              // ... 오류 처리 ...
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.visualization3dHtmlUrl!));
     }
     */
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = 'AI 분석 결과';
    if (widget.studyInstanceUID.length > 10) {
      appBarTitle += ' (UID: ...${widget.studyInstanceUID.substring(widget.studyInstanceUID.length - 6)})';
    } else {
      appBarTitle += ' (UID: ${widget.studyInstanceUID})';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          if (widget.overlayImageUrl != null && widget.visualization3dHtmlUrl != null)
            IconButton(
              icon: Icon(_showOverlay ? Icons.threed_rotation_outlined : Icons.image_search_outlined),
              tooltip: _showOverlay ? '3D 시각화 보기' : '오버레이 이미지 보기',
              onPressed: () {
                setState(() {
                  _showOverlay = !_showOverlay;
                  if (!_showOverlay && widget.visualization3dHtmlUrl != null) {
                    // 3D 뷰로 전환 시 로딩 상태 초기화 (WebViewWidget이 다시 빌드되면서 로드)
                    _isWebViewLoading = true;
                  }
                });
              },
            ),
        ],
      ),
      body: _buildBodyWidget(),
    );
  }

  Widget _buildBodyWidget() {
    if (widget.overlayImageUrl == null && widget.visualization3dHtmlUrl == null) {
      return const Center(child: Text('표시할 분석 결과가 없습니다.'));
    }

    if (_showOverlay) {
      return _buildOverlayImageView();
    } else {
      return _build3dVisualizationWebView();
    }
  }

  Widget _buildOverlayImageView() {
    if (widget.overlayImageUrl != null) {
      return InteractiveViewer(
        panEnabled: true,
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            widget.overlayImageUrl!,
            fit: BoxFit.contain,
            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
              print('오버레이 이미지 로드 오류: $exception');
              print('오버레이 이미지 URL: ${widget.overlayImageUrl}');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '오버레이 이미지를 불러오는 데 실패했습니다.\n네트워크 연결 및 이미지 URL을 확인해주세요.\nURL: ${widget.overlayImageUrl}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      // 이 경우는 _buildBodyWidget에서 이미 처리되었거나, _showOverlay가 true일 때만 호출되므로
      // 여기에 도달한다면 논리적 오류일 수 있습니다.
      // 다만, 방어적으로 메시지를 남깁니다.
      return const Center(child: Text('오버레이 이미지 경로가 없습니다.'));
    }
  }

  Widget _build3dVisualizationWebView() {
    if (widget.visualization3dHtmlUrl != null) {
      // WebViewController를 여기서 생성하고 WebViewWidget에 전달합니다.
      // 이렇게 하면 _showOverlay 상태가 변경되어 이 위젯이 다시 빌드될 때마다
      // 컨트롤러가 재생성되어 URL을 새로 로드합니다.
      final WebViewController controller = WebViewController();

      // 컨트롤러 설정
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000)) // 배경 투명하게 (선택 사항)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // print('WebView is loading (progress : $progress%)');
            },
            onPageStarted: (String url) {
              if (mounted) { // 위젯이 여전히 마운트된 상태인지 확인
                setState(() {
                  _isWebViewLoading = true;
                });
              }
              // print('Page started loading: $url');
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isWebViewLoading = false;
                });
              }
              // print('Page finished loading: $url');
            },
            onWebResourceError: (WebResourceError error) {
               if (mounted) {
                setState(() {
                  _isWebViewLoading = false;
                });
              }
              print('''
                Page resource error:
                code: ${error.errorCode}
                description: ${error.description}
                errorType: ${error.errorType}
                isForMainFrame: ${error.isForMainFrame}
                url: ${error.url}
              ''');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('3D 시각화 로딩 실패: ${error.description} (코드: ${error.errorCode})'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            onNavigationRequest: (NavigationRequest request) {
              // 특정 URL로의 이동을 제어할 수 있습니다. (예: 외부 링크는 브라우저로 열기)
              // if (request.url.startsWith('https://www.youtube.com/')) {
              //   return NavigationDecision.prevent;
              // }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.visualization3dHtmlUrl!)); // URL 로드

      return Stack(
        children: [
          WebViewWidget(controller: controller),
          if (_isWebViewLoading)
            const Center(child: CircularProgressIndicator())
          else
            Container(), // 로딩 완료 시 빈 컨테이너
        ],
      );
    } else {
      // 이 경우도 _buildBodyWidget에서 이미 처리되었거나, _showOverlay가 false일 때만 호출됩니다.
      return const Center(child: Text('3D 시각화 HTML 경로가 없습니다.'));
    }
  }
}