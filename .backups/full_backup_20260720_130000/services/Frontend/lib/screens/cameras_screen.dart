// services/Frontend/lib/screens/cameras_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_router.dart';
import '../map/map_config.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';
import 'map/widgets/video_dialog.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({super.key});

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  List<Map<String, dynamic>> _cameras = [];
  bool _isLoading = true;
  String? _error;
  bool _isVip = false;
  int _today3dCount = 0;

  @override
  void initState() {
    super.initState();
    _loadVipAnd3dCount();
    _fetchCameras();
  }

  Future<void> _loadVipAnd3dCount() async {
    final prefs = await SharedPreferences.getInstance();
    final isVip = prefs.getBool('is_premium_vip') ?? prefs.getBool('is_vip') ?? false;
    final todayKey = '3d_gen_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}';
    final count = prefs.getInt(todayKey) ?? 0;
    setState(() {
      _isVip = isVip;
      _today3dCount = count;
    });
  }

  Future<void> _increment3dCount() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = '3d_gen_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}';
    final count = prefs.getInt(todayKey) ?? 0;
    await prefs.setInt(todayKey, count + 1);
    setState(() {
      _today3dCount = count + 1;
    });
  }

  Future<void> _fetchCameras() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${MapConfig.backendApiBaseUrl}/cameras?city=nizhnevartovsk'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> cameraList = data['cameras'] ?? [];
        
        setState(() {
          _cameras = cameraList.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить камеры: $e';
        _isLoading = false;
      });
    }
  }

  void _openCameraLive(Map<String, dynamic> camera) {
    HapticFeedback.mediumImpact();
    
    final streamUrl = camera['stream_url']?.toString() ?? camera['s']?.toString() ?? '';
    final name = camera['name']?.toString() ?? camera['n']?.toString() ?? 'Камера';

    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => VideoPlayerDialog(
        title: name,
        url: streamUrl,
      ),
    ).then((_) {
      _fetchCameras();
    });
  }

  void _open3dGeneratorModal() {
    HapticFeedback.heavyImpact();
    if (!_isVip) {
      _showVipUpgradeDialog();
      return;
    }

    if (_today3dCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Вы исчерпали дневной лимит (3 из 3 3D-иллюстраций на сегодня). Возвращайтесь завтра!'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final promptController = TextEditingController(text: '3D изометрическая панорама улицы и двора Нижневартовска');
    bool isGenerating = false;
    String? generatedImageUrl;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Генератор 3D-Иллюстраций AI Vision',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Text(
                        'Осталось: ${3 - _today3dCount} из 3',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Введите описание городского объекта или выберите быстрый пресет для создания объёмного 3D-рендера (Pixar / Octane 3D style):',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: promptController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Опишите 3D сценарий...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '3D Киберпанк Нижневартовск',
                    '3D Вид на перекресток улиц',
                    '3D Двор в стиле Pixar',
                    '3D Снежная панорама'
                  ].map((preset) => InkWell(
                    onTap: () => setModalState(() => promptController.text = preset),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(preset, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                if (generatedImageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: generatedImageUrl!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => Container(
                        height: 220,
                        color: Colors.black26,
                        child: const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: isGenerating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.brush_rounded),
                    label: Text(
                      isGenerating ? 'Рендеринг 3D сцены...' : 'Сгенерировать 3D-иллюстрацию',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: isGenerating
                        ? null
                        : () async {
                            setModalState(() => isGenerating = true);
                            await _increment3dCount();
                            
                            final rawPrompt = promptController.text.trim();
                            final fullPrompt = '3d isometric render of $rawPrompt, octane 3d render, 8k resolution, highly detailed Pixar style animation';
                            final imgUrl = 'https://image.pollinations.ai/prompt/${Uri.encodeComponent(fullPrompt)}?width=1024&height=768&seed=${DateTime.now().millisecondsSinceEpoch}&model=flux';
                            
                            await Future.delayed(const Duration(milliseconds: 1200));
                            if (!mounted) return;
                            setModalState(() {
                              isGenerating = false;
                              generatedImageUrl = imgUrl;
                            });
                          },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showVipUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amber, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('VIP PREMIUM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Создание 3D ИИ-иллюстраций (3 шт/день) доступно для пользователей с активной VIP-подпиской.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              Navigator.pop(context);
              AppRouter.goToProfile(context: context);
            },
            child: const Text('Активировать VIP', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final glowColor = isDark ? PulseColors.primary : const Color(0xFF0EA5E9);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF06020F) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Умные камеры города',
          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: PulseColors.primary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: PulseColors.primary),
            onPressed: _fetchCameras,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner for 3D AI Illustration generator for VIP subscribers
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD946EF).withOpacity(0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '3D ИИ-ИЛЛЮСТРАЦИИ',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isVip
                            ? 'Лимит: $_today3dCount / 3 генераций сегодня'
                            : '3D генерации для VIP (3 шт/день)',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 0,
                  ),
                  onPressed: _open3dGeneratorModal,
                  child: const Text('Создать 3D', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: PulseColors.primary))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off_rounded, size: 48, color: Colors.redAccent),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(color: textColor, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchCameras,
                                child: const Text('Повторить попытку'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _cameras.isEmpty
                        ? Center(
                            child: Text(
                              'Нет доступных камер',
                              style: TextStyle(color: subColor, fontSize: 13),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchCameras,
                            color: PulseColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              itemCount: _cameras.length,
                              itemBuilder: (context, index) {
                                final cam = _cameras[index];
                                final name = cam['name']?.toString() ?? 'Камера города';
                                final online = cam['online'] as bool? ?? true;
                                final analysesCount = cam['ai_analyses_count'] as int? ?? 0;
                                
                                final statusColor = online ? const Color(0xFF10B981) : const Color(0xFFEF4444);
                                final statusLabel = online ? 'ОНЛАЙН' : 'ОФЛАЙН';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: InkWell(
                                    onTap: () => _openCameraLive(cam),
                                    borderRadius: BorderRadius.circular(14),
                                    child: AppPanel(
                                      padding: const EdgeInsets.all(14),
                                      style: PanelStyle.neo,
                                      borderColor: online 
                                          ? glowColor.withOpacity(0.4) 
                                          : Colors.redAccent.withOpacity(0.3),
                                      child: Row(
                                        children: [
                                          Stack(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: (online ? glowColor : Colors.grey).withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  Icons.videocam_rounded,
                                                  color: online ? glowColor : Colors.grey,
                                                  size: 24,
                                                ),
                                              ),
                                              Positioned(
                                                right: 0,
                                                top: 0,
                                                child: Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: statusColor,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: statusColor.withOpacity(0.7),
                                                        blurRadius: 4,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: statusColor.withOpacity(0.12),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        statusLabel,
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontSize: 8.5,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      Icons.psychology_alt_rounded,
                                                      size: 13,
                                                      color: analysesCount > 0 ? const Color(0xFFF59E0B) : subColor,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'ИИ-анализов: $analysesCount',
                                                      style: TextStyle(
                                                        color: analysesCount > 0 ? const Color(0xFFF59E0B) : subColor,
                                                        fontSize: 11,
                                                        fontWeight: analysesCount > 0 ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 14,
                                            color: subColor.withOpacity(0.6),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
