import 'dart:convert';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _errorMsg;

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
              if (_analysisResult != null && _analysisResult!.isNotEmpty) {
                SoundService().speak(_analysisResult!);
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
                onAnalyze: _runAiAnalysis,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _SimpleCameraPlayer(url: widget.url),
                  ),
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
                            Text(
                              'Результат AI-анализа (YOLO & VLM)',
                              style: TextStyle(
                                color: Colors.yellowAccent.shade100,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
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
                          Text(
                            _analysisResult!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
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
  final VoidCallback? onAnalyze;

  const _CameraPreviewHeader({
    required this.title,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onFullscreen,
    required this.onClose,
    this.fullscreenIcon = Icons.fullscreen_rounded,
    this.onAnalyze,
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
          if (onAnalyze != null)
            IconButton(
              tooltip: 'AI Анализ кадра',
              onPressed: onAnalyze,
              icon: const Icon(Icons.auto_awesome, color: Colors.yellowAccent),
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
