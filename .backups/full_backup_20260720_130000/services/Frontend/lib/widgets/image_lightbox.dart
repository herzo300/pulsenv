import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/pulse_colors.dart';

/// Fullscreen zoomable photo lightbox with premium animations,
/// drag-to-dismiss, pinch-to-zoom, and multi-image swipe support.
class ImageLightbox extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageLightbox({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  static void show(BuildContext context, List<String> imageUrls, {int initialIndex = 0}) {
    if (imageUrls.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.9),
        pageBuilder: (context, _, __) => ImageLightbox(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends State<ImageLightbox> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late int _currentIndex;
  double _dragOffset = 0.0;
  bool _isZoomed = false;

  final TransformationController _transformationController = TransformationController();
  late TapDownDetails _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
      setState(() {
        _isZoomed = false;
      });
    } else {
      final position = _doubleTapDetails.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
      setState(() {
        _isZoomed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 18 * (1.0 - (_dragOffset.abs() / 400).clamp(0.0, 1.0)),
                sigmaY: 18 * (1.0 - (_dragOffset.abs() / 400).clamp(0.0, 1.0)),
              ),
              child: Container(
                color: Colors.black.withOpacity(
                  (0.85 * (1.0 - (_dragOffset.abs() / 500).clamp(0.0, 0.75))),
                ),
              ),
            ),
          ),

          // Main Image Viewer
          Positioned.fill(
            child: GestureDetector(
              onVerticalDragUpdate: _isZoomed
                  ? null
                  : (details) {
                      setState(() {
                        _dragOffset += details.primaryDelta!;
                      });
                    },
              onVerticalDragEnd: _isZoomed
                  ? null
                  : (details) {
                      if (_dragOffset.abs() > 140) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() {
                          _dragOffset = 0.0;
                        });
                      }
                    },
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Hero(
                  tag: widget.imageUrls[_currentIndex],
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.imageUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                        _transformationController.value = Matrix4.identity();
                        _isZoomed = false;
                      });
                    },
                    physics: _isZoomed ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final url = widget.imageUrls[index];
                      return GestureDetector(
                        onDoubleTapDown: (details) => _doubleTapDetails = details,
                        onDoubleTap: _handleDoubleTap,
                        child: Center(
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            onInteractionEnd: (details) {
                              setState(() {
                                _isZoomed = _transformationController.value != Matrix4.identity();
                              });
                            },
                            minScale: 1.0,
                            maxScale: 4.5,
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Не удалось загрузить изображение',
                                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Header Controls (Close Button, Page counter)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Counter
                  if (widget.imageUrls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.imageUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // Close Button
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        color: Colors.white.withOpacity(0.12),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                          splashRadius: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer indicator for multiple images
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.imageUrls.length, (i) {
                    final active = i == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
