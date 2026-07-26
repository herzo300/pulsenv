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

      if (urls.isEmpty && (report['category'] == 'Животные' || report['category'] == 'вещи' || report['category'] == 'Вещи')) {
        final category = report['category']?.toString() ?? '';
        if (category == 'Животные') {
          final descText = (report['description'] ?? report['summary'] ?? '').toString().toLowerCase();
          final titleText = (report['title'] ?? '').toString().toLowerCase();
          final fullText = '$titleText $descText';
          if (fullText.contains('кош') || fullText.contains('кот') || fullText.contains('котенок')) {
            urls.add('https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=500'); // Cat
          } else if (fullText.contains('собак') || fullText.contains('пес') || fullText.contains('щенок') || fullText.contains('хаски')) {
            urls.add('https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500'); // Dog
          } else {
            urls.add('https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500'); // Default nice dog
          }
        }
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
    // e.g., "Фото: http..." or similar
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
      // Remove leading punctuation that was separating title from rest of text
      cleanDesc = cleanDesc.replaceFirst(RegExp(r'^[\.\,\-\s\:;!]+'), '').trim();
    }

    // If everything is stripped and we have nothing left, fallback to the cleaned original text
    if (cleanDesc.isEmpty) {
      String fallback = desc.trim();
      fallback = fallback.replaceFirst(RegExp(r'^[\.\,\-\s\:;!]+'), '').trim();
      cleanDesc = fallback;
    }

    // Keep description compact (max 180 chars) but cut cleanly at sentence/word boundary
    if (cleanDesc.length > 180) {
      final sub = cleanDesc.substring(0, 180);
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

  /// Automatically generates a brief situation analysis based on the category and description text.
  static Map<String, String> analyzeSituation(String? category, String? description) {
    final cat = (category ?? 'Прочее').toLowerCase();
    final desc = (description ?? '').toLowerCase();

    String severity = 'Низкий';
    String scope = 'Локальный';
    String impact = 'Информационный';
    String legal = 'Регулируется Федеральным законом № 59-ФЗ (срок ответа — до 30 дней, регистрация обращения — 3 дня).';

    if (cat.contains('чс') || cat.contains('пожар') || cat.contains('безопасность') ||
        desc.contains('пожар') || desc.contains('горит') || desc.contains('дым') ||
        desc.contains('взрыв') || desc.contains('драка') || desc.contains('полици') ||
        desc.contains('пострада') || desc.contains('травм') || desc.contains('сбил') || desc.contains('люк')) {
      severity = 'Высокий (Критический)';
      scope = 'Районный / Городской';
      impact = 'Угроза жизни, здоровью или общественному порядку';
      legal = '• Ст. 216 УК РФ (в случае травм из-за люков/котлованов).\n'
          '• ГОСТ Р 50597-2017: Опасные дорожные зоны должны ограждаться в течение 3 часов.';
    } else if (cat.contains('жкх') || cat.contains('водоснабжение') || cat.contains('отопление') || cat.contains('электричество') ||
        desc.contains('нет воды') || desc.contains('нет отопления') || desc.contains('прорыв') ||
        desc.contains('затопило') || desc.contains('отключили') || desc.contains('подтопл')) {
      severity = 'Средний';
      scope = 'Локальный (дом / квартал)';
      impact = 'Нарушение коммунальных услуг, риск повреждения имущества';
      legal = '• Постановление Правительства РФ № 354 от 06.05.2011: Отопление отключается не более 16 ч единовременно.\n'
          '• Закон ХМАО - Югры № 54-оз: Обязательства УК ЖКХ Нижневартовска за качество коммунальных услуг.';
    } else if (cat.contains('дороги') || cat.contains('транспорт') ||
        desc.contains('яма') || desc.contains('асфальт') || desc.contains('светофор') ||
        desc.contains('дорог') || desc.contains('дтп') || desc.contains('авари') ||
        desc.contains('пробк') || desc.contains('автобус')) {
      severity = 'Средний';
      scope = 'Локальный (улица / перекресток)';
      impact = 'Ограничение движения транспорта, риск ДТП';
      legal = '• ГОСТ Р 50597-2017: Выбоины не должны превышать 15х60х5 см. Срок ремонта — до 12 суток.\n'
          '• Закон ХМАО - Югры № 102-оз: Обязанности дорожных служб по обеспечению безопасности движения в округе.';
    } else if (cat.contains('экология') || cat.contains('мусор') || cat.contains('благоустройство') ||
        desc.contains('мусор') || desc.contains('свалка') || desc.contains('грязь') ||
        desc.contains('дерев') || desc.contains('сломал')) {
      severity = 'Низкий';
      scope = 'Локальный';
      impact = 'Эстетические неудобства, ухудшение экологии';
      legal = '• СанПиН 2.1.3684-21: Вывоз мусора при температуре выше +5 °C осуществляется ежедневно.\n'
          '• Закон ХМАО - Югры № 3-оз (об охране среды) и Правила благоустройства г. Нижневартовска (Решение № 278).';
    } else if (cat.contains('животные') || desc.contains('собак') || desc.contains('кот') || desc.contains('пропал')) {
      severity = 'Низкий';
      scope = 'Локальный';
      impact = 'Социальный / Помощь животным';
      legal = '• Федеральный закон № 498-ФЗ: Нормы ОСВВ и ответственного обращения.\n'
          '• Закон ХМАО - Югры № 115-оз: Порядок содержания и отлова домашних животных в Югре.';
    }

    return {
      'severity': severity,
      'scope': scope,
      'impact': impact,
      'legal': legal,
    };
  }
}
