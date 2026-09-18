import 'dart:async';
import 'package:flutter/material.dart';

/// A robust network image wrapper that enforces a strict loading timeout
/// and uses theme-aware placeholders to prevent "infinite white blocks".
class SafeImageWidget extends StatefulWidget {
  final String imageUrl;
  final double height;
  final double width;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? heroTag;
  final VoidCallback? onTap;
  final Widget? fallbackWidget;

  const SafeImageWidget({
    super.key,
    required this.imageUrl,
    this.height = 180,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.heroTag,
    this.onTap,
    this.fallbackWidget,
  });

  @override
  State<SafeImageWidget> createState() => _SafeImageWidgetState();
}

class _SafeImageWidgetState extends State<SafeImageWidget> {
  bool _hasError = false;
  bool _isLoaded = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
  }

  @override
  void didUpdateWidget(covariant SafeImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _timeoutTimer?.cancel();
      setState(() {
        _hasError = false;
        _isLoaded = false;
      });
      _startTimeoutTimer();
    }
  }

  void _startTimeoutTimer() {
    // 4-second timeout limit to prevent infinite spinner/white blocks on slow/offline connections
    _timeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isLoaded && !_hasError) {
        setState(() {
          _hasError = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallbackWidget ?? const SizedBox.shrink();
    }

    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    // Theme-aware dark/grey placeholder color, never pure white
    final placeholderColor = isLightTheme 
        ? Colors.black.withOpacity(0.08) 
        : Colors.white.withOpacity(0.06);

    Widget imageWidget = Image.network(
      widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: 450,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null) {
          _isLoaded = true;
          _timeoutTimer?.cancel();
        }
        return child;
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: placeholderColor,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
          ),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isLightTheme ? Colors.black38 : Colors.amber,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        _timeoutTimer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasError) {
            setState(() {
              _hasError = true;
            });
          }
        });
        return widget.fallbackWidget ?? const SizedBox.shrink();
      },
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    if (widget.onTap != null) {
      imageWidget = GestureDetector(
        onTap: widget.onTap,
        child: imageWidget,
      );
    }

    return RepaintBoundary(child: imageWidget);
  }
}
