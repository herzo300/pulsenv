import 'dart:convert';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_router.dart';
import '../../../map/map_config.dart';
import '../../../services/favorite_cameras_service.dart';
import '../../../services/sound_service.dart';

/// Video player dialog for live camera streams. Includes AI analysis & favorites support.
class VideoPlayerDialog extends StatefulWidget {
  final String title;
  final String url;

  const VideoPlayerDialog({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  bool _isFavorite = false;
  bool _isAnalyzing = false;
  String? _analysisResult;
  String? _speechText;
  String? _redesignImageUrl;
  bool _isGeneratingRedesign = false;
  String? _errorMsg;
  bool _isTtsMuted = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final fav = await FavoriteCamerasService().isFavorite(widget.url);
    if (mounted) {
      setState(() {
        _isFavorite = fav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await FavoriteCamerasService().removeFavorite(widget.url);
      if (mounted) {
        setState(() {
          _isFavorite = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Камера удалена из избранного')),
        );
      }
    } else {
      final success = await FavoriteCamerasService().addFavorite(widget.title, widget.url);
      if (mounted) {
        if (success) {
          setState(() {
            _isFavorite = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Камера добавлена в избранное (макс. 10)')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось добавить. Превышен лимит 10 избранных камер!')),
          );
        }
      }
    }
  }

  Future<void> _runAiAnalysis() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_camera_ai_onboarding') ?? false;

    if (!seen) {
      if (!mounted) return;
      // Show onboarding card
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.yellowAccent),
              SizedBox(width: 8),
              Text('ИИ Анализ Камеры', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Добро пожаловать в систему ИИ-аналитики города!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '• Нейросеть Gemini и YOLO проанализируют текущий кадр с камеры.\n'
                '• Система распознает объекты (люди, транспорт, ямы, мусор, ДТП).\n'
                '• Будет составлен текстовый отчет по дорожной и общественной ситуации.\n'
                '• Результат будет озвучен приятным жизнеутверждающим голосом.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                await prefs.setBool('seen_camera_ai_onboarding', true);
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellowAccent.shade700),
              child: const Text('Понятно', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
      _errorMsg = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${MapConfig.backendApiBaseUrl}/cameras/analyze-free'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'camera_name': widget.title,
          'camera_url': widget.url,
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            if (data['success'] == true || data['report'] != null) {
              _analysisResult = data['report']?.toString();
              _speechText = data['speech_text']?.toString() ?? _analysisResult;
              if (_analysisResult != null && _analysisResult!.isNotEmpty && !_isTtsMuted) {
                _isSpeaking = true;
                SoundService().speak(_speechText ?? _analysisResult!).then((_) {
                  if (mounted) setState(() => _isSpeaking = false);
                });
              }
            } else {
              _errorMsg = 'Не удалось проанализировать кадр.';
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _errorMsg = 'Ошибка сервера: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMsg = 'Не удалось связаться с сервером аналитики.';
        });
      }
    }
  }

