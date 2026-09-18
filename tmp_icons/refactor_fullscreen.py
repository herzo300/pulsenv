# Refactor fullscreen screen: composite modes + redesign support
import re

p = r'C:\Soobshio_project\services\Frontend\lib\screens\map\widgets\video_dialog.dart'
src = open(p, encoding='utf-8').read()

start = src.index('class _CameraPreviewFullscreenScreen extends StatelessWidget {')
end = src.index('class _CameraPreviewHeader extends StatelessWidget {')

new_class = r'''class _CameraPreviewFullscreenScreen extends StatefulWidget {
  final String title;
  final String url;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final String? redesignImageUrl;

  const _CameraPreviewFullscreenScreen({
    required this.title,
    required this.url,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.redesignImageUrl,
  });

  @override
  State<_CameraPreviewFullscreenScreen> createState() =>
      _CameraPreviewFullscreenScreenState();
}

class _CameraPreviewFullscreenScreenState
    extends State<_CameraPreviewFullscreenScreen> {
  String _overlayMode = 'split'; // 'split', 'blend', 'seamless', 'full'
  double _splitPos = 0.5;
  double _blendOpacity = 0.8;

  Widget _buildRedesignImage(BoxFit fit) {
    final imgSource = widget.redesignImageUrl;
    if (imgSource == null) return const SizedBox.shrink();
    if (imgSource.startsWith('data:image')) {
      final b64 = imgSource.split(',').last;
      return Image.memory(
        base64Decode(b64),
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
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2.5),
      ),
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  Widget _buildComposite(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    // Без дизайна — обычный плеер на весь экран
    if (widget.redesignImageUrl == null) {
      return _SimpleCameraPlayer(url: widget.url);
    }

    if (_overlayMode == 'full') {
      return _buildRedesignImage(BoxFit.contain);
    }

    if (_overlayMode == 'blend') {
      return Stack(
        fit: StackFit.expand,
        children: [
          _SimpleCameraPlayer(url: widget.url),
          Opacity(
            opacity: _blendOpacity,
            child: _buildRedesignImage(BoxFit.cover),
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
              child: _buildRedesignImage(BoxFit.cover),
            ),
          ),
        ],
      );
    }

    // 'split': интерактивная шторка до/после
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
          Positioned.fill(child: _SimpleCameraPlayer(url: widget.url)),
          Positioned.fill(
            child: ClipRect(
              clipper: _RightSplitClipper(_splitPos),
              child: _buildRedesignImage(BoxFit.cover),
            ),
          ),
          // Линия шторки
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
          // Ручка шторки
          Positioned(
            left: splitX - 18,
            top: (height / 2) - 18,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.code_rounded, color: Color(0xFF00E5FF), size: 18),
              ),
            ),
          ),
          // Бейджи
          Positioned(
            top: 64,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                '📷 КАМЕРА',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Positioned(
            top: 64,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E5FF)),
              ),
              child: const Text(
                '✨ 3D ДИЗАЙН',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBtn(String mode, String label, IconData icon) {
    final active = _overlayMode == mode;
    return InkWell(
      onTap: () => setState(() => _overlayMode = mode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8B5CF6).withOpacity(0.3) : Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFF00E5FF) : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? const Color(0xFF00E5FF) : Colors.white60),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white60,
                fontSize: 12,
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
    final hasDesign = widget.redesignImageUrl != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    _buildComposite(constraints),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _CameraPreviewHeader(
                title: widget.title,
                isFavorite: widget.isFavorite,
                onFavoriteToggle: widget.onFavoriteToggle,
                fullscreenIcon: Icons.fullscreen_exit_rounded,
                onFullscreen: () => Navigator.of(context).pop(),
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
            // Контролы режимов наложения поверх полного экрана
            if (hasDesign)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.35)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildModeBtn('split', '✂️ Шторка', Icons.compare_arrows_rounded),
                          _buildModeBtn('blend', '🌫 Смешивание', Icons.opacity_rounded),
                          _buildModeBtn('seamless', '🔮 Мягкое', Icons.blur_on_rounded),
                          _buildModeBtn('full', '🖼 Только 3D', Icons.image_rounded),
                        ],
                      ),
                      if (_overlayMode == 'blend' || _overlayMode == 'seamless') ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.opacity_rounded, size: 15, color: Colors.white54),
                            const SizedBox(width: 6),
                            Text('Прозрачность: ${(_blendOpacity * 100).toInt()}%',
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  thumbColor: const Color(0xFF00E5FF),
                                  activeTrackColor: const Color(0xFF8B5CF6),
                                  inactiveTrackColor: Colors.white12,
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}

'''

src = src[:start] + new_class + src[end:]

# Pass redesign image to fullscreen from dialog
src = src.replace(
    '''                          _CameraPreviewFullscreenScreen(
                            title: widget.title, 
                            url: widget.url,
                            isFavorite: _isFavorite,
                            onFavoriteToggle: _toggleFavorite,
                          ),''',
    '''                          _CameraPreviewFullscreenScreen(
                            title: widget.title, 
                            url: widget.url,
                            isFavorite: _isFavorite,
                            onFavoriteToggle: _toggleFavorite,
                            redesignImageUrl: _redesignImageUrl,
                          ),''', 1)

open(p, 'w', encoding='utf-8', newline='').write(src)
print('fullscreen refactored OK')
