import 'dart:convert';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_router.dart';
import '../../../map/map_config.dart';
import '../../../services/favorite_cameras_service.dart';
import '../../../services/sound_service.dart';

import '../../complaint_form_screen.dart';

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
    // ИИ-анализ запускается сразу — без диалога-описания
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
              final rawSpeech = data['speech_text']?.toString() ?? _analysisResult ?? '';
              _speechText = rawSpeech.replaceAll(RegExp(r'^Оператор системы мониторинга[^\n]*\n*'), '').trim();
              if (_analysisResult != null && _analysisResult!.isNotEmpty && !_isTtsMuted) {
                _isSpeaking = true;
                SoundService().speak(_speechText!.isNotEmpty ? _speechText! : _analysisResult!).then((_) {
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
    final todayKey = '3d_gen_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}';
    final count = prefs.getInt(todayKey) ?? 0;
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

                    try {
                      var response = await http.post(
                        Uri.parse('${MapConfig.backendApiBaseUrl}/cameras/redesign'),
                        headers: {'Content-Type': 'application/json; charset=utf-8'},
                        body: jsonEncode({
                          'camera_id': widget.title.hashCode.abs().toString(),
                          'camera_url': widget.url,
                          'camera_name': widget.title,
                          'prompt': userPrompt,
                        }),
                      ).timeout(const Duration(seconds: 25));

                      if (response.statusCode != 200) {
                        // Fallback attempt
                        response = await http.post(
                          Uri.parse('${MapConfig.backendApiBaseUrl}/api/cameras/redesign'),
                          headers: {'Content-Type': 'application/json; charset=utf-8'},
                          body: jsonEncode({
                            'camera_id': widget.title.hashCode.abs().toString(),
                            'camera_url': widget.url,
                            'camera_name': widget.title,
                            'prompt': userPrompt,
                          }),
                        ).timeout(const Duration(seconds: 15));
                      }

                      if (response.statusCode == 200) {
                        final data = jsonDecode(utf8.decode(response.bodyBytes));
                        if (data['success'] == false && data['message'] != null) {
                          if (mounted) {
                            setState(() {
                              _isGeneratingRedesign = false;
                              _errorMsg = data['message'];
                            });
                          }
                        } else if (mounted) {
                          setState(() {
                            _isGeneratingRedesign = false;
                            _redesignImageUrl = data['image_base64'] ?? data['image_url'];
                          });
                        }
                      } else {
                        if (mounted) {
                          setState(() {
                            _isGeneratingRedesign = false;
                            _errorMsg = 'Не удалось сгенерировать 3D перепланировку.';
                          });
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          _isGeneratingRedesign = false;
                          _errorMsg = 'Ошибка 3D визуализации.';
                        });
                      }
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

  String _overlayMode = 'split'; // 'split', 'blend', 'seamless', 'full'
  double _splitPos = 0.5; // 0.0 .. 1.0 for before/after wipe
  double _blendOpacity = 0.8; // 0.0 .. 1.0 for transparency mode

  Widget _buildRedesignImageOverlay(String imgSource, {BoxFit fit = BoxFit.cover}) {
    if (imgSource.startsWith('data:image')) {
      final base64String = imgSource.split(',').last;
      return Image.memory(
        base64Decode(base64String),
        fit: fit,
        filterQuality: FilterQuality.high,
      );
    }
    final effectiveUrl = imgSource.startsWith('http')
        ? imgSource
        : '${MapConfig.backendApiBaseUrl.replaceAll('/api/v1', '')}$imgSource';
    return CachedNetworkImage(
      imageUrl: effectiveUrl,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 350),
      placeholder: (context, url) => Container(
        color: Colors.transparent,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2.5),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Text('Синтез 3D-благоустройства...', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompositeCameraView(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    if (_redesignImageUrl == null) {
      return _SimpleCameraPlayer(url: widget.url);
    }

    if (_overlayMode == 'full') {
      return _buildRedesignImageOverlay(_redesignImageUrl!);
    }

    if (_overlayMode == 'blend') {
      return Stack(
        fit: StackFit.expand,
        children: [
          _SimpleCameraPlayer(url: widget.url),
          Opacity(
            opacity: _blendOpacity,
            child: _buildRedesignImageOverlay(_redesignImageUrl!),
          ),
        ],
      );
    }

    if (_overlayMode == 'seamless') {
      return Stack(
        fit: StackFit.expand,
        children: [
          _SimpleCameraPlayer(url: widget.url),
          ShaderMask(
            shaderCallback: (rect) {
              return const RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: [Colors.black, Colors.black87, Colors.transparent],
                stops: [0.4, 0.75, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: Opacity(
              opacity: _blendOpacity,
              child: _buildRedesignImageOverlay(_redesignImageUrl!),
            ),
          ),
        ],
      );
    }

    // Default: 'split' interactive before/after wipe
    final splitX = (width * _splitPos).clamp(10.0, width - 10.0);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _splitPos = (details.localPosition.dx / width).clamp(0.05, 0.95);
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: Live Camera feed (Left side visible)
          Positioned.fill(
            child: _SimpleCameraPlayer(url: widget.url),
          ),
          // Foreground: 3D AI Design Photo (Clipped to right side)
          Positioned.fill(
            child: ClipRect(
              clipper: _RightSplitClipper(_splitPos),
              child: _buildRedesignImageOverlay(_redesignImageUrl!),
            ),
          ),
          // Splitter Divider Line
          Positioned(
            left: splitX - 1.5,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.8),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          // Splitter Center Handle
          Positioned(
            left: splitX - 16,
            top: (height / 2) - 16,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.code_rounded, color: Color(0xFF00E5FF), size: 16),
              ),
            ),
          ),
          // Left Badge: "КАМЕРА"
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                '📷 КАМЕРА',
                style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Right Badge: "3D ДИЗАЙН"
          Positioned(
            top: 8,
            right: 42,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF00E5FF)),
              ),
              child: const Text(
                '✨ 3D ДИЗАЙН',
                style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayControls() {
    if (_redesignImageUrl == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModeButton('split', '✂️ Шторка', Icons.compare_arrows_rounded),
              _buildModeButton('blend', '🌫 Смешивание', Icons.opacity_rounded),
              _buildModeButton('seamless', '🔮 Мягкое', Icons.blur_on_rounded),
              _buildModeButton('full', '🖼 Только 3D', Icons.image_rounded),
            ],
          ),
          if (_overlayMode == 'blend' || _overlayMode == 'seamless') ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.opacity_rounded, size: 14, color: Colors.white54),
                const SizedBox(width: 6),
                Text('Прозрачность: ${(_blendOpacity * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      thumbColor: const Color(0xFF00E5FF),
                      activeTrackColor: const Color(0xFF8B5CF6),
                      inactiveTrackColor: Colors.white12,
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: _blendOpacity,
                      min: 0.1,
                      max: 1.0,
                      onChanged: (v) => setState(() => _blendOpacity = v),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, String label, IconData icon) {
    final active = _overlayMode == mode;
    return InkWell(
      onTap: () => setState(() => _overlayMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8B5CF6).withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF00E5FF) : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? const Color(0xFF00E5FF) : Colors.white60),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white60,
                fontSize: 10.5,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
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
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                _buildCompositeCameraView(constraints),
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
                                      'ИИ генерирует фотореалистичный 3D дизайн...',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Наложение на камеру в ультра-качестве Flux 8K',
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
              _buildOverlayControls(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // ИИ-сетка проблем удалена по запросу пользователя:
                        // осталась функциональная связка — ИИ-анализ кадра и
                        // генерация 3D-дизайна поверх живого превью камеры.
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            onPressed: _runAiAnalysis,
                            label: const Text('ИИ-Анализ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.brush_rounded, size: 16),
                            onPressed: _run3dRedesignModal,
                            label: const Text('3D Дизайн', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                          ),
                        ),
                      ],
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
  bool _useSnapshotFallback = false;
  int _snapshotKey = 0;
  var _snapshotTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _snapshotTimer?.cancel();
    if (mounted) {
      setState(() {
        _hasError = false;
        _useSnapshotFallback = false;
        _chewieController = null;
      });
    }

    try {
      final rawTarget = MapConfig.cameraAnalysisUrl(widget.url);
      final playUrl = MapConfig.cameraPlaybackUrl(rawTarget);

      final Map<String, String> headers = {};
      final lowerUrl = playUrl.toLowerCase();
      if (lowerUrl.contains('pride-net.ru')) {
        headers['Referer'] = 'https://nv86.ru/cam/';
        headers['User-Agent'] = 'PulsGorodaCameraProbe/1.2';
      } else if (lowerUrl.contains('dantser.org')) {
        headers['Referer'] = 'https://dantser.ru/camera/nv';
        headers['User-Agent'] = 'PulsGorodaCameraProbe/1.2';
      }

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
        httpHeaders: headers,
        formatHint: (playUrl.contains('.m3u8') || rawTarget.contains('.m3u8'))
            ? VideoFormat.hls
            : null,
      );

      // Add 7-second timeout for video init before fallback
      await _videoPlayerController!.initialize().timeout(
        const Duration(seconds: 7),
        onTimeout: () {
          throw Exception('Video stream timeout, switching to live snapshot');
        },
      );

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
          return _buildSnapshotFallbackWidget();
        },
      );
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Video initialized error: $e. Using live snapshot fallback.');
      _startSnapshotFallback();
    }
  }

  void _startSnapshotFallback() {
    if (!mounted) return;
    setState(() {
      _useSnapshotFallback = true;
      _hasError = false;
    });

    _snapshotTimer?.cancel();
    // Auto-refresh snapshot every 3 seconds for continuous live stream feel
    _snapshotTimer = Stream.periodic(const Duration(seconds: 3)).listen((_) {
      if (mounted) {
        setState(() {
          _snapshotKey++;
        });
      }
    });
  }

  @override
  void dispose() {
    _snapshotTimer?.cancel();
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Widget _buildSnapshotFallbackWidget() {
    final rawTarget = MapConfig.cameraAnalysisUrl(widget.url);
    final snapshotUrl = '${MapConfig.backendApiBaseUrl}/cameras/snapshot?url=${Uri.encodeComponent(rawTarget)}&t=$_snapshotKey';

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          key: ValueKey('cam_snap_${rawTarget}_$_snapshotKey'),
          imageUrl: snapshotUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            color: Colors.black,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 40),
                const SizedBox(height: 10),
                const Text(
                  'Прямой эфир временно недоступен',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _initializePlayer,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF), size: 16),
                  label: const Text('Переподключиться', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.85),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 6),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                SizedBox(width: 4),
                Text(
                  'LIVE КАДРЫ',
                  style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: IconButton(
            tooltip: 'Попробовать видеопоток',
            icon: const Icon(Icons.videocam_rounded, color: Colors.white70, size: 20),
            onPressed: _initializePlayer,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useSnapshotFallback) {
      return _buildSnapshotFallbackWidget();
    }

    if (_hasError) {
      return _buildSnapshotFallbackWidget();
    }

    if (_chewieController == null ||
        !_chewieController!.videoPlayerController.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black),
      child: Chewie(controller: _chewieController!),
    );
  }
}

class _RightSplitClipper extends CustomClipper<Rect> {
  final double splitFraction;

  _RightSplitClipper(this.splitFraction);

  @override
  Rect getClip(Size size) {
    final left = size.width * splitFraction;
    return Rect.fromLTRB(left, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_RightSplitClipper oldClipper) {
    return oldClipper.splitFraction != splitFraction;
  }
}
