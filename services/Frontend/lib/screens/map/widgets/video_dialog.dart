import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Video player dialog for live camera streams.
class VideoPlayerDialog extends StatelessWidget {
  final String title;
  final String url;

  const VideoPlayerDialog({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CameraPreviewHeader(
              title: title,
              onFullscreen: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        _CameraPreviewFullscreenScreen(title: title, url: url),
                  ),
                );
              },
              onClose: () => Navigator.of(context).pop(),
              onAnalyze: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AI Захват: кадр отправлен на анализ...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _SimpleCameraPlayer(url: url),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPreviewFullscreenScreen extends StatelessWidget {
  final String title;
  final String url;

  const _CameraPreviewFullscreenScreen({
    required this.title,
    required this.url,
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
                fullscreenIcon: Icons.fullscreen_exit_rounded,
                onFullscreen: () => Navigator.of(context).pop(),
                onClose: () => Navigator.of(context).pop(),
                onAnalyze: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('AI Захват: кадр отправлен на анализ...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
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
  final VoidCallback onFullscreen;
  final VoidCallback onClose;
  final IconData fullscreenIcon;

  const _CameraPreviewHeader({
    required this.title,
    required this.onFullscreen,
    required this.onClose,
    this.fullscreenIcon = Icons.fullscreen_rounded,
    this.onAnalyze,
  });

  final VoidCallback? onAnalyze;

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
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));
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
