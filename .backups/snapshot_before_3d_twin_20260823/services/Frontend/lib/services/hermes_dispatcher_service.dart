import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_api_service.dart';

class HermesDispatcherService {
  static const String _cacheKey = 'hermes_dispatcher_cache';
  static const String _cacheTimeKey = 'hermes_dispatcher_cache_time';

  static final HermesDispatcherService instance = HermesDispatcherService._();
  HermesDispatcherService._();

  // Локальная база знаний (всегда доступна оффлайн)
  static const Map<String, String> _localKnowledge = {
    'трениров': '''
🧠 ОБУЧЕНИЕ И ТРЕНИРОВКА ГЕРМЕСА (Civic Tech AI)
Доступно 5 интерактивных учебных заданий в выбранных направлениях:
1.  [новости] - Мониторинг новостей о ЧП (аварии, отключения) за период.
2.  [животн] - Мониторинг пропавших домашних животных по пабликам.
3.  [претенз] - Создание официальной юридической претензии в УК в PDF.
5.  [эколог] - Анализ химических запахов и выбросов (Windy API).
9.  [отопл] - Контроль параметров теплоснабжения и автоперерасчет.

Введите ключевое слово (например: «Гермес, задание новости» или «претензия пдф»), чтобы получить полную спецификацию задания, шаблоны команд и запустить симуляцию.
''',
    'новост': '''
📋 Задание №1: Мониторинг городских новостей и ЧП
Направление: Парсинг OSINT и классификация инцидентов.
Команда запуска:
`/monitor-news --duration=24h --keywords='пожар, взрыв, дтп, прорыв трубы, потоп' --target='Нижневартовск'`

Спецификация работы:
1. Сканирование: Гермес с интервалом в 15 минут опрашивает 8 крупных городских пабликов VK («Привет, сей час Нижневартовск», «ЧП в Нижневартовске») и 5 Telegram-каналов.
2. Фильтрация: ИИ очищает текст от рекламы и релевантно классифицирует инцидент.
3. Геолокация: Модуль `geoint-locator` пытается определить точный адрес из описания.
4. Результат: Формируется структурированный дайджест в лог и на карту.
''',
    'животн': '''
📋 Задание №2: Мониторинг пропавших животных
Направление: Социальный мониторинг и компьютерное зрение (VLM).
Команда запуска:
`/monitor-pets --area='Нижневартовск' --species='собака, кошка' --alerts=true`

Спецификация работы:
1. OSINT-сбор: Парсинг постов с тегами #потеряшка, #пропала_собака, #найден_кот.
2. Анализ фото: ИИ-модель распознает породу, окрас, наличие ошейника на фото.
3. Сверка баз: Поиск пересечений между объявлениями о пропаже и находках.
4. Оповещение: Автоматическая отправка уведомления кураторам приютов и хозяевам в радиусе 2 км от места обнаружения.
''',
    'претенз': '''
📋 Задание №3: Генерация претензии в УК в PDF
Направление: Цифровой юрист ЖКХ.
Команда запуска:
`/create-pdf-claim --address='ул. Мира, д. 24, кв. 12' --issue='нет горячей воды 10 дней' --recipient='ООО УК Жилищник'`

Спецификация работы:
1. Правовой анализ: ИИ использует RAG-базу для подбора нормативных актов (Постановление Правительства РФ №354, СанПиН 2.1.3684-21, ст. 29 Закона о защите прав потребителей).
2. Расчет компенсации: Вычисление пени за каждый час отсутствия услуги сверх норматива (0.15% от стоимости за каждый час просрочки).
3. PDF-рендеринг: Формирование официального бланка с подписями, ссылками на законы и таблицей расчетов.
4. Доставка: Экспорт в PDF на рабочий стол пользователя и автоотправка на Email УК.
''',
    'эколог': '''
📋 Задание №5: Экологический радар (выбросы и запахи)
Направление: Экологический краудсорсинг.
Команда запуска:
`/monitor-air --district='Индустриальный' --pollutants='запах гари, сероводород'`

Спецификация работы:
1. Кластеризация: Группировка жалоб жителей на неприятные запахи по времени и координатам.
2. Метео-корреляция: Получение вектора ветра через Windy API.
3. Локализация: Проецирование вектора в обратном направлении для вычисления промышленного предприятия — источника выбросов.
4. Отчетность: Отправка сводного отчета в Природоохранную прокуратуру ХМАО.
''',
    'отопл': '''
📋 Задание №9: Контроль теплоснабжения
Направление: Цифровое ЖКХ.
Команда запуска:
`/monitor-heating --address='ул. Чапаева, д. 5' --min-temp=18`

Спецификация работы:
1. Сбор данных: Парсинг температуры воздуха в жилых помещениях по отчетам жителей.
2. Проверка СанПиН: Согласно нормам, температура в угловых комнатах должна быть не ниже +20°C, в обычных — не ниже +18°C.
3. Расчет снижения платы: Каждые 3°C снижения температуры дают скидку 0.15% от стоимости отопления за час.
4. Печать требований: Генерация заявления на перерасчет в «Управление теплоснабжения Нижневартовска».
''',
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
        {
          'query': query,
          'is_vip': isVip,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (data['answer'] != null) {
          String answer = data['answer'] as String;
          final pdfUrl = data['pdf_url'];
          if (pdfUrl != null && pdfUrl.toString().isNotEmpty && !answer.contains(pdfUrl.toString())) {
            answer += '\n\n📄 **[Скачать официальный PDF-документ]($pdfUrl)**';
          }
          _offlineCache[query] = answer;
          await _saveCache();
          return HermesResponse(
            text: answer,
            source: HermesSource.online,
          );
        }
      }
    } catch (e) {
      debugPrint('Hermes online query failed: $e');
    }

    // 2. Ищем в кэше ответов сервера
    if (_offlineCache.containsKey(query)) {
      return HermesResponse(
        text: _offlineCache[query]!,
        source: HermesSource.serverCache,
        cacheAge: _cacheUpdatedAt,
      );
    }

    // 3. Ищем в локальной оффлайн базе знаний
    final localAnswer = _findLocalAnswer(query);
    if (localAnswer != null) {
      return HermesResponse(
        text: localAnswer,
        source: HermesSource.localKnowledge,
      );
    }

    // 4. Дефолтный ответ оффлайн
    return HermesResponse(
      text: '⚠️ Система «Гермес» работает в автономном режиме. Данный запрос требует подключения к сети ХМАО или настройки API-ключа в настройках.\n\nВы можете спросить о локальных службах («жкх», «бензин», «автобус», «скорая», «тишина») или запустить «обучение».',
      source: HermesSource.offline,
    );
  }

  String? _findLocalAnswer(String query) {
    final q = query.toLowerCase();
    for (final kv in _localKnowledge.entries) {
      if (q.contains(kv.key)) return kv.value;
    }
    return null;
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
