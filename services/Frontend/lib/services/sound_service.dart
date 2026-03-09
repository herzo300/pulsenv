import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Сервис для управления звуками в приложении.
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _splashPlayer = AudioPlayer();
  final AudioPlayer _pulsePlayer = AudioPlayer();

  bool _isMuted = false;

  void setMute(bool mute) {
    _isMuted = mute;
  }

  /// Проиграть звук для сплэш-экрана "Цифровая Невесомость"
  Future<void> playSplash() async {
    if (_isMuted) return;
    try {
      await _splashPlayer.play(AssetSource('sounds/splash_gravity.wav'));
    } catch (e) {
      debugPrint('Ошибка воспроизведения звука сплэша: $e');
    }
  }

  /// Проиграть звук на основе выбранного дизайна
  Future<void> playSplashDesign(String designName) async {
    if (_isMuted) return;
    String file = const {
      'aurora': 'splash_aurora.wav',
      'network': 'splash_network.wav',
      'gravity': 'splash_gravity.wav',
    }[designName] ?? 'splash_particles.wav';
    
    try {
      await _splashPlayer.play(AssetSource('sounds/$file'));
    } catch (e) {
      debugPrint('Ошибка воспроизведения альт. сплэша ($designName): $file -> $e');
    }
  }

  /// Остановить звук сплэша
  Future<void> stopSplash() async {
    try {
      if (_splashPlayer.state == PlayerState.playing) {
        await _splashPlayer.stop();
      }
      if (_pulsePlayer.state == PlayerState.playing) {
        await _pulsePlayer.stop();
      }
    } catch (e) {
      debugPrint('Ошибка остановки сплэша: $e');
    }
  }

  /// Проиграть звук пульса (сердцебиение)
  Future<void> playPulse() async {
    if (_isMuted) return;
    try {
      await _pulsePlayer.play(AssetSource('sounds/pulse.wav'));
    } catch (e) {
      debugPrint('Ошибка воспроизведения пульса: $e');
    }
  }

  /// Проиграть звук появления новой жалобы (общий)
  Future<void> playNewComplaint() async {
    if (_isMuted) return;
    try {
      await _player.play(AssetSource('sounds/new_item.wav'));
    } catch (e) {
      debugPrint('Ошибка воспроизведения звука новой жалобы: $e');
    }
  }

  /// Проиграть звук для конкретной категории
  Future<void> playCategorySound(String category) async {
    if (_isMuted) return;
    
    String filename;
    switch (category) {
      case 'Дороги':
        filename = 'cat_roads.wav';
        break;
      case 'ЖКХ':
        filename = 'cat_zhkh.wav';
        break;
      case 'Освещение':
        filename = 'cat_light.wav';
        break;
      case 'Транспорт':
        filename = 'cat_transport.wav';
        break;
      case 'Экология':
        filename = 'cat_ecology.wav';
        break;
      case 'Безопасность':
        filename = 'cat_safety.wav';
        break;
      case 'Снег/Наледь':
        filename = 'cat_snow.wav';
        break;
      case 'Медицина':
      case 'Здравоохранение':
        filename = 'cat_med.wav';
        break;
      case 'Образование':
        filename = 'cat_edu.wav';
        break;
      case 'Парковки':
        filename = 'cat_parking.wav';
        break;
      case 'Благоустройство':
        filename = 'cat_garden.wav'; // Gardening/Parks
        break;
      default:
        filename = 'cat_other.wav';
    }

    try {
      await _player.play(AssetSource('sounds/$filename'));
    } catch (e) {
      debugPrint('Ошибка воспроизведения звука категории $category: $e');
    }
  }

  void dispose() {
    _player.dispose();
    _splashPlayer.dispose();
    _pulsePlayer.dispose();
  }
}
