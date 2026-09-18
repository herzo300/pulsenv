import 'dart:math' as math;
import 'package:soobshio/map/map_config.dart';

class SituationHelper {
  static final RegExp _imageUrlPattern = RegExp(
    r'''(https?://[^\s\]\)\>\"\']+|/(?:static|media|uploads)/[^\s\]\)\>\"\']+)''',
    caseSensitive: false,
  );

  static final RegExp _socialCdnPattern = RegExp(
    r'''https?://(?:cdn\d*\.telesco\.(?:pe|ph)|userapi\.com|pp\.userapi\.com|sun\d-\d+\.userapi\.com|vk\.com/impf)[^\s\]\)\>\"\']+''',
    caseSensitive: false,
  );

  /// Collects all image URLs from report fields and description (TG/VK CDN included).
  static List<String> extractImageUrls(dynamic report) {
    if (report == null) return const [];

    final urls = <String>[];
    void add(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      final resolved = resolveImageUrl(raw.trim());
      if (resolved.isNotEmpty && !urls.contains(resolved)) {
        urls.add(resolved);
      }
    }

    if (report is Map) {
      if (report['images'] is List) {
        for (final item in report['images'] as List) {
          add(item?.toString());
        }
      } else if (report['images'] is String) {
        add(report['images'] as String);
      }
      add(report['photo_url']?.toString());
      add(report['image_url']?.toString());
      add(report['image']?.toString());

      final desc = (report['description'] ?? report['summary'] ?? '').toString();
      if (desc.contains('Фото: ')) {
        final afterPhoto = desc.split('Фото: ').skip(1).join('Фото: ');
        for (final match in _imageUrlPattern.allMatches(afterPhoto)) {
          add(match.group(0));
        }
        for (final match in _socialCdnPattern.allMatches(afterPhoto)) {
          add(match.group(0));
        }
      }
      for (final match in _imageUrlPattern.allMatches(desc)) {
        final candidate = match.group(0) ?? '';
        if (_looksLikeImageUrl(candidate)) add(candidate);
      }
      for (final match in _socialCdnPattern.allMatches(desc)) {
        add(match.group(0));
      }

      if (urls.isEmpty) {
        final category = report['category']?.toString() ?? 'Городское событие';
        final title = (report['title'] ?? '').toString();
        final prompt = 'photorealistic high resolution photo of $title, $category in Nizhnevartovsk city, urban street environment, daylight, high quality, 8k, sharp details';
        final aiGeneratedUrl = 'https://image.pollinations.ai/prompt/${Uri.encodeComponent(prompt)}?width=1280&height=720&model=flux&nologo=true';
        urls.add(aiGeneratedUrl);
      }
    }

    return urls;
  }

