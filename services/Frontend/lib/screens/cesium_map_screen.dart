import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

class CesiumMapScreen extends StatefulWidget {
  final List<dynamic> complaints;
  const CesiumMapScreen({super.key, required this.complaints});

  @override
  State<CesiumMapScreen> createState() => _CesiumMapScreenState();
}

class _CesiumMapScreenState extends State<CesiumMapScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController();
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (String url) {
          setState(() => _isLoading = false);
          _sendDataToWebView();
        },
        onWebResourceError: (WebResourceError error) {
          debugPrint('WebView error: ${error.errorCode} ${error.description}');
        },
      ));

    // Force base URL to geoportal.n-vartovsk.ru to bypass CORS for 3D tiles
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    try {
      final htmlStr = await rootBundle.loadString('assets/cesium_view.html');
      await _controller.loadHtmlString(htmlStr, baseUrl: 'https://geoportal.n-vartovsk.ru');
    } catch (e) {
      debugPrint('Error loading cesium HTML: $e');
    }
  }

  Future<void> _sendDataToWebView() async {
    // 1. Send cameras
    try {
      final String camJsonStr = await rootBundle.loadString('assets/cameras_nv.json');
      final String base64Cam = base64Encode(utf8.encode(camJsonStr));
      _controller.runJavaScript('addCameras("$base64Cam")');
    } catch (e) {
      debugPrint('Error loading cameras for Cesium: $e');
      _controller.runJavaScript('addCameras([])');
    }

    // 2. Send markers (complaints)
    List<Map<String, dynamic>> combined = [];
    if (_activeFilter == 'all' || _activeFilter == 'complaints') {
      combined.addAll(widget.complaints.map((c) => {
        'type': 'complaint',
        'lat': c['latitude'] ?? c['lat'],
        'lng': c['longitude'] ?? c['lng'],
        'title': c['title'] ?? 'Проблема',
        'color': _getHexColor(c['category'] ?? 'Прочее'),
      }));
    }

    final String jsonStr = jsonEncode(combined);
    final String base64Data = base64Encode(utf8.encode(jsonStr));
    _controller.runJavaScript('updateMarkers("$base64Data")');
  }

  String _getHexColor(String category) {
    return switch (category) {
      'Дороги' => '#FF3D00',
      'ЖКХ' => '#00E5FF',
      'Безопасность' => '#FFC107',
      'Экология' => '#10B981',
      _ => '#00E5FF',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('3D ПУЛЬС ГОРОДА',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2),
        ),
        actions: [
          if (!_isLoading)
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _sendDataToWebView),
        ],
      ),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        // Filter chips
        Positioned(
          top: 10, left: 0, right: 0,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _filterChip('all', 'ВСЕ', Icons.layers_outlined),
              const SizedBox(width: 8),
              _filterChip('complaints', 'ЖАЛОБЫ', Icons.report_problem_outlined),
            ]),
          ),
        ),
        if (_isLoading)
          Container(
            color: const Color(0xFF020617),
            child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Color(0xFF00E5FF)),
              SizedBox(height: 24),
              Text('ЗАПУСК 3D ДВИЖКА...', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 4, fontWeight: FontWeight.bold)),
            ])),
          ),
      ]),
    );
  }

  Widget _filterChip(String id, String label, IconData icon) {
    bool active = _activeFilter == id;
    return GestureDetector(
      onTap: () { setState(() => _activeFilter = id); _sendDataToWebView(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00E5FF) : const Color(0xFF1E1E3F).withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.white : Colors.white10),
          boxShadow: active ? [const BoxShadow(color: Color(0x4400E5FF), blurRadius: 10)] : [],
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: active ? Colors.black : Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: active ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ]),
      ),
    );
  }
}
