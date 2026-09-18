// lib/widgets/premium/pulse_onboarding_swipe.dart
//
// Премиальный онбординг с liquid-swipe переходами (жидкие «переливания»
// между страницами вместо обычного cross-fade).
//
// На базе liquid_swipe + существующих OnboardingFrame-кадров.
// Можно использовать вместо CinematicOnboarding для VIP-подписчиков.
//
// Премиум-визуал: плавные, физичные переходы создают ощущение дорогого UX.
import 'package:flutter/material.dart';
import 'package:liquid_swipe/liquid_swipe.dart';

import '../../theme/pulse_colors.dart';
import '../../theme/pulse_typography.dart';
import '../../utils/pulse_haptics.dart';

/// Кадр онбординга (локальная копия, чтобы не тащить зависимость).
class OnboardingFrame {
  const OnboardingFrame({
    required this.icon,
    required this.title,
    required this.description,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color? accentColor;
}

/// Liquid-swipe онбординг. Принимает кадры OnboardingFrame.
class PulseOnboardingSwipe extends StatefulWidget {
  const PulseOnboardingSwipe({
    super.key,
    required this.onComplete,
    this.frames,
  });

  final VoidCallback onComplete;
  final List<OnboardingFrame>? frames;

  @override
  State<PulseOnboardingSwipe> createState() => _PulseOnboardingSwipeState();
}

class _PulseOnboardingSwipeState extends State<PulseOnboardingSwipe> {
  late final LiquidController _controller;
  late final List<OnboardingFrame> _frames;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller = LiquidController();
    _frames = widget.frames ?? _defaultFrames();
  }

  List<OnboardingFrame> _defaultFrames() => [
        OnboardingFrame(
          icon: Icons.map_outlined,
          title: 'Живая Карта Города',
          description: 'В левой части экрана находится панель фильтров 🔎 для выбора категорий и районов. Кнопка 📍 в правом нижнем углу быстро центрирует карту по вашему GPS, а переключатель слоев вверху переводит карту в режим ночного мониторинга или отображения городских видеокамер.',
          accentColor: const Color(0xFF0F172A),
        ),
        OnboardingFrame(
          icon: Icons.add_circle_outline_rounded,
          title: 'Умная Подача Сигналов',
          description: 'Нажмите центральную кнопку «+» на панели навигации, чтобы открыть форму. Вы можете сфотографировать дефект, продиктовать описание голосом с помощью кнопки 🎤, а ИИ автоматически распознает тип проблемы и определит точный адрес с помощью обратного геокодирования.',
          accentColor: const Color(0xFF1E3A8A),
        ),
        OnboardingFrame(
          icon: Icons.pets_rounded,
          title: 'Masonry Бюро Находок',
          description: 'Раздел «Находки» выполнен в виде Masonry-сетки с асимметричной высотой карточек. Нажмите кнопку 📍 в форме подачи, чтобы автоматически определить место потери по GPS, или зажмите микрофон 🎤 для записи голосового описания.',
          accentColor: const Color(0xFF0F766E),
        ),
        OnboardingFrame(
          icon: Icons.auto_awesome_rounded,
          title: 'ИИ-Дайджест и Награды',
          description: 'Перейдите на экран ИИ-Дайджеста для просмотра сводки городских событий. Управляйте настройками прозрачности карточек в профиле, просматривайте достижения и уровень активности. Чем больше одобренных сигналов, тем выше ваш статус VIP-гражданина!',
          accentColor: const Color(0xFF5B21B6),
        ),
      ];

  void _onPageChange(int activePageIndex) {
    PulseHaptics.tap();
    setState(() => _current = activePageIndex);
    if (activePageIndex == _frames.length - 1) {
      // На последней странице — кнопку «Начать» нажмёт пользователь.
    }
  }

  void _finish() {
    PulseHaptics.success();
    widget.onComplete();
  }

  Color _bgColor(OnboardingFrame f) =>
      f.accentColor ?? PulseColors.primary;

  @override
  Widget build(BuildContext context) {
    final pages = _frames.map((f) {
      return Container(
        color: _bgColor(f),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Большая иконка в круге
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(f.icon,
                      size: 80, color: Colors.white),
                ),
                const SizedBox(height: 48),
                Text(
                  f.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  f.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                // Кнопка на последней странице
                if (f == _frames.last)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: ElevatedButton(
                      onPressed: _finish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _bgColor(f),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Начать',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          LiquidSwipe(
            pages: pages,
            liquidController: _controller,
            enableSideReveal: true,
            slideIconWidget: const Icon(Icons.arrow_back_rounded,
                color: Colors.white70),
            positionSlideIcon: 0.8,
            onPageChangeCallback: _onPageChange,
            waveType: WaveType.liquidReveal,
            preferDragFromRevealedArea: true,
          ),
          // Прогресс-индикатор сверху
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_frames.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          // Кнопка «Пропустить»
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: TextButton(
              onPressed: _finish,
              child: Text('Пропустить',
                  style: PulseTypography.labelLarge.copyWith(
                      color: Colors.white.withValues(alpha: 0.85))),
            ),
          ),
        ],
      ),
    );
  }
}
