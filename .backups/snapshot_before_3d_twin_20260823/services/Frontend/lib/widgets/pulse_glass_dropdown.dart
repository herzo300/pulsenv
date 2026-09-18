// lib/widgets/pulse_glass_dropdown.dart
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../theme/pulse_colors.dart';

class PulseGlassDropdownItem<T> {
  final T value;
  final Widget child;

  const PulseGlassDropdownItem({
    required this.value,
    required this.child,
  });
}

class PulseGlassDropdown<T> extends StatefulWidget {
  final T? value;
  final Widget? hint;
  final List<PulseGlassDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isNightMode;
  final Color? fillColor;
  final double? width;

  const PulseGlassDropdown({
    super.key,
    required this.value,
    this.hint,
    required this.items,
    required this.onChanged,
    required this.isNightMode,
    this.fillColor,
    this.width,
  });

  @override
  State<PulseGlassDropdown<T>> createState() => _PulseGlassDropdownState<T>();
}

class _PulseGlassDropdownState<T> extends State<PulseGlassDropdown<T>> with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _closeMenu();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
    setState(() {
      _isOpen = true;
    });
  }

  void _closeMenu() {
    if (!_isOpen) return;
    _animationController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      if (mounted) {
        setState(() {
          _isOpen = false;
        });
      }
    });
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeMenu,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: SizedBox(
                width: widget.width ?? size.width,
                child: SizeTransition(
                  sizeFactor: _expandAnimation,
                  axisAlignment: -1,
                  child: FadeTransition(
                    opacity: _opacityAnimation,
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.fillColor ?? 
                                  (widget.isNightMode 
                                      ? const Color(0xEE0B1324) 
                                      : Colors.white.withOpacity(0.9)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: widget.isNightMode 
                                    ? Colors.white.withOpacity(0.12) 
                                    : Colors.black.withOpacity(0.12),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.24),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 280),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shrinkWrap: true,
                                itemCount: widget.items.length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  color: widget.isNightMode 
                                      ? Colors.white.withOpacity(0.08) 
                                      : Colors.black.withOpacity(0.08),
                                ),
                                itemBuilder: (context, index) {
                                  final item = widget.items[index];
                                  final isSelected = widget.value == item.value;
                                  return InkWell(
                                    onTap: () {
                                      widget.onChanged(item.value);
                                      _closeMenu();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      color: isSelected 
                                          ? (widget.isNightMode 
                                              ? Colors.white.withOpacity(0.08) 
                                              : Colors.black.withOpacity(0.04))
                                          : Colors.transparent,
                                      child: DefaultTextStyle(
                                        style: TextStyle(
                                          color: isSelected 
                                              ? PulseColors.primary 
                                              : (widget.isNightMode ? Colors.white70 : Colors.black87),
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        child: item.child,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeItem = widget.items.firstWhere(
      (item) => item.value == widget.value,
      orElse: () => widget.items.first,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleMenu,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.fillColor ?? 
                (widget.isNightMode 
                    ? const Color(0x330B1324) 
                    : Colors.white.withOpacity(0.35)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isNightMode 
                  ? Colors.white.withOpacity(0.12) 
                  : Colors.black.withOpacity(0.12),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: widget.isNightMode ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  child: widget.value == null && widget.hint != null 
                      ? widget.hint! 
                      : activeItem.child,
                ),
              ),
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: widget.isNightMode ? Colors.white60 : Colors.black54,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
