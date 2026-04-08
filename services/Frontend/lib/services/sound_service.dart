import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_catalog.dart';

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

  Future<bool> _canPlay() async {
    if (_isMuted) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sound_enabled') ?? true;
  }

  Future<void> playSplash() async {
    // Silenced as per user request
    return;
  }

  Future<void> playSplashDesign(String designName) async {
    // Silenced as per user request
    return;
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
    // Silenced as per user request
    return;
  }

  Future<void> playNewComplaint() async {
    if (!await _canPlay()) return;
    try {
      await _player.play(AssetSource('sounds/new_item.wav'));
    } catch (error) {
      debugPrint('New complaint sound failed: $error');
    }
  }

  Future<void> playSelection() async {
    if (!await _canPlay()) return;
    try {
      await _player.play(AssetSource('sounds/new_item.wav'));
    } catch (error) {
      debugPrint('Selection sound failed: $error');
    }
  }

  Future<void> playCategorySound(String category) async {
    if (!await _canPlay()) return;
    final filename = NotificationCatalog.describe(category).soundAsset;

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
