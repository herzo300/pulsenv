import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../map/map_config.dart';
import 'backend_api_service.dart';

/// ИИ-Диспетчер Гермес — офлайн/онлайн режим
/// 
/// Для VIP-пользователей:
///   - ответы из локального кэша при отсутствии интернета
///   - автоматическое обновление кэша при появлении сети
/// Для бесплатных:
///   - только онлайн-запросы
class HermesDispatcherService {
  HermesDispatcherService._();
  static final HermesDispatcherService instance = HermesDispatcherService._();

  static const String _cacheKey = 'hermes_offline_cache';
  static const String _cacheTimeKey = 'hermes_cache_updated_at';
  static String get _baseUrl => MapConfig.backendBaseUrl;

  // Локальная база знаний (всегда доступна оффлайн)
  static const Map<String, String> _localKnowledge = {
    'автобус': '''
Автобусное сообщение Нижневартовска:
• Маршрут №1: Центр — Площадь Нефтяников (АТП «Домтрансавто», ЛиАЗ 5292)
• Маршрут №3: ул. Ленина — Мкр. 14 (интервал 15 мин)
• Маршрут №7: Ж/д вокзал — Промышленная зона
• Маршрут №15: Центр — Мкр. Западный (ЛиАЗ Метан)
Расписание: будни 6:00–23:00, выходные 7:00–22:00
''',
    'бензин': '''
Актуальные цены АЗС Нижневартовска:
• АЗС «Роснефть» — АИ-92: 55.3₽, АИ-95: 59.9₽
• АЗС «Газпромнефть» — АИ-92: 55.1₽, АИ-95: 60.2₽
• АЗС «Окис-С» — АИ-92: 54.5₽, АИ-95: 58.9₽ (самая дешёвая)
• АЗС «Лукойл» — АИ-92: 55.8₽, АИ-95: 60.5₽
''',
    'жкх': '''
Управляющие компании Нижневартовска:
• ООО «РемСтрой-НВ» — ул. Омская, 7, тел. 43-45-60
• МКУ «ЖКХ» — пр. Победы, 12, тел. 46-10-11
• ООО «УК Тепловодоснабжение» — тел. 46-55-00
Аварийная служба: 112 (круглосуточно)
Горячая вода: норматив восстановления — 4 часа (ПП РФ №354)
''',
    'дорога': '''
Нормы ямочного ремонта (ГОСТ Р 50597-2017):
• Ямы глубиной >5 см должны устраняться за 5-12 суток
• Опасные участки должны быть огорожены в течение 3 часов
• Куда жаловаться: ГИБДД (102), Дорожный департамент НВ
Онлайн: портал «Госуслуги» → «Дороги и транспорт» → «Ямы и неровности»
''',
    'мусор': '''
Вывоз ТКО — нормы (СанПиН 2.1.3684-21):
• Лето (+5°C и выше): ежедневный вывоз обязателен
• Зима: не реже 1 раза в 3 дня
• Регоператор ХМАО: ООО «ЮграЭкоПром», тел. 8-800-707-86-08
• Жалобы: gosuslugi.ru или портал ЖКХ РФ
''',
    'тишина': '''
Закон о тишине — ХМАО-Югра:
• Будни: тишина с 22:00 до 08:00
• Выходные и праздники: тишина с 22:00 до 10:00
• Дневной тихий час: 13:00–15:00 (для МКД с детьми)
• Ремонтные работы: только 9:00–19:00 в будни
• При нарушении: звонок в полицию 102 или участковому
''',
    'собака': '''
Безнадзорные животные:
• Сообщить в МКУ «Хозяйственный отдел» НВ: тел. 46-10-01
• Закон: ст. 230 ГК РФ — бездомное животное содержится 6 месяцев
• Приют для животных НВ: ул. Индустриальная, 50-А
''',
    'находка': '''
Потерянные вещи:
• Ст. 227 ГК РФ: находку нужно сдать в полицию или муниципалитет
• Срок хранения: 6 месяцев
• По истечении 6 мес. право собственности переходит нашедшему
• Сообщить: МВД НВ, ул. Северная, 74, тел. 02 / 102
''',
    'скорая': '''
Экстренные службы Нижневартовска:
• Скорая помощь: 103 / 112
• Пожарные: 101 / 112
• Полиция: 102 / 112
• Газ: 104 / 112
• НВОКБ: тел. 46-53-00 (ул. Дружбы народов, 27)
• Детская больница: тел. 46-36-00
''',
  };

