import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

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

  Future<void> playSplash() async {
    if (_isMuted) return;
    try {
      await _splashPlayer.play(AssetSource('sounds/soft_splash.wav'));
    } catch (error) {
      debugPrint('Splash sound failed: $error');
    }
  }

  Future<void> playSplashDesign(String designName) async {
    if (_isMuted) return;
    final file = <String, String>{
          'aurora': 'splash_aurora.wav',
          'network': 'splash_network.wav',
          'gravity': 'soft_splash.wav',
          'cyber': 'soft_splash.wav',
        }[designName] ??
        'soft_splash.wav';

    try {
      await _splashPlayer.play(AssetSource('sounds/$file'));
    } catch (error) {
      debugPrint('Alternate splash sound failed: $error');
    }
  }

  Future<void> stopSplash() async {
    try {
      if (_splashPlayer.state == PlayerState.playing) {
        await _splashPlayer.stop();
      }
      if (_pulsePlayer.state == PlayerState.playing) {
        await _pulsePlayer.stop();
      }
    } catch (error) {
      debugPrint('Stop splash failed: $error');
    }
  }

  Future<void> playPulse() async {
    if (_isMuted) return;
    try {
      await _pulsePlayer.play(AssetSource('sounds/soft_pulse.wav'));
    } catch (error) {
      debugPrint('Pulse sound failed: $error');
    }
  }

  Future<void> playNewComplaint() async {
    if (_isMuted) return;
    try {
      await _player.play(AssetSource('sounds/new_item.wav'));
    } catch (error) {
      debugPrint('New complaint sound failed: $error');
    }
  }

  Future<void> playSelection() async {
    if (_isMuted) return;
    try {
      await _player.play(AssetSource('sounds/new_item.wav'));
    } catch (error) {
      debugPrint('Selection sound failed: $error');
    }
  }

  Future<void> playCategorySound(String category) async {
    if (_isMuted) return;

    final filename = switch (category) {
      'Дороги' => 'cat_roads.wav',
      'ЖКХ' => 'cat_zhkh.wav',
      'Освещение' => 'cat_light.wav',
      'Транспорт' => 'cat_transport.wav',
      'Экология' => 'cat_ecology.wav',
      'Безопасность' => 'cat_safety.wav',
      'Снег/Наледь' => 'cat_snow.wav',
      'Медицина' || 'Здравоохранение' => 'cat_med.wav',
      'Образование' => 'cat_edu.wav',
      'Парковки' => 'cat_parking.wav',
      'Благоустройство' => 'cat_garden.wav',
      _ => 'cat_other.wav',
    };

    try {
      await _player.play(AssetSource('sounds/$filename'));
    } catch (error) {
      debugPrint('Category sound failed for $category: $error');
    }
  }

  void dispose() {
    _player.dispose();
    _splashPlayer.dispose();
    _pulsePlayer.dispose();
  }
}
