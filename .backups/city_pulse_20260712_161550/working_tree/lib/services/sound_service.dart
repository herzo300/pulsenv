import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'backend_api_service.dart';

import '../map/map_config.dart';
import 'notification_catalog.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();

  factory SoundService() => _instance;

  SoundService._internal();
  Stream<void> get onTtsComplete => _ttsPlayer.onPlayerComplete;


  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _splashPlayer = AudioPlayer();
  final AudioPlayer _pulsePlayer = AudioPlayer();
  final AudioPlayer _ttsPlayer = AudioPlayer();

  bool _isMuted = false;
  bool _stopRequested = false;
  int _speakSession = 0;

  void setMute(bool mute) {
    _isMuted = mute;
  }

  Future<bool> _canPlay() async {
    if (_isMuted) return false;
    
    // Prevent playing sounds when the app is in the background
    try {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) {
        return false;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final vol = prefs.getDouble('sound_volume_level') ?? 0.8;
    await _player.setVolume(vol);
    await _splashPlayer.setVolume(vol);
    await _pulsePlayer.setVolume(vol);
    await _ttsPlayer.setVolume(vol);

    return prefs.getBool('sound_enabled') ?? true;
  }

  String _getSoundUrl(String filename) {
    return '${MapConfig.backendBaseUrl}/static/sounds/$filename';
  }

  Future<void> playSplash() async {
    if (!await _canPlay()) return;
    try {
      await _splashPlayer.play(AssetSource('audio/splash_gravity.mp3'));
    } catch (error) {
      debugPrint('Play splash failed: $error');
    }
  }

  Future<void> playSplashDesign(String designName) async {
    if (!await _canPlay()) return;
    try {
      final nameLower = designName.toLowerCase();
      if (nameLower.contains('ai_core') || nameLower.contains('cyber')) {
        await _splashPlayer.play(AssetSource('audio/splash_ai_core.mp3'));
      } else if (nameLower.contains('monitor') || nameLower.contains('swamp')) {
        await _splashPlayer.play(AssetSource('audio/splash_monitor.mp3'));
      } else if (nameLower.contains('oil')) {
        await _splashPlayer.play(AssetSource('audio/splash_oil.mp3'));
      } else if (nameLower.contains('gravity') || nameLower.contains('radar') || nameLower.contains('aurora')) {
        await _splashPlayer.play(AssetSource('audio/splash_gravity.mp3'));
      } else {
        await _splashPlayer.play(AssetSource('audio/splash_gravity.mp3'));
      }
    } catch (error) {
      debugPrint('Play splash design ($designName) failed: $error');
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
    if (!await _canPlay()) return;
    try {
      await _pulsePlayer.play(AssetSource('audio/menu_confirm.mp3'));
    } catch (error) {
      debugPrint('Play pulse failed: $error');
    }
  }

  Future<void> playNewComplaint() async {
    if (!await _canPlay()) return;
    try {
      await _player.play(AssetSource('audio/menu_notification.mp3'));
    } catch (error) {
      debugPrint('New complaint sound failed: $error');
    }
  }

  Future<void> playAiNotification() async {
    if (!await _canPlay()) return;
    try {
      await _player.play(AssetSource('sounds/soft_pulse.mp3'));
    } catch (error) {
      debugPrint('Play AI notification failed: $error');
    }
  }

  Future<void> playMessageSent() async {
    if (!await _canPlay()) return;
    try {
      await _player.play(AssetSource('audio/menu_confirm.mp3'));
    } catch (error) {
      debugPrint('Play message sent failed: $error');
    }
  }

  Future<void> playSelection() async {
    if (!await _canPlay()) return;
    try {
      await _player.play(AssetSource('audio/menu_confirm.mp3'));
    } catch (error) {
      debugPrint('Selection sound failed: $error');
    }
  }

  Future<void> playEmergencyAlert() async {
    if (!await _canPlay()) return;
    try {
      await _player.play(AssetSource('audio/alert_seismic.mp3'));
    } catch (error) {
      debugPrint('Emergency alert sound failed: $error');
    }
  }

  Future<void> playCategorySound(String category) async {
    if (!await _canPlay()) return;
    try {
      final normalizedCategory = NotificationCatalog.normalize(category);
      final descriptor = NotificationCatalog.describe(normalizedCategory);
      final assetName = descriptor.soundAsset;

      await _player.play(AssetSource('audio/$assetName'));
    } catch (error) {
      debugPrint('Category sound failed for $category: $error');
    }
  }

  Future<void> playComplaintSubmit() async {
    if (!await _canPlay()) return;
    try {
      await _player.play(AssetSource('audio/menu_confirm.mp3'));
    } catch (error) {
      debugPrint('Complaint submit sound failed: $error');
    }
  }

  Future<void> playComplaintResolved() async {
    if (!await _canPlay()) return;
    try {
      await _player.play(AssetSource('audio/menu_confirm.mp3'));
    } catch (error) {
      debugPrint('Complaint resolved sound failed: $error');
    }
  }

  Future<void> playPushNotification() async {
    if (!await _canPlay()) return;
    try {
      await _player.play(AssetSource('audio/menu_notification.mp3'));
    } catch (error) {
      debugPrint('Push notification sound failed: $error');
    }
  }

  Future<void> playEventReminder() async {
    if (!await _canPlay()) return;
    try {
      await _player.play(AssetSource('audio/menu_notification.mp3'));
    } catch (error) {
      debugPrint('Event reminder sound failed: $error');
    }
  }

  Future<void> speak(String text, {bool forcePremium = false}) async {
    if (!await _canPlay() || text.trim().isEmpty) return;

    // Отсекаем всё до "описание сцены:" включительно для анализа камер
    final lowerText = text.toLowerCase();
    final sceneIndex = lowerText.indexOf('описание сцены:');
    if (sceneIndex != -1) {
      text = text.substring(sceneIndex + 'описание сцены:'.length);
    } else {
      final sceneIndex2 = lowerText.indexOf('описание сцены');
      if (sceneIndex2 != -1) {
        text = text.substring(sceneIndex2 + 'описание сцены'.length);
      }
    }

    // 1. Сбрасываем предыдущую сессию и останавливаем любое текущее воспроизведение
    _stopRequested = false;
    final int mySession = ++_speakSession;
    try {
      if (_ttsPlayer.state == PlayerState.playing) {
        await _ttsPlayer.stop();
      }
    } catch (_) {}

    // 2. Extract actual description if it is a formatted DB report containing "Описание:"
    final descriptionMatch = RegExp(
      r'Описание:\s*(.*?)(?:\.\s*(?:Источник|Дата создания|Категория|Статус|Адрес|Управляющая компания|УК)|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (descriptionMatch != null) {
      text = descriptionMatch.group(1)!;
    }

    // 3. Remove "Статус: ..." and "УК: ..." / "Управляющая компания: ..." fields
    text = text.replaceAll(
      RegExp(r'(?:статус|управляющая компания\s*\(ук\)|ук\s*\(управляющая компания\)|управляющая компания|ук):\s*[^.\n;]+(?:[.\n;]|$)?',
        caseSensitive: false),
      '',
    );

    // 4. Remove square brackets entirely to prevent TTS from reading them
    text = text.replaceAll('[', '').replaceAll(']', '').trim();

    // 5. Remove asterisks, hashes, underscores, tildes and other markdown noise
    text = text
        .replaceAll('*', '')
        .replaceAll('#', '')
        .replaceAll('_', ' ')
        .replaceAll('~', '')
        .replaceAll('`', '')
        .replaceAll('|', ' ')
        .replaceAll('>', '')
        .replaceAll('<', '')
        .replaceAll('\\', '');

    // 6. Replace common punctuation/symbols with spoken equivalents
    text = text
        .replaceAll('—', ', ')
        .replaceAll('–', ', ')
        .replaceAll('…', '.')
        .replaceAll(' / ', ' или ')
        .replaceAll('/', ' ')
        .replaceAll('&', ' и ');

    // 7. Clip the text to the last punctuation mark (period, exclamation, question mark, semicolon)
    final lastPunct = text.lastIndexOf(RegExp(r'[.!?;]'));
    if (lastPunct != -1) {
      text = text.substring(0, lastPunct + 1);
    }

    // 8. Collapse extra whitespace
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    // --- Разбиваем длинный текст на чанки ≤ 180 символов по границам предложений ---
    final chunks = _splitIntoChunks(cleanText, 180);

    try {
      bool usedGoogleSuccessfully = false;

      for (int i = 0; i < chunks.length; i++) {
        // Проверяем — пользователь нажал СТОП или начата новая сессия
        if (_stopRequested || mySession != _speakSession) return;

        final chunk = chunks[i].trim();
        if (chunk.isEmpty) continue;

        bool chunkPlayed = false;

        if (forcePremium) {
          try {
            final path = '/api/reports/tts?text=${Uri.encodeComponent(chunk)}';
            final response = await BackendApiService.instance
                .get(path, timeout: const Duration(seconds: 20));

            if (_stopRequested || mySession != _speakSession) return;

            if (response.statusCode == 200 && response.bodyBytes.length > 512) {
              final tempDir = await getTemporaryDirectory();
              final tempFile = File(
                  '${tempDir.path}/tts_back_${DateTime.now().millisecondsSinceEpoch}_$i.mp3');
              await tempFile.writeAsBytes(response.bodyBytes);
              await _ttsPlayer.play(DeviceFileSource(tempFile.path));
              await Future.any([
                _ttsPlayer.onPlayerComplete.first,
                Future.doWhile(() async {
                  await Future<void>.delayed(const Duration(milliseconds: 80));
                  return !_stopRequested && mySession == _speakSession;
                }),
              ]).timeout(const Duration(seconds: 30));

              if (_stopRequested || mySession != _speakSession) return;
              chunkPlayed = true;
            } else {
              debugPrint('Premium Backend TTS chunk $i: status=${response.statusCode}');
            }
          } catch (e) {
            debugPrint('Premium Backend TTS chunk $i failed: $e');
          }
        }

        if (!chunkPlayed && !forcePremium) {
          final googleUrl =
              'https://translate.google.com/translate_tts?ie=UTF-8&tl=ru&client=tw-ob&q=${Uri.encodeComponent(chunk)}';

          try {
            final response = await http
                .get(Uri.parse(googleUrl))
                .timeout(const Duration(seconds: 6));

            if (_stopRequested || mySession != _speakSession) return;

            if (response.statusCode == 200 && response.bodyBytes.length > 512) {
              final tempDir = await getTemporaryDirectory();
              final tempFile = File(
                  '${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}_$i.mp3');
              await tempFile.writeAsBytes(response.bodyBytes);
              await _ttsPlayer.play(DeviceFileSource(tempFile.path));
              await Future.any([
                _ttsPlayer.onPlayerComplete.first,
                Future.doWhile(() async {
                  await Future<void>.delayed(const Duration(milliseconds: 80));
                  return !_stopRequested && mySession == _speakSession;
                }),
              ]).timeout(const Duration(seconds: 30));

              if (_stopRequested || mySession != _speakSession) return;
              chunkPlayed = true;
              usedGoogleSuccessfully = true;
            } else {
              debugPrint(
                  'Google TTS chunk $i: status=${response.statusCode} bytes=${response.bodyBytes.length}');
            }
          } catch (e) {
            debugPrint('Google TTS chunk $i failed: $e');
          }
        }

        if (_stopRequested || mySession != _speakSession) return;

        // Fallback на backend только если Google совсем не работает
        if (!chunkPlayed && !usedGoogleSuccessfully) {
          try {
            final path = '/api/reports/tts?text=${Uri.encodeComponent(chunk)}';
            final response = await BackendApiService.instance
                .get(path, timeout: const Duration(seconds: 20));

            if (_stopRequested || mySession != _speakSession) return;

            if (response.statusCode == 200 && response.bodyBytes.length > 512) {
              final tempDir = await getTemporaryDirectory();
              final tempFile = File(
                  '${tempDir.path}/tts_back_${DateTime.now().millisecondsSinceEpoch}_$i.mp3');
              await tempFile.writeAsBytes(response.bodyBytes);
              await _ttsPlayer.play(DeviceFileSource(tempFile.path));
              await Future.any([
                _ttsPlayer.onPlayerComplete.first,
                Future.doWhile(() async {
                  await Future<void>.delayed(const Duration(milliseconds: 80));
                  return !_stopRequested && mySession == _speakSession;
                }),
              ]).timeout(const Duration(seconds: 30));

              if (_stopRequested || mySession != _speakSession) return;
            } else {
              debugPrint('Backend TTS chunk $i: status=${response.statusCode}');
            }
          } catch (e) {
            debugPrint('Backend TTS chunk $i failed: $e');
          }
        }
      }
    } catch (error) {
      debugPrint('TTS speak failed: $error');
    }
  }

  /// Разбивает текст на чанки не длиннее [maxLen] по границам предложений/слов.
  List<String> _splitIntoChunks(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final chunks = <String>[];
    // Пробуем разбить по . ! ? ; — сохраняем разделитель в конце чанка
    final sentenceRe = RegExp(r'[^.!?;]+[.!?;]?');
    final sentences = sentenceRe.allMatches(text).map((m) => m.group(0)!).toList();

    final buf = StringBuffer();
    for (final sentence in sentences) {
      if (buf.length + sentence.length > maxLen && buf.isNotEmpty) {
        chunks.add(buf.toString().trim());
        buf.clear();
      }
      // Если одно предложение само по себе > maxLen — режем по словам
      if (sentence.length > maxLen) {
        final words = sentence.split(' ');
        for (final word in words) {
          if (buf.length + word.length + 1 > maxLen && buf.isNotEmpty) {
            chunks.add(buf.toString().trim());
            buf.clear();
          }
          if (buf.isNotEmpty) buf.write(' ');
          buf.write(word);
        }
      } else {
        buf.write(sentence);
      }
    }
    if (buf.isNotEmpty) chunks.add(buf.toString().trim());
    return chunks.where((c) => c.isNotEmpty).toList();
  }


  Future<void> stopSpeak() async {
    // Флаг прерывает цикл чанков в speak() немедленно
    _stopRequested = true;
    _speakSession++; // инвалидируем любую активную сессию
    try {
      if (_ttsPlayer.state == PlayerState.playing) {
        await _ttsPlayer.stop();
      }
    } catch (error) {
      debugPrint('Stop TTS failed: $error');
    }
  }

  void dispose() {
    _player.dispose();
    _splashPlayer.dispose();
    _pulsePlayer.dispose();
    _ttsPlayer.dispose();
  }
}
