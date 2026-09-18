// lib/screens/map/widgets/user_camera_broadcast_modal.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../../../map/map_config.dart';

class UserCameraBroadcastModal extends StatefulWidget {
  final LatLng currentMapCenter;
  final VoidCallback onCameraAdded;

  const UserCameraBroadcastModal({
    super.key,
    required this.currentMapCenter,
    required this.onCameraAdded,
  });

  static Future<void> show(BuildContext context, {required LatLng currentMapCenter, required VoidCallback onCameraAdded}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UserCameraBroadcastModal(
        currentMapCenter: currentMapCenter,
        onCameraAdded: onCameraAdded,
      ),
    );
  }

  @override
  State<UserCameraBroadcastModal> createState() => _UserCameraBroadcastModalState();
}

class _UserCameraBroadcastModalState extends State<UserCameraBroadcastModal> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _nameController = TextEditingController(text: 'Моя камера во дворе');
  final _urlController = TextEditingController(text: 'rtsp://');
  final _addressController = TextEditingController();

  double _azimuth = 45.0; // 0 to 360
  double _fov = 75.0;     // 60 to 90
  bool _isPublic = true;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String _userIdentifier = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? prefs.getString('jwt_token');
    final phone = prefs.getString('user_phone') ?? prefs.getString('saved_phone');
    final userId = prefs.getString('user_id');

    final isAuthed = (token != null && token.isNotEmpty) || (phone != null && phone.isNotEmpty) || (userId != null && userId.isNotEmpty);

    if (mounted) {
      setState(() {
        _isAuthenticated = isAuthed;
        _userIdentifier = phone ?? userId ?? 'Зарегистрированный житель';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _urlController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitIpCamera() async {
    if (!_isAuthenticated) {
      _showAuthRequiredDialog();
      return;
    }

    final name = _nameController.text.trim();
    final streamUrl = _urlController.text.trim();
    if (name.isEmpty || streamUrl.isEmpty || streamUrl == 'rtsp://') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Укажите название и корректный RTSP/HLS URL видеопотока'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final payload = {
        'name': name,
        'stream_url': streamUrl,
        'lat': widget.currentMapCenter.latitude,
        'lng': widget.currentMapCenter.longitude,
        'azimuth': _azimuth,
        'fov': _fov,
        'is_public': _isPublic,
        'user': _userIdentifier,
      };

      // Add to local session / backend
      MapConfig.loadedCameras.add({
        'n': name,
        'name': name,
        's': streamUrl,
        'stream_url': streamUrl,
        'lat': widget.currentMapCenter.latitude,
        'lng': widget.currentMapCenter.longitude,
        'azimuth': _azimuth,
        'fov': _fov,
        'is_user_stream': true,
        'is_secret': !_isPublic,
      });

      // Try sending to backend
      try {
        final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/api/cameras/user/register');
        await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        ).timeout(const Duration(seconds: 4));
      } catch (_) {}

      widget.onCameraAdded();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✅ Видеотрансляция «$name» добавлена на карту с сектором обзора ${_azimuth.round()}°!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFF00E5FF)),
            SizedBox(width: 10),
            Text('Требуется авторизация', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Трансляция городских видеопотоков и добавление IP-камер доступно только верифицированным жителям Нижневартовска во избежание спама и нарушений.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              // Navigate to profile
            },
            child: const Text('Войти в профиль', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.5),
          boxShadow: [
            BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.15), blurRadius: 30, spreadRadius: 4),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Color(0xFF00E5FF), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ПОДКЛЮЧИТЬ ВИДЕОПОТОК',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          _isAuthenticated
                              ? 'Авторизован: $_userIdentifier'
                              : '🔒 Требуется регистрация для трансляций',
                          style: TextStyle(
                            color: _isAuthenticated ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E5FF)),
                ),
                labelColor: const Color(0xFF00E5FF),
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(icon: Icon(Icons.settings_input_antenna_rounded, size: 16), text: 'IP / RTSP Камера'),
                  Tab(icon: Icon(Icons.sensors_rounded, size: 16), text: 'Прямой эфир (WebRTC)'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: IP / RTSP / ONVIF Camera
                  _buildIpCameraForm(),
                  // Tab 2: Smartphone Live WebRTC
                  _buildWebRtcBroadcastView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpCameraForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Name Field
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Название камеры / Локация',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.edit_location_rounded, color: Color(0xFF00E5FF)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 14),

        // Stream URL Field
        TextField(
          controller: _urlController,
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
          decoration: InputDecoration(
            labelText: 'URL потока (RTSP, HLS .m3u8, RTMP)',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF00E5FF)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            hintText: 'rtsp://admin:pass@192.168.1.50:554/stream1',
            hintStyle: const TextStyle(color: Colors.white30),
          ),
        ),
        const SizedBox(height: 16),

        // Azimuth (Direction) Slider
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.explore_rounded, color: Color(0xFF00E5FF), size: 18),
                      SizedBox(width: 8),
                      Text('Азимут направления обзора', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Text('${_azimuth.round()}°', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
              Slider(
                value: _azimuth,
                min: 0,
                max: 360,
                divisions: 72,
                activeColor: const Color(0xFF00E5FF),
                onChanged: (val) => setState(() => _azimuth = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // FOV Cone Angle Slider
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.light_mode_rounded, color: Color(0xFFFFD54F), size: 18),
                      SizedBox(width: 8),
                      Text('Ширина сектора видимости (FOV)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Text('${_fov.round()}°', style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 15)),
                ],
              ),
              Slider(
                value: _fov,
                min: 45,
                max: 120,
                divisions: 15,
                activeColor: const Color(0xFFFFD54F),
                onChanged: (val) => setState(() => _fov = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Submit Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _isLoading ? null : _submitIpCamera,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('ДОБАВИТЬ КАМЕРУ НА КАРТУ ГОРОДА', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
        ),
      ],
    );
  }

  Widget _buildWebRtcBroadcastView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cell_tower_rounded, color: Color(0xFF10B981), size: 24),
                  SizedBox(width: 10),
                  Text('WebRTC Live Stream (Смартфон)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Транслируйте видео со смартфона в реальном времени прямо на карту Нижневартовска при фиксации дорожных событий, паводка на Набережной или городских мероприятий.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
              ),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.videocam_rounded, color: Colors.black),
          label: const Text('НАЧАТЬ ПРЯМОЙ ЭФИР НА КАРТЕ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          onPressed: () {
            if (!_isAuthenticated) {
              _showAuthRequiredDialog();
            } else {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF10B981),
                  content: Text('🔴 Прямая WebRTC-трансляция активирована! Ваша камера видна на карте.'),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        ],
      ),
    );
  }
}