  // Оффлайн-кэш (хранит ответы сервера)
  Map<String, String> _offlineCache = {};
  DateTime? _cacheUpdatedAt;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    final timeStr = prefs.getString(_cacheTimeKey);
    if (raw != null) {
      try {
        _offlineCache = Map<String, String>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    if (timeStr != null) {
      _cacheUpdatedAt = DateTime.tryParse(timeStr);
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(_offlineCache));
    await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
    _cacheUpdatedAt = DateTime.now();
  }

  /// Основной метод запроса — онлайн или оффлайн
  Future<HermesResponse> ask({
    required String query,
    required bool isVip,
  }) async {
    // 1. Пробуем онлайн-запрос
    try {
      final response = await BackendApiService.instance.postJson(
        '/api/dispatcher/ask',
        {'query': query, 'is_vip': isVip},
        timeout: const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final answer = data['answer'] as String? ?? '';
        // Кэшируем ответ для оффлайна (для VIP)
        if (isVip && answer.isNotEmpty) {
          final cacheKey = _normalizeQuery(query);
          _offlineCache[cacheKey] = answer;
          await _saveCache();
        }
        return HermesResponse(
          text: answer,
          source: HermesSource.online,
          cacheAge: null,
        );
      }
    } catch (_) {
      // Нет сети или сервер недоступен
    }

    // 2. Для VIP — ищем в оффлайн-кэше сервера
    if (isVip) {
      final cachedKey = _findInCache(query);
      if (cachedKey != null) {
        return HermesResponse(
          text: _offlineCache[cachedKey]!,
          source: HermesSource.serverCache,
          cacheAge: _cacheUpdatedAt,
        );
      }
    }

    // 3. Ищем в локальной базе знаний (доступна всем)
    final localAnswer = _findLocalAnswer(query);
    if (localAnswer != null) {
      return HermesResponse(
        text: localAnswer,
        source: HermesSource.localKnowledge,
        cacheAge: null,
      );
    }

    // 4. Если VIP и ничего не нашли — честное сообщение
    if (isVip) {
      return HermesResponse(
        text: 'Нет соединения с сервером. Для получения актуальных данных подключитесь к сети. '
              'Кэш последнего обновления: ${_cacheUpdatedAt != null ? _formatDate(_cacheUpdatedAt!) : "нет данных"}.',
        source: HermesSource.offline,
        cacheAge: _cacheUpdatedAt,
      );
    }

    // 5. Для бесплатных — предложение обновить подключение
    return HermesResponse(
      text: 'ИИ-Диспетчер недоступен — нет соединения с сервером. '
            'Оффлайн-режим доступен для VIP-подписчиков. '
            'Подключитесь к интернету или оформите VIP-доступ.',
      source: HermesSource.offline,
      cacheAge: null,
    );
  }

  String _normalizeQuery(String q) => q.toLowerCase().trim().replaceAll(' ', '_');

  String? _findInCache(String query) {
    final normalized = _normalizeQuery(query);
    // Точное совпадение
    if (_offlineCache.containsKey(normalized)) return normalized;
    // Частичное совпадение
    for (final key in _offlineCache.keys) {
      if (normalized.contains(key) || key.contains(normalized)) return key;
    }
    return null;
  }

  String? _findLocalAnswer(String query) {
    final q = query.toLowerCase();
    for (final kv in _localKnowledge.entries) {
      if (q.contains(kv.key)) return kv.value;
    }
    return null;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Обновить кэш в фоне (вызывать при появлении сети)
  Future<void> refreshCacheIfOnline({required bool isVip}) async {
    if (!isVip) return;
    try {
      final response = await BackendApiService.instance.get(
        '/api/dispatcher/cache-dump',
        timeout: const Duration(seconds: 15),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (data['cache'] is Map) {
          _offlineCache = Map<String, String>.from(data['cache'] as Map);
          await _saveCache();
          debugPrint('Hermes: кэш обновлён (${_offlineCache.length} записей)');
        }
      }
    } catch (e) {
      debugPrint('Hermes: не удалось обновить кэш: $e');
    }
  }
}

enum HermesSource { online, serverCache, localKnowledge, offline }

class HermesResponse {
  final String text;
  final HermesSource source;
  final DateTime? cacheAge;

  const HermesResponse({
    required this.text,
    required this.source,
    this.cacheAge,
  });

  String get sourceLabel {
    switch (source) {
      case HermesSource.online:
        return '🌐 Онлайн';
      case HermesSource.serverCache:
        return '💾 Оффлайн (кэш сервера)';
      case HermesSource.localKnowledge:
        return '📚 Локальная база знаний';
      case HermesSource.offline:
        return '⚡ Оффлайн';
    }
  }

  Color get sourceColor {
    switch (source) {
      case HermesSource.online:
        return const Color(0xFF00C853);
      case HermesSource.serverCache:
        return const Color(0xFFFFAB00);
      case HermesSource.localKnowledge:
        return const Color(0xFF2196F3);
      case HermesSource.offline:
        return const Color(0xFF757575);
    }
  }
}
