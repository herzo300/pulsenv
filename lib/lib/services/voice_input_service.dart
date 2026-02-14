// lib/lib/services/voice_input_service.dart
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceInputService {
  static final SpeechToText _speech = SpeechToText();
  static final FlutterTts _tts = FlutterTts();
  static bool _isListening = false;
  static bool _isAvailable = false;
  static final Function(String)? _onResult = null;

  /// Проверить доступность голосового ввода
  static Future<bool> isAvailable() async {
    try {
      final available = await _speech.initialize();
      return available;
    } catch (e) {
      print('Speech to text initialization error: $e');
      return false;
    }
  }

  /// Начать голосовой ввод
  static Future<void> startListening({
    required Function(String) onResult,
    Function()? onError,
    Function()? onListeningStart,
    Function()? onListeningEnd,
  }) async {
    try {
      final available = await isAvailable();
      if (!available) {
        onError?.call();
        return;
      }

      _isListening = true;
      onListeningStart?.call();

      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords ?? '');
        },
        onListeningDone: () {
          _isListening = false;
          onListeningEnd?.call();
        },
        onError: (error) {
          _isListening = false;
          onError?.call();
        },
        partialResults: true,
        localeId: 'ru_RU',
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        listenFor: Duration(seconds: 30),
      );
    } catch (e) {
      _isListening = false;
      onError?.call();
      print('Speech to text error: $e');
    }
  }

  /// Остановить голосовой ввод
  static Future<void> stopListening() async {
    try {
      await _speech.stop();
      _isListening = false;
    } catch (e) {
      print('Stop listening error: $e');
    }
  }

  /// Проверить, идет ли запись
  static bool get isListening => _isListening;

  /// Озвучить текст
  static Future<void> speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      print('TTS error: $e');
    }
  }

  /// Остановить озвучивание
  static Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      print('Stop TTS error: $e');
    }
  }

  /// Установить язык
  static Future<void> setLanguage(String language) async {
    await _speech.setLocaleId(language);
    await _tts.setLanguage(language);
  }

  /// Установить голос
  static Future<void> setVoice(String voice) async {
    await _tts.setVoice(voice);
  }

  /// Получить список языков
  static Future<List<dynamic>?> getLanguages() async {
    return await _speech.locales;
  }

  /// Получить список голосов
  static Future<List<dynamic>?> getVoices() async {
    return await _tts.getVoices;
  }
}
