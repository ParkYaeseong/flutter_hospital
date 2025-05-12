// lib/screens/dicom_viewer_webview_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DicomViewerWebViewScreen extends StatefulWidget {
  // 이제 initialUrl 대신 studyInstanceUID를 받습니다.
  final String studyInstanceUID;

  const DicomViewerWebViewScreen({
    super.key,
    required this.studyInstanceUID,
  });

  @override
  State<DicomViewerWebViewScreen> createState() => _DicomViewerWebViewScreenState();
}

class _DicomViewerWebViewScreenState extends State<DicomViewerWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoadingPage = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // studyInstanceUID를 사용하여 DICOM 뷰어 URL을 구성합니다.
    // 예시: 공용 OHIF 뷰어 사용 (실제 환경에 맞게 URL 수정 필요)
    // 만약 자체 Orthanc + OHIF 서버를 사용한다면 해당 서버 주소로 변경해야 합니다.
    // 예: final String ohifViewerUrl = 'http://YOUR_OHIF_SERVER/viewer?StudyInstanceUIDs=${widget.studyInstanceUID}';
    // 예: 또는 Orthanc에 내장된 StoneViewer 사용 시
    // final String stoneViewerUrl = 'http://YOUR_ORTHANC_SERVER_IP:PORT/stone-webviewer/index.html?study=${widget.studyInstanceUID}';
    // 여기서는 일반적인 OHIF 뷰어 URL 형식을 사용합니다.
    final String initialUrl = 'https://viewer.ohif.org/viewer?StudyInstanceUIDs=${widget.studyInstanceUID}';
    // 만약 Django 서버를 통해 WADO URL 등을 프록시하고 OHIF에 전달해야 한다면,
    // 그 URL 구성 로직이 여기에 들어가야 합니다.
    // final String orthancWadoUrl = 'http://YOUR_DJANGO_SERVER/api/v1/pacs/wado?studyUID=${widget.studyInstanceUID}'; // 예시
    // final String initialUrl = 'https://viewer.ohif.org/viewer?StudyInstanceUIDs=${widget.studyInstanceUID}&wadoURL=${Uri.encodeComponent(orthancWadoUrl)}';


    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar if needed.
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoadingPage = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoadingPage = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoadingPage = false;
                _errorMessage = '''
Page resource error:
  Code: ${error.errorCode}
  Description: ${error.description}
  Error Type: ${error.errorType}
  URL: ${error.url}
                ''';
              });
            }
            print('WebResourceError: ${error.description}');
          },
          onHttpError: (HttpResponseError error) {
            if (mounted) {
              setState(() {
                _isLoadingPage = false;
                _errorMessage = 'HTTP Error: ${error.response?.statusCode}';
              });
            }
             print('HttpError: ${error.response?.statusCode}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // 특정 URL로의 이동을 제어할 수 있습니다.
            // if (request.url.startsWith('https://www.youtube.com/')) {
            //   return NavigationDecision.prevent;
            // }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = 'DICOM 뷰어';
     if (widget.studyInstanceUID.length > 10) {
      appBarTitle += ' (UID: ...${widget.studyInstanceUID.substring(widget.studyInstanceUID.length - 6)})';
    } else {
      appBarTitle += ' (UID: ${widget.studyInstanceUID})';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage == null)
            WebViewWidget(controller: _controller)
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '뷰어를 로드하는 중 오류가 발생했습니다:\n$_errorMessage',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (_isLoadingPage)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