  Widget _buildParsedAnalysis(String text) {
    final lines = text.split('\n');
    final List<Widget> compactRows = [];
    String mainAnalysisText = '';

    final regex = RegExp(r'^(?:\#{1,4}\s+)?(?:\*\*)?([А-ЯЁа-яёA-Za-z0-9№\s\-\_\(\)]+?)(?:\*\*)?\s*:\s*(?:\*\*)?\s*(.*)$');

    for (final line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;

      final match = regex.firstMatch(cleanLine);
      if (match != null) {
        final header = match.group(1)!.toLowerCase().trim();
        final value = match.group(2)!.replaceAll('**', '').trim();

        if (value.isEmpty) continue;

        IconData icon;
        Color color;

        if (header.contains('категор') || header.contains('category')) {
          icon = Icons.category_rounded;
          color = Colors.cyanAccent;
        } else if (header.contains('обнаруж') || header.contains('объект') || header.contains('detect') || header.contains('object')) {
          icon = Icons.search_rounded;
          color = Colors.amberAccent;
        } else if (header.contains('угроза') || header.contains('критич') || header.contains('threat') || header.contains('severity')) {
          icon = Icons.report_problem_rounded;
          color = Colors.redAccent;
        } else if (header.contains('рекоменд') || header.contains('recommend')) {
          icon = Icons.lightbulb_outline_rounded;
          color = Colors.greenAccent;
        } else if (header.contains('адрес') || header.contains('location') || header.contains('address')) {
          icon = Icons.location_on_rounded;
          color = Colors.blueAccent;
        } else if (header.contains('анализ') || header.contains('описание') || header.contains('analysis') || header.contains('desc')) {
          mainAnalysisText += (mainAnalysisText.isEmpty ? '' : '\n') + value;
          continue;
        } else {
          icon = Icons.arrow_right_alt_rounded;
          color = Colors.white70;
        }

        compactRows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        if (cleanLine.toLowerCase().startsWith('анализ:') || cleanLine.toLowerCase().startsWith('описание:')) {
          final val = cleanLine.substring(cleanLine.indexOf(':') + 1).trim();
          if (val.isNotEmpty) {
            mainAnalysisText += (mainAnalysisText.isEmpty ? '' : '\n') + val;
          }
        } else {
          mainAnalysisText += (mainAnalysisText.isEmpty ? '' : '\n') + cleanLine;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compactRows.isNotEmpty) ...[
          ...compactRows,
          const SizedBox(height: 10),
          Container(
            height: 1,
            color: Colors.white10,
            margin: const EdgeInsets.only(bottom: 10),
          ),
        ],
        if (mainAnalysisText.isNotEmpty)
          Text(
            mainAnalysisText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
            ),
          ),
      ],
    );
  }

  Future<void> _run3dRedesignModal() async {
    final prefs = await SharedPreferences.getInstance();
    final isVip = prefs.getBool('is_premium_vip') ?? prefs.getBool('is_vip') ?? false;

    if (!isVip) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amber)),
          title: const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('VIP PREMIUM', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            '3D ИИ-перепланировка кадра (детские площадки, воркаут, скверы) доступна для VIP-подписчиков (3 шт/день).',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () {
                Navigator.pop(ctx);
                AppRouter.goToProfile(context: context);
              },
              child: const Text('Включить VIP', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final todayKey = '3d_gen_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}';
    final count = prefs.getInt(todayKey) ?? 0;
    if (count >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Вы исчерпали дневной лимит (3 из 3 3D-перепланировок на сегодня).')),
      );
      return;
    }

    final promptController = TextEditingController(text: '3D детская площадка в стиле Pixar с качелями и горками');

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent, size: 22),
                  SizedBox(width: 8),
                  Text('3D ИИ-Перепланировка кадра', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Выберите объект для 3D достройки поверх live-трансляции двора:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: promptController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  '3D Детский игровой городок',
                  '3D Воркаут площадка',
                  '3D Эко-парк и зеленый сквер',
                  '3D Ландшафтный фонтан',
                  '3D Велопарковка и зона отдыха',
                ].map((p) => ActionChip(
                  backgroundColor: Colors.white.withOpacity(0.08),
                  label: Text(p, style: const TextStyle(fontSize: 11, color: Colors.cyanAccent)),
                  onPressed: () => setModalState(() => promptController.text = p),
                )).toList(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
                  icon: const Icon(Icons.brush_rounded),
                  onPressed: () async {
                    Navigator.of(context).pop(); // Close bottom sheet immediately
                    
                    setState(() {
                      _isGeneratingRedesign = true;
                      _redesignImageUrl = null;
                    });
                    
                    await prefs.setInt(todayKey, count + 1);
                    final userPrompt = promptController.text.trim();
                    final fullPrompt = 'photorealistic 3d architectural visualization of $userPrompt added into urban city yard, matching street perspective, octane 3d render, daytime lighting, 8k resolution, highly detailed';
                    final imgUrl = 'https://image.pollinations.ai/prompt/${Uri.encodeComponent(fullPrompt)}?width=1024&height=768&seed=${DateTime.now().millisecondsSinceEpoch}&model=flux';
                    
                    if (mounted) {
                      setState(() {
                        _isGeneratingRedesign = false;
                        _redesignImageUrl = imgUrl;
                      });
                    }
                  },
                  label: const Text('Сгенерировать и наложить 3D дизайн'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF121214),
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CameraPreviewHeader(
                title: widget.title,
                isFavorite: _isFavorite,
                onFavoriteToggle: _toggleFavorite,
                onFullscreen: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          _CameraPreviewFullscreenScreen(
                            title: widget.title, 
                            url: widget.url,
                            isFavorite: _isFavorite,
                            onFavoriteToggle: _toggleFavorite,
                          ),
                    ),
                  );
                },
                onClose: () => Navigator.of(context).pop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _SimpleCameraPlayer(url: widget.url),
                        ),
                        if (_redesignImageUrl != null)
                          Positioned.fill(
                            child: Image.network(
                              _redesignImageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.black87,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Рендеринг 3D дизайна над камерой... ${loadingProgress.expectedTotalBytes != null ? "${(loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! * 100).toInt()}%" : ""}',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.black87,
                                child: const Center(
                                  child: Text('Ошибка загрузки 3D кадра', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                ),
                              ),
                            ),
                          ),
                        if (_isGeneratingRedesign)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black87,
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                                    SizedBox(height: 12),
                                    Text(
                                      'ИИ генерирует 3D перепланировку...',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Это займет около 3-5 секунд',
                                      style: TextStyle(color: Colors.white54, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_redesignImageUrl != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _redesignImageUrl = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        onPressed: _runAiAnalysis,
                        label: const Text('ИИ-Анализ (VLM)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.brush_rounded, size: 16),
                        onPressed: _run3dRedesignModal,
                        label: const Text('3D ИИ-Дизайн', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isAnalyzing || _analysisResult != null || _errorMsg != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0x26FFFFFF),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.yellowAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Результат AI-анализа (YOLO & VLM)',
                                style: TextStyle(
                                  color: Colors.yellowAccent.shade100,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_analysisResult != null)
                              GestureDetector(
                                onTap: () {
                                  if (_isSpeaking) {
                                    SoundService().stopSpeak();
                                    setState(() => _isSpeaking = false);
                                  } else if (_analysisResult != null && _analysisResult!.isNotEmpty) {
                                    setState(() => _isSpeaking = true);
                                    SoundService().speak(_speechText ?? _analysisResult!).then((_) {
                                      if (mounted) setState(() => _isSpeaking = false);
                                    });
                                  }
                                },
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: Icon(
                                    _isSpeaking ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                    key: ValueKey(_isSpeaking),
                                    color: _isSpeaking ? Colors.redAccent : Colors.yellowAccent.shade100,
                                    size: 20,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() => _isTtsMuted = !_isTtsMuted);
                                if (_isTtsMuted && _isSpeaking) {
                                  SoundService().stopSpeak();
                                  setState(() => _isSpeaking = false);
                                }
                              },
                              child: Tooltip(
                                message: _isTtsMuted ? 'Включить автоозвучку' : 'Выключить автоозвучку',
                                child: Icon(
                                  _isTtsMuted ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
                                  color: _isTtsMuted ? Colors.white38 : Colors.yellowAccent.shade100,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_isAnalyzing)
                          const Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.yellowAccent,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Захват кадра и обработка нейросетью...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (_errorMsg != null)
                          Text(
                            _errorMsg!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        if (_analysisResult != null)
                          _buildParsedAnalysis(_analysisResult!),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraPreviewFullscreenScreen extends StatelessWidget {
  final String title;
  final String url;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _CameraPreviewFullscreenScreen({
    required this.title,
    required this.url,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _SimpleCameraPlayer(url: url),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _CameraPreviewHeader(
                title: title,
                isFavorite: isFavorite,
                onFavoriteToggle: onFavoriteToggle,
                fullscreenIcon: Icons.fullscreen_exit_rounded,
                onFullscreen: () => Navigator.of(context).pop(),
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPreviewHeader extends StatelessWidget {
  final String title;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onFullscreen;
  final VoidCallback onClose;
  final IconData fullscreenIcon;

  const _CameraPreviewHeader({
    required this.title,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onFullscreen,
    required this.onClose,
    this.fullscreenIcon = Icons.fullscreen_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: isFavorite ? 'Убрать из избранного' : 'Добавить в избранное',
            onPressed: onFavoriteToggle,
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: isFavorite ? Colors.amber : Colors.white70,
            ),
          ),
          IconButton(
            tooltip: 'На весь экран',
            onPressed: onFullscreen,
            icon: Icon(fullscreenIcon, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Закрыть',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SimpleCameraPlayer extends StatefulWidget {
  final String url;

  const _SimpleCameraPlayer({required this.url});

  @override
  State<_SimpleCameraPlayer> createState() => _SimpleCameraPlayerState();
}

class _SimpleCameraPlayerState extends State<_SimpleCameraPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _hasError = false;
      _chewieController = null;
    });

    try {
      final Map<String, String> headers = {};
      final lowerUrl = widget.url.toLowerCase();
      if (lowerUrl.contains('pride-net.ru')) {
        headers['Referer'] = 'https://nv86.ru/cam/';
        headers['User-Agent'] = 'PulsGorodaCameraProbe/1.2';
      } else if (lowerUrl.contains('dantser.org')) {
        headers['Referer'] = 'https://dantser.ru/camera/nv';
        headers['User-Agent'] = 'PulsGorodaCameraProbe/1.2';
      }

      _videoPlayerController =
          VideoPlayerController.networkUrl(
            Uri.parse(widget.url),
            httpHeaders: headers,
            formatHint: widget.url.toLowerCase().contains('.m3u8')
                ? VideoFormat.hls
                : null,
          );
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        isLive: true,
        allowFullScreen: false,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.redAccent,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
        errorBuilder: (context, errorMessage) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_off_rounded,
                  color: Colors.white38,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Video initialized error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Поток недоступен',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    if (_chewieController == null ||
        !_chewieController!.videoPlayerController.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black),
      child: Chewie(controller: _chewieController!),
    );
  }
}