  static bool _looksLikeImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.gif') ||
        lower.contains('.webp') ||
        lower.contains('uploads/') ||
        lower.contains('reports-media') ||
        lower.contains('telesco.pe') ||
        lower.contains('userapi.com') ||
        lower.contains('pollinations.ai') ||
        lower.contains('/impf/');
  }

  /// Resolves relative URLs by prepending the backend base URL.
  static String resolveImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    var url = rawUrl.trim();
    final base = MapConfig.backendBaseUrl;

    if (url.contains('localhost:8000')) {
      url = url.replaceAll('http://localhost:8000', base).replaceAll('https://localhost:8000', base);
    }
    if (url.contains('127.0.0.1:8000')) {
      url = url.replaceAll('http://127.0.0.1:8000', base).replaceAll('https://127.0.0.1:8000', base);
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '$base$url';
    }
    return '$base/$url';
  }

  /// Cleans the situation description by removing source links, source channel names,
  /// and avoiding duplication of the title at the start of the description.
  static String cleanDescription(String? rawDesc, String title) {
    if (rawDesc == null || rawDesc.trim().isEmpty) return '';
    String desc = rawDesc.trim();
    
    // Extract actual description if it is a formatted DB report containing "Описание:"
    final descriptionMatch = RegExp(
      r'Описание:\s*(.*?)(?:\.\s*(?:Источник|Дата создания|Категория|Статус|Адрес|Управляющая компания|УК)|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(desc);
    if (descriptionMatch != null) {
      desc = descriptionMatch.group(1)!;
    }

    // Explicitly remove "Статус: ..." and "УК: ..." / "Управляющая компания: ..." fields
    desc = desc.replaceAll(
      RegExp(r'(?:статус|управляющая компания\s*\(ук\)|ук\s*\(управляющая компания\)|управляющая компания|ук):\s*[^.\n;]+(?:[.\n;]|$)?',
        caseSensitive: false),
      '',
    );

    // Remove square brackets entirely to prevent TTS reading them
    desc = desc.replaceAll('[', '').replaceAll(']', '').trim();

    final cleanTitle = title.trim();

    // 1. Remove photo URL patterns
    desc = desc.replaceAll(RegExp(r'Фото:\s*\S+', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '');

    // 2. Remove typical promotional, subscription, and source mentions
    desc = desc.replaceAll(RegExp(r'(?:прислать|предложить|предлагайте|присылайте)\s+новость', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'предложить\s+новость/сотрудничество', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'подписаться\s+на\s+чп\s+нижневартовск', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'подписывайтесь\s+на\s+нас', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'подписывайтесь\s+на\s+чп\s+нижневартовск', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'подписаться\s+на\s+наш\s+канал', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'чп\s+нижневартовск', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'чпнв', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'чп\s+нв', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'подписывайтесь\s+на\s+сообщество', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'все\s+новости\s+тут', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'подробнее\s+в\s+источнике', caseSensitive: false), '');

    desc = desc.replaceAll(RegExp(r'\(?Источник:\s*[^\)\n]+\)?', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'\(?Источник\s*-\s*[^\)\n]+\)?', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'vk\.com\/[a-zA-Z0-9_\-\.\/]+', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r't\.me\/[a-zA-Z0-9_\-\.\/]+', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'vk:[a-zA-Z0-9_\-\.\/]+', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'tg:[a-zA-Z0-9_\-\.\/]+', caseSensitive: false), '');
    desc = desc.replaceAll(RegExp(r'@(?:[a-zA-Z0-9_]{5,32})', caseSensitive: false), '');
    
    // Clean up empty parentheses/brackets and double spaces
    desc = desc.replaceAll(RegExp(r'\(\s*\)'), '');
    desc = desc.replaceAll(RegExp(r'\[\s*\]'), '');
    desc = desc.replaceAll(RegExp(r'\s+'), ' ');

    // 3. Remove title duplication from start of description
    String cleanDesc = desc.trim();
    final lowerDescForAnalysis = cleanDesc.toLowerCase();
    final analysisMarkers = [
      'краткий анализ ситуации',
      'краткий анализ',
      'анализ ситуации:',
      'анализ (ии):'
    ];
    for (final marker in analysisMarkers) {
      final idx = lowerDescForAnalysis.indexOf(marker);
      if (idx != -1) {
        cleanDesc = cleanDesc.substring(0, idx).trim();
        break;
      }
    }

    if (cleanTitle.isNotEmpty && cleanDesc.toLowerCase().startsWith(cleanTitle.toLowerCase())) {
      cleanDesc = cleanDesc.substring(cleanTitle.length).trim();
      cleanDesc = cleanDesc.replaceFirst(RegExp(r'^[\.\,\-\s\:;!]+'), '').trim();
    }

    if (cleanDesc.isEmpty) {
      String fallback = desc.trim();
      fallback = fallback.replaceFirst(RegExp(r'^[\.\,\-\s\:;!]+'), '').trim();
      cleanDesc = fallback;
    }

    if (cleanDesc.length > 220) {
      final sub = cleanDesc.substring(0, 220);
      final lastSentenceEnd = math.max(
        sub.lastIndexOf('. '),
        math.max(sub.lastIndexOf('! '), sub.lastIndexOf('? ')),
      );
      if (lastSentenceEnd > 60) {
        cleanDesc = sub.substring(0, lastSentenceEnd + 1).trim();
      } else {
        final lastSpace = sub.lastIndexOf(' ');
        if (lastSpace > 60) {
          cleanDesc = sub.substring(0, lastSpace).trim() + '...';
        } else {
          cleanDesc = sub.trim() + '...';
        }
      }
    }

    return cleanDesc;
  }

  /// Automatically generates a detailed situation analysis with accurate Russian legal norms & GOSTs.
  static Map<String, String> analyzeSituation(String? category, String? description) {
    final cat = (category ?? 'Прочее').toLowerCase();
    final desc = (description ?? '').toLowerCase();

    String severity = 'Обычный';
    String scope = 'Локальный';
    String impact = 'Информационный мониторинг';
    String legal = '• Федеральный закон № 59-ФЗ «О порядке рассмотрения обращений граждан РФ» (срок регистрации — 3 дня, рассмотрение и официальный ответ — до 30 дней).\n'
        '• Ответственный орган: Муниципальный центр управления г. Нижневартовска (МЦУ).';

    if (cat.contains('чс') || cat.contains('пожар') || cat.contains('безопасность') ||
        desc.contains('пожар') || desc.contains('горит') || desc.contains('дым') ||
        desc.contains('взрыв') || desc.contains('драка') || desc.contains('полици') ||
        desc.contains('пострада') || desc.contains('травм') || desc.contains('сбил') || desc.contains('люк')) {
      severity = 'Высокий (Критический риск)';
      scope = 'Городской / Районный масштаб';
      impact = 'Прямая угроза жизни, здоровью граждан или общественной безопасности';
      legal = '• ГОСТ Р 50597-2017: Открытые люки, провалы и опасные зоны на дорогах/тротуарах подлежат ограждению в течение 3 часов, устранению — до 24 часов.\n'
          '• Ст. 12.34 КоАП РФ: Несоблюдение требований по обеспечению безопасности дорожного движения (штраф для юрлиц до 300 000 руб.).\n'
          '• Ст. 216 УК РФ: Нарушение правил безопасности при ведении строительных/ремонтных работ.\n'
          '• Орган реагирования: ЕДДС г. Нижневартовска (тел. 112) и УМВД России по г. Нижневартовску.';
    } else if (cat.contains('жкх') || cat.contains('водоснабжение') || cat.contains('отопление') || cat.contains('электричество') ||
        desc.contains('нет воды') || desc.contains('нет отопления') || desc.contains('прорыв') ||
        desc.contains('затопило') || desc.contains('отключили') || desc.contains('подтопл')) {
      severity = 'Повышенный (Коммунальный сбой)';
      scope = 'Многоквартирный дом / Квартал';
      impact = 'Нарушение условий жизнедеятельности, риск порчи имущества жителей';
      legal = '• Постановление Правительства РФ № 354: Перерыв в подаче отопления зимой — не более 16 ч суммарно за месяц (при t воздуха в помещении +12..+18°C — не более 8 ч).\n'
          '• Ст. 161, 162 ЖК РФ: Обязанность управляющей организации обеспечить надлежащее содержание общедомового имущества.\n'
          '• Ст. 7.22 КоАП РФ: Нарушение правил содержания жилых домов (штраф на УК до 50 000 руб.).\n'
          '• Орган реагирования: Управляющая компания дома / Департамент ЖКХ Администрации г. Нижневартовска / Жилстройнадзор Югры.';
    } else if (cat.contains('дороги') || cat.contains('транспорт') ||
        desc.contains('яма') || desc.contains('асфальт') || desc.contains('светофор') ||
        desc.contains('дорог') || desc.contains('дтп') || desc.contains('авари') ||
        desc.contains('парков') || desc.contains('газон') || desc.contains('тротуар')) {
      if (desc.contains('парков') || desc.contains('газон') || desc.contains('тротуар')) {
        severity = 'Средний (Нарушение ПДД / Благоустройства)';
        scope = 'Дворовая территория / Тротуар';
        impact = 'Препятствие для пешеходов, спецтехники и разрушение зеленых зон';
        legal = '• Ч. 3 ст. 12.19 КоАП РФ: Остановка/стоянка транспортных средств на пешеходном переходе и тротуаре (штраф 1 000 руб. + задержание ТС на штрафстоянку).\n'
            '• Закон ХМАО - Югры № 102-оз (ст. 29.1): Размещение транспортных средств на газонах, цветниках и детских площадках (штраф до 5 000 руб.).\n'
            '• Орган реагирования: ОГИБДД УМВД России по г. Нижневартовску и Муниципальный контроль Администрации города.';
      } else {
        severity = 'Средний (Дорожный дефект)';
        scope = 'Проезжая часть / Улично-дорожная сеть';
        impact = 'Риск аварийных ситуаций и повреждения подвески транспортных средств';
        legal = '• ГОСТ Р 50597-2017: Предельные размеры выбоин на дорогах не более 15 см по длине, 60 см по ширине и 5 см по глубине. Срок устранения — от 1 до 3 суток.\n'
            '• Ст. 12 ФЗ № 196-ФЗ «О безопасности дорожного движения»: Обязанность дорожных служб содержать дороги в безопасном для движения состоянии.\n'
            '• Ст. 12.34 КоАП РФ: Штраф на должностных лиц до 30 000 руб., на юридических лиц — до 300 000 руб.\n'
            '• Орган реагирования: МКУ «Управление по дорожному хозяйству и благоустройству г. Нижневартовска» (УДХБ).';
      }
    } else if (cat.contains('экология') || cat.contains('мусор') || cat.contains('благоустройство') ||
        desc.contains('мусор') || desc.contains('свалка') || desc.contains('грязь') ||
        desc.contains('дерев') || desc.contains('сломал') || desc.contains('урн')) {
      severity = 'Умеренный (Экология / Благоустройство)';
      scope = 'Контейнерная площадка / Общественное пространство';
      impact = 'Нарушение санитарно-эпидемиологических норм, ухудшение городской среды';
      legal = '• СанПиН 2.1.3684-21: Вывоз твердых коммунальных отходов (ТКО) при среднесуточной температуре выше +5°C — ежедневно, при температуре +5°C и ниже — не реже 1 раза в 3 суток.\n'
          '• Ст. 8.2 КоАП РФ: Несоблюдение требований в области охраны окружающей среды при обращении с отходами (штраф для юрлиц до 250 000 руб.).\n'
          '• Правила благоустройства территории г. Нижневартовска (Решение Думы № 278).\n'
          '• Орган реагирования: Региональный оператор АО «Югра-Экология» / Департамент ЖКХ города Нижневартовска.';
    } else if (cat.contains('животные') || desc.contains('собак') || desc.contains('кот') || desc.contains('стая')) {
      severity = 'Умеренный (Безнадзорные животные)';
      scope = 'Двор / Микрорайон';
      impact = 'Риск агрессии безнадзорных животных либо необходимость помощи питомцам';
      legal = '• Федеральный закон № 498-ФЗ «Об ответственном обращении с животными» (ст. 18: программа ОСВВ, немедленный отлов агрессивных особей).\n'
          '• Закон ХМАО - Югры № 115-оз: Порядок организации мероприятий при осуществлении деятельности по обращению с животными без владельцев.\n'
          '• Орган реагирования: Муниципальная служба отлова г. Нижневартовска через ЕДДС 112.';
    }

    return {
      'severity': severity,
      'scope': scope,
      'impact': impact,
      'legal': legal,
    };
  }
}
