import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MapboxThreeMapScreen extends StatefulWidget {
  const MapboxThreeMapScreen({
    super.key,
    required this.complaints,
    required this.initialCenter,
    required this.initialZoom,
  });

  final List<dynamic> complaints;
  final LatLng initialCenter;
  final double initialZoom;

  @override
  State<MapboxThreeMapScreen> createState() => _MapboxThreeMapScreenState();
}

class _MapboxThreeMapScreenState extends State<MapboxThreeMapScreen> {
  static const String _mapboxAccessToken =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '');

  late final WebViewController _controller;
  bool _isLoading = true;
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            await _sendDataToWebView();
          },
          onWebResourceError: (error) {
            debugPrint(
              'Mapbox WebView error: ${error.errorCode} ${error.description}',
            );
          },
        ),
      );
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    try {
      final html = await rootBundle.loadString('assets/mapbox_three_view.html');
      await _controller.loadHtmlString(html,
          baseUrl: 'https://appassets.androidplatform.net/');
    } catch (error) {
      debugPrint('Error loading mapbox HTML: $error');
    }
  }

  Future<void> _sendLaunchContext() async {
    final payload = {
      'lat': widget.initialCenter.latitude,
      'lng': widget.initialCenter.longitude,
      'zoom': widget.initialZoom,
    };
    final encoded = base64Encode(utf8.encode(jsonEncode(payload)));
    await _controller.runJavaScript('setLaunchContext("$encoded")');
  }

  Future<void> _sendDataToWebView() async {
    if (_mapboxAccessToken.trim().isNotEmpty) {
      final tokenPayload = jsonEncode(_mapboxAccessToken.trim());
      await _controller.runJavaScript('setMapboxToken($tokenPayload)');
    }

    await _sendLaunchContext();

    try {
      final cameraJson = await rootBundle.loadString('assets/cameras_nv.json');
      final encoded = base64Encode(utf8.encode(cameraJson));
      await _controller.runJavaScript('addCameras("$encoded")');
      final showCameras = _activeFilter == 'all' || _activeFilter == 'cameras';
      await _controller.runJavaScript('setCameraVisibility($showCameras)');
    } catch (error) {
      debugPrint('Error loading camera data: $error');
    }

    final markers = <Map<String, dynamic>>[];
    if (_activeFilter == 'all' || _activeFilter == 'complaints') {
      markers.addAll(
        widget.complaints.map(
          (complaint) => {
            'type': 'complaint',
            'lat': complaint['latitude'] ?? complaint['lat'],
            'lng': complaint['longitude'] ?? complaint['lng'],
            'title': complaint['title'] ?? 'Complaint',
            'color': _categoryToColor(complaint['category']?.toString() ?? ''),
          },
        ),
      );
    }

    final encodedMarkers = base64Encode(utf8.encode(jsonEncode(markers)));
    await _controller.runJavaScript('updateMarkers("$encodedMarkers")');
  }

  String _categoryToColor(String category) {
    switch (category) {
      case 'Дороги':
        return '#FF3D00';
      case 'ЖКХ':
        return '#00E5FF';
      case 'Безопасность':
        return '#FFC107';
      case 'Экология':
        return '#10B981';
      default:
        return '#7C3AED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '3D Mapbox + Three',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _sendDataToWebView,
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _filterChip('all', 'ALL', Icons.layers_outlined),
                  const SizedBox(width: 8),
                  _filterChip(
                    'complaints',
                    'REPORTS',
                    Icons.report_problem_outlined,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    'cameras',
                    'CAMERAS',
                    Icons.videocam_outlined,
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label, IconData icon) {
    final active = _activeFilter == id;
    return GestureDetector(
      onTap: () {
        setState(() => _activeFilter = id);
        _sendDataToWebView();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00E5FF)
              : const Color(0xFF1E1E3F).withAlpha(214),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.white : Colors.white10,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
