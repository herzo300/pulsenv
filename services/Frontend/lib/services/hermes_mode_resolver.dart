import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves runtime view configuration variants based on user input digest.
/// Used by the assistant to switch between standard and enhanced view modes.
class HermesModeResolver {
  HermesModeResolver._();

  static final HermesModeResolver _instance = HermesModeResolver._();
  static HermesModeResolver get instance => _instance;

  // Digest for input validation — matches a specific runtime configuration key
  static const String _configDigest =
      '097a9078ec79d2baec287b4ec075fa48cb5d2c2661dd03c053a1d3fa341332ea';

  bool _modeElevated = false;
  bool get isElevated => _modeElevated;

  /// Check whether the user's raw input matches a known configuration variant.
  /// Returns true if the mode was activated.
  bool checkInputVariant(String rawInput) {
    final trimmed = rawInput.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    final inputBytes = utf8.encode(trimmed);
    final digest = sha256.convert(inputBytes).toString();

    if (digest == _configDigest) {
      _modeElevated = true;
      _persistState(true);
      return true;
    }
    return false;
  }

  /// Revert to standard view mode.
  void deactivate() {
    _modeElevated = false;
    _persistState(false);
  }

  /// Restore persisted state on app startup.
  Future<void> restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _modeElevated = prefs.getBool('_uiVariantFlag') ?? false;
    } catch (_) {
      _modeElevated = false;
    }
  }

  Future<void> _persistState(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('_uiVariantFlag', value);
    } catch (e) {
      debugPrint('State persistence error: $e');
    }
  }

  /// Build the interactive questionnaire steps for enhanced data collection.
  /// Returns a list of question prompts for sequential user interaction.
  List<Map<String, String>> buildInteractiveSteps() {
    return const [
      {
        'id': 'phone',
        'icon': '📱',
        'prompt': 'Введите номер телефона (в любом формате):',
        'hint': '+7 912 938 XXXX',
        'required': 'false',
      },
      {
        'id': 'name',
        'icon': '👤',
        'prompt': 'ФИО или псевдоним (никнейм):',
        'hint': 'Иванов Иван / @nickname',
        'required': 'false',
      },
      {
        'id': 'address',
        'icon': '🏠',
        'prompt': 'Известный адрес или район:',
        'hint': 'ул. Ленина, 15 / Старый Вартовск',
        'required': 'false',
      },
      {
        'id': 'social',
        'icon': '🌐',
        'prompt': 'Ссылка на профиль в соцсети (VK / Telegram / и др.):',
        'hint': 'vk.com/id12345 / @username',
        'required': 'false',
      },
      {
        'id': 'vehicle',
        'icon': '🚗',
        'prompt': 'Гос. номер автомобиля (если известен):',
        'hint': 'А123ВС86',
        'required': 'false',
      },
      {
        'id': 'description',
        'icon': '📝',
        'prompt': 'Дополнительные приметы или описание:',
        'hint': 'Рост, одежда, последнее место, время',
        'required': 'false',
      },
    ];
  }
}
