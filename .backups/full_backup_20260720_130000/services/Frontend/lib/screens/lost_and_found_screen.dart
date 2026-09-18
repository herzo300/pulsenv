// services/Frontend/lib/screens/lost_and_found_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../services/backend_api_service.dart';
import '../services/app_state_service.dart';
import '../theme/theme_provider.dart';
import '../services/sound_service.dart';

import '../core/app_router.dart';
import '../map/map_config.dart';
import '../theme/pulse_colors.dart';
import '../theme/pulse_categories.dart';
import '../widgets/app_ui.dart';
import '../widgets/dynamic_animated_background.dart';
import '../widgets/aura_living_background.dart';
import '../core/living/aura_living_engine.dart';
import '../core/living/aura_circadian.dart';
import '../core/living/aura_theme_service.dart';
import '../widgets/aura_theme_picker.dart';
import '../widgets/category_icon_3d.dart';
import 'package:camera/camera.dart';
import '../utils/situation_helper.dart';
import 'package:rive/rive.dart' as rive;
import '../services/city_provider.dart';
import 'lost_and_found/widgets/add_finding_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/premium/index.dart';

class LostAndFoundScreen extends StatefulWidget {
  const LostAndFoundScreen({super.key});

  @override
  State<LostAndFoundScreen> createState() => _LostAndFoundScreenState();
}

/// Отображение фото находки с поддержкой http(s) и локальных file:// путей.
/// Использует CachedNetworkImage (с кэшем + placeholder) для URL и
/// Image.file для локальных фото из offline-формы.
class FindingImage extends StatelessWidget {
  const FindingImage({
    super.key,
    required this.url,
    required this.placeholder,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  final String url;
  final Widget placeholder;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    var finalUrl = url.trim();
    
    // Auto-resolve relative paths if they somehow slipped through
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://') && !finalUrl.startsWith('file://')) {
      finalUrl = SituationHelper.resolveImageUrl(finalUrl);
    }

    // Local photo (file:// from offline lost & found form)
    if (finalUrl.startsWith('file://')) {
      final path = finalUrl.replaceFirst('file://', '');
      return Image.file(
        File(path),
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            SizedBox(height: height, width: width, child: placeholder),
      );
    }

    // Network photo - reliable rendering withCachedNetworkImage and fallback
    return CachedNetworkImage(
      imageUrl: finalUrl,
      height: height,
      width: width,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => SizedBox(height: height, width: width, child: placeholder),
      errorWidget: (_, __, ___) => SizedBox(height: height, width: width, child: placeholder),
    );
  }
}

class _LostAndFoundScreenState extends State<LostAndFoundScreen> {
  static const String _complaintsCachePrefKey = 'my_lost_and_found_items'; // Align with local cache key
  
  List<Map<String, dynamic>> _allItems = [];

  String _getPlaceholderImageFor(String category, String title, String description, [String? id]) {
    final seed = ((id ?? title).hashCode.abs()) % 1000 + 1;
    final text = '$title $description'.toLowerCase();
    
    if (category.toLowerCase().contains('животн')) {
      if (text.contains('кот') || text.contains('кошк') || text.contains('котенок') || text.contains('кис')) {
        final catSeeds = [
          'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=600',
          'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=600',
          'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?w=600',
          'https://images.unsplash.com/photo-1495360010541-f48722b34f7d?w=600',
          'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=600',
        ];
        return catSeeds[seed % catSeeds.length];
      } else if (text.contains('собак') || text.contains('пес') || text.contains('щенок') || text.contains('хаски') || text.contains('пёс')) {
        final dogSeeds = [
          'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=600',
          'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=600',
          'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=600',
          'https://images.unsplash.com/photo-1561037404-61cd46aa615b?w=600',
          'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=600',
        ];
        return dogSeeds[seed % dogSeeds.length];
      }
      return 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=600';
    } else {
      if (text.contains('ключ')) {
        return 'https://images.unsplash.com/photo-1582139329536-e7284fece509?w=600';
      } else if (text.contains('телеф') || text.contains('iphone') || text.contains('айфон') || text.contains('смартф')) {
        return 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=600';
      } else if (text.contains('кошел') || text.contains('бумажн') || text.contains('портмоне') || text.contains('карт')) {
        return 'https://images.unsplash.com/photo-1627163430004-6f85022f67b4?w=600';
      } else if (text.contains('рюкзак') || text.contains('сумк') || text.contains('портфе')) {
        return 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=600';
      } else if (text.contains('документ') || text.contains('паспорт') || text.contains('прав')) {
        return 'https://images.unsplash.com/photo-1506784983877-45594efa4cbe?w=600';
      }
      final encodedTitle = Uri.encodeComponent('$title $category');
      return 'https://image.pollinations.ai/prompt/$encodedTitle?width=600&height=400&seed=$seed&nologo=true';
    }
  }
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = false;
  String _searchQuery = '';
  int _currentPageIndex = 0; // 0 = Животные, 1 = Вещи
  bool _isGridView = false;

  late PageController _pageController;
  late PageController _moviePageController;
  double _moviePageViewOffset = 0.0;

  late PageController _animalsPageController;
  double _animalsPageViewOffset = 0.0;
  late PageController _thingsPageController;
  double _thingsPageViewOffset = 0.0;
  List<Map<String, dynamic>> _filteredAnimals = [];
  List<Map<String, dynamic>> _filteredThings = [];

  final List<Map<String, dynamic>> _movies = const [
    {
      'id': 'm1',
      'title': 'Свет Самотлора',
      'genre': 'Научная фантастика / Драма',
      'duration': '142 мин',
      'description': 'В недалеком будущем на Самотлорском месторождении совершается открытие, способное изменить энергетический баланс планеты.',
      'image': 'assets/poster_samotlor.png',
      'rating': '8.9',
      'schedule': {
        'nizhnevartovsk': ['12:30', '15:45', '19:00', '21:30'],
        'novosibirsk': ['14:00', '17:30', '20:00', '22:40'],
      },
      'cinemas': {
        'nizhnevartovsk': 'Кинотеатр «Мир» / «Югра-Cinema»',
        'novosibirsk': 'Кинотеатр «Победа» / «Синема Парк»',
      }
    },
    {
      'id': 'm2',
      'title': 'Тайга: Затерянный мир',
      'genre': 'Приключения / Триллер',
      'duration': '118 мин',
      'description': 'Группа исследователей отправляется вглубь непроходимой сибирской тайги на поиски артефакта, но сталкивается с древней силой природы.',
      'image': 'assets/poster_taiga.png',
      'rating': '8.2',
      'schedule': {
        'nizhnevartovsk': ['10:00', '14:20', '18:10', '20:30'],
        'novosibirsk': ['11:30', '15:10', '19:20', '21:50'],
      },
      'cinemas': {
        'nizhnevartovsk': 'Кинотеатр «Galaxy»',
        'novosibirsk': 'Кинотеатр «Аура» / «Каро»',
      }
    }
  ];

  late ConfettiController _confettiController;
  List<String> _myReportedIds = [];
  List<String> _myResolvedIds = [];

  int _totalThisMonth = 0;
  int _resolvedThisMonth = 0;
  double _successRate = 0.0;

  // ── Daily Fun AI Content ──────────────────────────────────────────
  List<Map<String, dynamic>> _dailyFunItems = [];
  bool _isDailyFunLoading = false;
  String _dailyFunType = 'all'; // all | theatre | event | movie
  String _dailyFunDate = '';

  @override
  void initState() {
    super.initState();
    SoundService().playLostFound();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _pageController = PageController(initialPage: 0);
    _moviePageController = PageController(viewportFraction: 0.76, initialPage: 0);
    _moviePageController.addListener(() {
      if (mounted) {
        setState(() {
          _moviePageViewOffset = _moviePageController.page ?? 0.0;
        });
      }
    });
    _animalsPageController = PageController(viewportFraction: 0.78, initialPage: 0);
    _animalsPageController.addListener(() {
      if (mounted) {
        setState(() {
          _animalsPageViewOffset = _animalsPageController.page ?? 0.0;
        });
      }
    });
    _thingsPageController = PageController(viewportFraction: 0.78, initialPage: 0);
    _thingsPageController.addListener(() {
      if (mounted) {
        setState(() {
          _thingsPageViewOffset = _thingsPageController.page ?? 0.0;
        });
      }
    });
    _loadData();
    _loadDailyFun();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pageController.dispose();
    _moviePageController.dispose();
    _animalsPageController.dispose();
    _thingsPageController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _myLocalItems = [];

  Future<void> _loadDailyFun() async {
    if (_isDailyFunLoading) return;
    setState(() => _isDailyFunLoading = true);
    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/daily-fun');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        if (mounted) {
          setState(() {
            _dailyFunItems = items;
            _dailyFunDate = data['date']?.toString() ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Daily fun load error: $e');
    } finally {
      if (mounted) setState(() => _isDailyFunLoading = false);
    }
  }

  Future<void> _loadUserReportedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _myReportedIds = prefs.getStringList('my_reported_ids') ?? [];
      _myResolvedIds = prefs.getStringList('my_resolved_ids') ?? [];
      
      final localRaw = prefs.getString('my_lost_and_found_items') ?? '[]';
      final List<dynamic> decoded = jsonDecode(localRaw);
      _myLocalItems = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadUserReportedIds();
    
    // 1. Try to load from local cache first for instant display
    await _loadFromCache();
    
    // 2. Fetch fresh data from network
    await _fetchFromNetwork();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_complaintsCachePrefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final items = decoded.whereType<Map>().map((item) {
            return Map<String, dynamic>.from(item);
          }).toList();
          _processRawItems(items);
        }
      }
    } catch (e) {
      debugPrint('Error reading lost & found cache: $e');
    }
  }

  Future<void> _fetchFromNetwork() async {
    final cityParam = CityProvider().activeCity.backendCityParam;
    final apiUrl = '${MapConfig.backendApiBaseUrl}/map/feed?limit=400&refresh=true&city=$cityParam';
    try {
      final res = await http.get(Uri.parse(apiUrl), headers: {
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final payload = jsonDecode(utf8.decode(res.bodyBytes));
        final markers = payload is Map<String, dynamic>
            ? (payload['markers'] as List<dynamic>? ?? const <dynamic>[])
            : const <dynamic>[];
        final items = markers.whereType<Map>().map((item) {
          return Map<String, dynamic>.from(item);
        }).toList();
        
        // Save to cache as well
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_complaintsCachePrefKey, jsonEncode(items));
        
        _processRawItems(items);
      }
    } catch (e) {
      debugPrint('Error fetching lost & found from network: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _extractLocationSnippet(String title, String desc) {
    final text = '$title. $desc';
    
    // 1. Поиск перекрестков: "перекресток Ленина и Мира", "угол Ленина / Мира", "пересечение Ленина и Чапаева"
    final intersectionRegex = RegExp(
      r'((?:перекрест(?:ок|ка|ке|ком|ков)|пересечен(?:ие|ии|ием|ий)|уг(?:ол|лу|ла|лом))\s+(?:ул\.\s*)?[а-яА-ЯёЁ0-9\-]+(?:\s+(?:ул\.\s*)?[а-яА-ЯёЁ0-9\-]+)*(?:\s+(?:и|/)\s+(?:ул\.\s*)?[а-яА-ЯёЁ0-9\-]+)+)',
      caseSensitive: false,
    );
    final intersectionMatch = intersectionRegex.firstMatch(text);
    if (intersectionMatch != null) {
      return _capitalize(intersectionMatch.group(0)!.trim());
    }
    // 2. Поиск известных сетей с предлогами: "около Магнита", "в Пятерочке", "рядом с Лентой", "возле ТЦ Югра"
    final knownBrandsWithPrep = RegExp(
      r'((?:около|возле|рядом\s+с|у|в|напротив)\s+(?:магазин[а-я]*\s+|ТЦ\s+|ТРЦ\s+)?(?:Магнит[а-я]*|Пятерочк[а-я]*|Монетк[а-я]*|Лент[а-я]*|Красн[а-я]*\s+и\s+Бел[а-я]*|К&Б|КБ|Югр[а-я]*|Гринпарк[a-я]*|Спар[а-я]*|Spar))',
      caseSensitive: false,
    );
    final brandMatch = knownBrandsWithPrep.firstMatch(text);
    if (brandMatch != null) {
      return _capitalize(brandMatch.group(0)!.trim());
    }

    // 3. Поиск магазинов/ТЦ/остановок: "магазин Магнит", "ТЦ Югра", "ТРЦ Премьер", "остановка Мира"
    final shopRegex = RegExp(
      r'((?:магазин[а-я]*|ТЦ|ТРЦ|супермаркет[а-я]*|гипермаркет[а-я]*|остановк[а-я]*|Торгов[а-я]*\s+центр[а-я]*)\s+(?:«[^»]+»|"[^"]+"|[a-zA-Zа-яА-ЯёЁ0-9\-]+))',
      caseSensitive: false,
    );
    final shopMatch = shopRegex.firstMatch(text);
    if (shopMatch != null) {
      return _capitalize(shopMatch.group(0)!.trim());
    }

    // 4. Поиск просто упоминания известной сети
    final standaloneBrand = RegExp(
      r'\b(Магнит|Пятерочка|Монетка|Лента|Красное\s+и\s+Белое|КБ|Югра|Гринпарк|Спар|Spar)\b',
      caseSensitive: false,
    );
    final standaloneMatch = standaloneBrand.firstMatch(text);
    if (standaloneMatch != null) {
      return 'Ориентир: ${standaloneMatch.group(0)}';
    }

    return null;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  List<Map<String, dynamic>> _getFallbackLostAndFoundItems(String city) {
    final bool isNsk = city == 'novosibirsk';
    return [
      {
        'id': 'fallback_lf_1',
        'title': 'Найден кобель Хаски',
        'description': 'В районе улицы ${isNsk ? 'Красный проспект 184' : 'Ленина 15'} бегает молодой кобель хаски в брезентовом ошейнике. Очень ласковый, знает команды, явно домашний. Ищем старых или новых хозяев.',
        'category': 'Найдено животное',
        'address': isNsk ? 'Красный проспект, 184' : 'улица Ленина, 15',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'status': 'open',
        'image': 'https://images.unsplash.com/photo-1531804055935-76f44d7c3621?auto=format&fit=crop&q=80&w=400',
      },
      {
        'id': 'fallback_lf_2',
        'title': 'Найдены ключи от автомобиля',
        'description': 'На детской площадке во дворе дома по адресу ${isNsk ? 'ул. Сибиряков-Гвардейцев 26' : 'ул. Чапаева 5'} найдены ключи от машины Toyota с брелоком Scher-Khan. Верну владельцу при подтверждении.',
        'category': 'Найдена вещь',
        'address': isNsk ? 'ул. Сибиряков-Gвардейцев, 26' : 'улица Чапаева, 5',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'status': 'open',
        'image': 'https://images.unsplash.com/photo-1582139329536-e7284fece509?auto=format&fit=crop&q=80&w=400',
      },
      {
        'id': 'fallback_lf_3',
        'title': 'Рыжий кот в подъезде',
        'description': 'В подъезде дома по ${isNsk ? 'ул. Бориса Богаткова 194' : 'ул. Мира 38'} со вчерашнего дня сидит упитанный рыжий кот, явно домашний, очень испуган. Хозяева, отзовитесь!',
        'category': 'Найдено животное',
        'address': isNsk ? 'ул. Бориса Богаткова, 194' : 'улица Мира, 38',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'status': 'open',
        'image': 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&q=80&w=400',
      },
      {
        'id': 'fallback_lf_4',
        'title': 'Найден телефон iPhone 12',
        'description': 'Возле центрального входа в ${isNsk ? 'ТЦ Аура' : 'ТРЦ Премьер'} найден телефон iPhone 12 в черном силиконовом чехле. Экран заблокирован. Верну по описанию обоев на экране.',
        'category': 'Найдена вещь',
        'address': isNsk ? 'Военная ул., 5' : 'ул. Ленина, 11',
        'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        'status': 'open',
        'image': 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?auto=format&fit=crop&q=80&w=400',
      },
      {
        'id': 'fallback_lf_5',
        'title': 'Пропала собака Шпиц',
        'description': 'В районе ${isNsk ? 'Центрального парка' : 'ТЦ Югра'} убежал маленький белый шпиц (кобель), отзывается на кличку Пушок. Был без ошейника. Просьба вернуть за вознаграждение!',
        'category': 'Найдено животное',
        'address': isNsk ? 'Мичурина, 8' : 'Интернациональная улица, 12',
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'status': 'open',
        'image': 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&q=80&w=400',
      },
      {
        'id': 'fallback_lf_6',
        'title': 'Найден кошелек с картами',
        'description': 'На лавочке возле ${isNsk ? 'Метро Площадь Ленина' : 'ул. Интернациональная 12'} найден черный кожаный кошелек. Внутри банковские карты на имя Aleksandr S. и немного наличных. Верну при предъявлении паспорта.',
        'category': 'Найдена вещь',
        'address': isNsk ? 'Красный проспект, 25' : 'Интернациональная улица, 12',
        'created_at': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(),
        'status': 'open',
        'image': 'https://images.unsplash.com/photo-1627163430004-6f85022f67b4?auto=format&fit=crop&q=80&w=400',
      },
    ];
  }

  void _processRawItems(List<Map<String, dynamic>> items) {
    final merged = List<Map<String, dynamic>>.from(items);
    
    final activeCity = CityProvider().activeCity.backendCityParam;
    final fallbacks = _getFallbackLostAndFoundItems(activeCity);
    for (final fb in fallbacks) {
      if (!merged.any((e) => e['id']?.toString() == fb['id'])) {
        merged.add(fb);
      }
    }

    final existingIds = merged.map((e) => e['id']?.toString()).toSet();
    
    for (final local in _myLocalItems) {
      final localId = local['id']?.toString();
      if (localId != null && !existingIds.contains(localId)) {
        merged.insert(0, local);
      }
    }

    final filtered = merged.where((item) {
      final address = item['address']?.toString() ?? '';
      final title = item['title']?.toString() ?? '';
      final desc = item['description']?.toString() ?? '';
      final String originalCategory = item['category']?.toString() ?? '';
      var category = originalCategory;
      final text = (title + ' ' + desc).toLowerCase();

      bool isFound = false;
      bool isLost = false;

      final lostTriggers = ['потерял', 'потерян', 'пропал', 'утерян', 'убежал', 'ищем', 'разыскива'];
      final foundTriggers = ['найден', 'нашли', 'нашел', 'нашла', 'прибился', 'замечен', 'лежит', 'сидит'];

      final hasLostWord = lostTriggers.any((w) => text.contains(w));
      final hasFoundWord = foundTriggers.any((w) => text.contains(w));

      bool _hasWord(String haystack, String word) {
        return RegExp('(^|[\\s,.;:!?()\\[\\]"\'/\\-])' + RegExp.escape(word), caseSensitive: false).hasMatch(haystack);
      }
      final isAnimal = category.toLowerCase().contains('животн') ||
                       category.toLowerCase().contains('animal') ||
                       _hasWord(text, 'собак') ||
                       _hasWord(text, 'кошк') ||
                       _hasWord(text, 'котик') ||
                       _hasWord(text, 'котён') ||
                       _hasWord(text, 'кот ') ||
                       _hasWord(text, 'кота ') ||
                       _hasWord(text, 'коту ') ||
                       _hasWord(text, 'котом') ||
                       _hasWord(text, 'пёс') ||
                       _hasWord(text, 'пёсик') ||
                       _hasWord(text, 'щенок') ||
                       _hasWord(text, 'щенк') ||
                       _hasWord(text, 'хомяк') ||
                       _hasWord(text, 'попугай') ||
                       _hasWord(text, 'черепах');

      final isThing = category.toLowerCase().contains('вещ') ||
                      category.toLowerCase().contains('thing') ||
                      _hasWord(text, 'ключ') ||
                      _hasWord(text, 'телефон') ||
                      _hasWord(text, 'документ') ||
                      _hasWord(text, 'кошелек') ||
                      _hasWord(text, 'кошелёк') ||
                      _hasWord(text, 'сумк') ||
                      _hasWord(text, 'очки') ||
                      _hasWord(text, 'паспорт');

      if (hasFoundWord && (isAnimal || isThing || category == 'Бюро находок' || category.contains('Найдено') || category.contains('Найдена'))) {
        isFound = true;
      } else if (hasLostWord && (isAnimal || isThing)) {
        isLost = true;
      }

      if (category == 'Найдено животное' || category == 'Найдена вещь' || category == 'Бюро находок') {
        isFound = true;
      } else if (category == 'Потеряно животное' || category == 'Потеряна вещь') {
        isLost = true;
      }

      if (isFound) {
        final finalCat = isAnimal ? 'Найдено животное' : 'Найдена вещь';
        category = finalCat;
        item['category'] = finalCat;
      } else if (isLost) {
        final finalCat = isAnimal ? 'Животные' : 'Вещи';
        category = finalCat;
        item['category'] = finalCat;
      }

      // Strict check: must be either animal or thing, otherwise exclude from lost & found
      if (!isAnimal && !isThing) {
        return false;
      }

      // Применяем локальный статус "решено"
      final idStr = item['id']?.toString() ?? '';
      if (_myResolvedIds.contains(idStr)) {
        item['status'] = 'resolved';
      }

      String displayAddress = address.trim();
      if (displayAddress.isEmpty) {
        final derived = _extractLocationSnippet(title, desc);
        if (derived != null) {
          item['_derivedAddress'] = derived;
          displayAddress = derived;
        }
      }

      // Если адрес все еще пустой, отфильтровываем
      if (displayAddress.isEmpty) return false;

      // Exclude standard municipal signals from Lost & Found
      final excludedCats = [
        'ЖКХ', 'Дороги', 'Благоустройство', 'Транспорт', 'Безопасность',
        'Экология', 'Мероприятие', 'Камеры', 'Здравоохранение', 'Образование',
        'Освещение', 'Парковки', 'Мусор', 'Дворы', 'Детские', 'Ремонт',
        'Яма', 'Светофор', 'Канализация', 'Отопление', 'Вода', 'Газ',
        'Электричество', 'Лифт', 'Подъезд', 'Фасад', 'Крыш',
        'Строительство', 'Шум', 'Реклам', 'Незаконн', 'Свалк',
        'Граффити', 'Вандал', 'Тариф', 'Управляющ', 'УК',
      ];
      if (excludedCats.any((ec) => originalCategory.toLowerCase().contains(ec.toLowerCase()))) return false;
      
      // Exclude general stray animal reports or municipal issues
      final complaintTriggers = [
        'отлов', 'стая', 'стаи', 'кусает', 'покусан', 'агрессив', 'чипиров', 'бегают', 'подрядчик', 'заявка',
        'жалоба', 'устранить', 'мусор', 'свалка', 'подтоплен', 'яма', 'дорог', 'тротуар', 'ук', 'жкх', 'протеч'
      ];
      if (complaintTriggers.any((w) => text.contains(w))) {
        return false;
      }

      return isFound || isLost;
    }).toList();

    if (mounted) {
      setState(() {
        _allItems = filtered;
        _calculateMonthlyStats();
        _applyFilters();
      });
    }
  }

  void _calculateMonthlyStats() {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    int total = 0;
    int resolved = 0;

    for (final item in _allItems) {
      final category = item['category']?.toString() ?? '';
      final lowerCat = category.toLowerCase();
      final isLostOrFound = lowerCat.contains('найден') || lowerCat.contains('находк');
      if (!isLostOrFound) continue;

      DateTime? createdAt;
      final rawCreated = item['created_at'] ?? item['createdAt'];
      if (rawCreated != null) {
        createdAt = DateTime.tryParse(rawCreated.toString());
      }

      if (createdAt == null || createdAt.isAfter(thirtyDaysAgo)) {
        total++;
        final status = item['status']?.toString().toLowerCase() ?? '';
        if (status == 'resolved' || status == 'решена') {
          resolved++;
        }
      }
    }

    _totalThisMonth = total;
    _resolvedThisMonth = resolved;
    _successRate = total > 0 ? (resolved / total) : 0.0;
  }

  Widget _buildMonthlyStatsCard() {
    if (_totalThisMonth == 0) return const SizedBox.shrink();
    
    final percentage = (_successRate * 100).round();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          borderRadius: AppRadii.md,
          gradient: LinearGradient(
            colors: [
              PulseColors.primary.withOpacity(0.3),
              Colors.purpleAccent.withOpacity(0.2),
              Colors.cyanAccent.withOpacity(0.2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: PulseColors.primary.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: -2,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadii.md,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              children: [
                // Circular progress indicator
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _successRate,
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                        strokeWidth: 4.5,
                      ),
                      Text(
                        '$percentage%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'СТАТИСТИКА ЗА 30 ДНЕЙ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Найдено животных и вещей: $_resolvedThisMonth из $_totalThisMonth потеряшек',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
       .shimmer(duration: 3.seconds, color: Colors.white24),
    );
  }

  Future<void> _toggleReportStatus(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    
    final idStr = id.toString();
    
    // 1. Вибрация и Конфетти
    HapticFeedback.heavyImpact();
    _confettiController.play();
    
    // 2. Обновление локального состояния
    setState(() {
      if (!_myResolvedIds.contains(idStr)) {
        _myResolvedIds.add(idStr);
      }
      item['status'] = 'resolved';
      _calculateMonthlyStats();
    });

    // 3. Сохранение локальных идентификаторов
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('my_resolved_ids', _myResolvedIds);
      
      // Обновляем кэш объявлений
      await prefs.setString(_complaintsCachePrefKey, jsonEncode(_allItems));
    } catch (e) {
      debugPrint('Error saving local resolved status: $e');
    }

    // 4. Отправка PATCH-запроса на сервер
    final apiUrl = '${MapConfig.reportsApiUrl}?id=eq.$idStr';
    try {
      final body = {'status': 'resolved'};
      await http.patch(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error patching report status to server: $e');
    }
  }

  void _applyFilters() {
    final animalItems = _allItems.where((item) => (item['category']?.toString() ?? '').toLowerCase().contains('животн')).toList();
    final thingItems = _allItems.where((item) => (item['category']?.toString() ?? '').toLowerCase().contains('вещ')).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      _filteredAnimals = animalItems.where((item) {
        final title = item['title']?.toString().toLowerCase() ?? '';
        final desc = item['description']?.toString().toLowerCase() ?? '';
        final address = (item['_derivedAddress'] ?? item['address'])?.toString().toLowerCase() ?? '';
        return title.contains(q) || desc.contains(q) || address.contains(q);
      }).toList();

      _filteredThings = thingItems.where((item) {
        final title = item['title']?.toString().toLowerCase() ?? '';
        final desc = item['description']?.toString().toLowerCase() ?? '';
        final address = (item['_derivedAddress'] ?? item['address'])?.toString().toLowerCase() ?? '';
        return title.contains(q) || desc.contains(q) || address.contains(q);
      }).toList();
    } else {
      _filteredAnimals = animalItems;
      _filteredThings = thingItems;
    }

    setState(() {});
  }

  void _showMovieDetails(BuildContext context, Map<String, dynamic> movie) {
    // Filter movies if search query is not empty
    var filteredMovies = _movies;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredMovies = _movies.where((m) {
        final title = m['title']?.toString().toLowerCase() ?? '';
        final genre = m['genre']?.toString().toLowerCase() ?? '';
        final desc = m['description']?.toString().toLowerCase() ?? '';
        return title.contains(q) || genre.contains(q) || desc.contains(q);
      }).toList();
    }
    
    final initialIndex = filteredMovies.indexWhere((x) => x['id'] == movie['id']).clamp(0, filteredMovies.length - 1);
    final PageController dialogPageController = PageController(initialPage: initialIndex);
    
    final activeCity = CityProvider().activeCity.backendCityParam;
    final cityKey = activeCity == 'novosibirsk' ? 'novosibirsk' : 'nizhnevartovsk';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.78,
            child: PageView.builder(
              controller: dialogPageController,
              itemCount: filteredMovies.length,
              itemBuilder: (context, idx) {
                final curMovie = filteredMovies[idx];
                final title = curMovie['title'] as String;
                final genre = curMovie['genre'] as String;
                final duration = curMovie['duration'] as String;
                final rating = curMovie['rating'] as String;
                final description = curMovie['description'] as String;
                final image = curMovie['image'] as String;
                final cinemas = (curMovie['cinemas'] as Map)[cityKey] as String;
                final schedule = (curMovie['schedule'] as Map)[cityKey] as List;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: PulseColors.background,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: PulseColors.primary.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: PulseColors.primary.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              Image.asset(
                                image,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: PulseColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: PulseColors.primary.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        genre.toUpperCase(),
                                        style: TextStyle(
                                          color: PulseColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$rating/10 ИИ',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: PulseColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Продолжительность: $duration',
                                  style: TextStyle(
                                    color: PulseColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Divider(color: PulseColors.border, height: 24),
                                const Text(
                                  'СЮЖЕТ ФИЛЬМА',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: PulseColors.textPrimary.withOpacity(0.85),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                Divider(color: PulseColors.border, height: 24),
                                Row(
                                  children: [
                                    Icon(Icons.videocam_outlined, color: PulseColors.primary, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        cinemas,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'СЕАНСЫ НА СЕГОДНЯ',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: schedule.map((time) {
                                    return InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Билет на сеанс $time забронирован!'),
                                            backgroundColor: PulseColors.primaryDeep,
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: PulseColors.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: PulseColors.border),
                                        ),
                                        child: Text(
                                          time.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showItemDetails(BuildContext context, Map<String, dynamic> item, List<Map<String, dynamic>> items) {
    final initialIndex = items.indexWhere((x) => x['id'] == item['id']).clamp(0, items.length - 1);
    final PageController dialogPageController = PageController(initialPage: initialIndex);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.78,
            child: PageView.builder(
              controller: dialogPageController,
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final curItem = items[idx];
                final title = curItem['title'] ?? 'Объявление';
                final desc = curItem['description'] ?? 'Нет описания';
                final category = curItem['category'] ?? 'Прочее';
                final address = (curItem['_derivedAddress'] ?? curItem['address'])?.toString() ?? CityProvider().activeCity.name;
                final rawImages = SituationHelper.extractImageUrls(curItem);
                final images = rawImages.isNotEmpty ? rawImages : [_getPlaceholderImageFor(category, title, desc, item['id']?.toString())];
                final cleanDesc = SituationHelper.cleanDescription(desc, title);
                final color = PulseCategories.colorFor(category);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: PulseColors.background,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              Hero(
                                tag: 'lost_found_img_${curItem['id']}',
                                child: Material(
                                  color: Colors.transparent,
                                  child: images.isNotEmpty
                                      ? FindingImage(
                                          url: images.first,
                                          height: 220,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder:
                                              _buildPosterPlaceholder(category, color),
                                        )
                                      : SizedBox(
                                          height: 220,
                                          width: double.infinity,
                                          child: _buildPosterPlaceholder(category, color),
                                        ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: color.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        category.toUpperCase(),
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: category.contains('Найдено')
                                            ? const Color(0xFF00FF88).withOpacity(0.15)
                                            : const Color(0xFFFF3366).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: category.contains('Найдено')
                                              ? const Color(0xFF00FF88)
                                              : const Color(0xFFFF3366),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        category.contains('Найдено') ? '✅ НАЙДЕНО' : '🚨 В РОЗЫСКЕ',
                                        style: TextStyle(
                                          color: category.contains('Найдено')
                                              ? const Color(0xFF00FF88)
                                              : const Color(0xFFFF3366),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: PulseColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, color: color, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: TextStyle(
                                          color: PulseColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(color: PulseColors.border, height: 24),
                                Text(
                                  cleanDesc,
                                  style: TextStyle(
                                    color: PulseColors.textPrimary.withOpacity(0.85),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                Divider(color: PulseColors.border, height: 24),
                                Row(
                                  children: [
                                    Icon(Icons.contact_phone_rounded, color: color, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Контакты:',
                                      style: TextStyle(
                                        color: PulseColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Автор объявления: ${curItem['user_name'] ?? 'Житель города'}',
                                  style: TextStyle(color: PulseColors.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    final rawPhone = curItem['phone'] ?? curItem['user_phone'] ?? '+7 (3466) 29-12-34';
                                    launchUrl(Uri.parse('tel:${rawPhone.toString().trim()}'));
                                  },
                                  child: Text(
                                    'Телефон: ${curItem['phone'] ?? curItem['user_phone'] ?? '+7 (3466) 29-12-34'}',
                                    style: TextStyle(
                                      color: PulseColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => context.canPop() ? context.pop() : context.go('/map'),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Бюро находок'.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: PulseColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: PulseColors.primary.withAlpha(200),
                              blurRadius: 4,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        CityProvider().activeCity.name.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                // Кнопка выбора премиум-темы фона AuraLiving
                IconButton(
                  icon: const Icon(Icons.palette_rounded, color: Colors.white, size: 24),
                  tooltip: 'Тема фона',
                  onPressed: () => AuraThemePicker.show(context),
                ),
                IconButton(
                  icon: Icon(
                    _isGridView ? Icons.view_carousel_rounded : Icons.grid_view_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  tooltip: _isGridView ? 'Карусель' : 'Сетка',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
              ],
              backgroundColor: Colors.black.withOpacity(0.2),
              elevation: 0,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await AddFindingSheet.show(
            context,
            initialCity: CityProvider().activeCity.name,
          );
          // После сохранения — перечитать локальные записи и обновить список.
          if (saved == true) {
            await _loadUserReportedIds();
            _processRawItems(List<Map<String, dynamic>>.from(_allItems));
            setState(() {});
          }
        },
        backgroundColor: PulseColors.primary,
        foregroundColor: PulseColors.background,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Сообщить'),
      ),
      body: ListenableBuilder(
        listenable: AuraThemeService.instance,
        builder: (context, _) {
          final currentTheme = AuraThemeService.instance.theme;
          final isDark = ThemeProvider.instance.isDarkMode;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: AuraLivingBackground(
              key: ValueKey('aura_bg_${currentTheme.id}'),
              scene: currentTheme.toScene(),
              showSignatureObject: false,
              showConstellationVeil: false,
              interactive: true,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                color: isDark ? const Color(0xFF0B071B).withOpacity(0.18) : Colors.white.withOpacity(0.24),
                child: SafeArea(
                child: Stack(
                  children: [
                Column(
                  children: [
                    _buildFilterHeader(),
                    _buildMonthlyStatsCard(),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (pageIndex) {
                          setState(() {
                            _currentPageIndex = pageIndex;
                            _applyFilters();
                          });
                        },
                        children: [
                          // Вкладка 1: Животные
                          PulseRefresher(
                            onRefresh: _fetchFromNetwork,
                            style: PulseRefreshStyle.bezier,
                            child: _buildContent(_filteredAnimals, _animalsPageController, _animalsPageViewOffset),
                          ),
                          // Вкладка 2: Вещи
                          PulseRefresher(
                            onRefresh: _fetchFromNetwork,
                            style: PulseRefreshStyle.bezier,
                            child: _buildContent(_filteredThings, _thingsPageController, _thingsPageViewOffset),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [
                      Colors.greenAccent,
                      Colors.blueAccent,
                      Colors.pinkAccent,
                      Colors.yellowAccent,
                      Colors.purpleAccent,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  },
),
);
}

  Widget _buildFilterHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Column(
        children: [
          // Search input field with premium glass design
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    final isDark = ThemeProvider.instance.isDarkMode;
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                        ),
                      ),
                      child: TextField(
                        onChanged: (val) {
                          _searchQuery = val;
                          _applyFilters();
                        },
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Поиск вещей и животных...',
                          hintStyle: TextStyle(color: isDark ? Colors.white.withOpacity(0.4) : Colors.black38),
                          prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white.withOpacity(0.6) : Colors.black54),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    );
                  }
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _showAiCrossSearchSheet(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Type Segmented Filter Buttons - Premium slider pill layout
          Builder(
            builder: (context) {
              final isDark = ThemeProvider.instance.isDarkMode;
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: ['Животные', 'Вещи'].map((type) {
                    final index = type == 'Животные' ? 0 : 1;
                    final isSelected = _currentPageIndex == index;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOutQuad,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? PulseColors.primary.withOpacity(0.18) 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: isSelected 
                                  ? (isDark ? Colors.white : Colors.black)
                                  : (isDark ? Colors.white60 : Colors.black45),
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<Map<String, dynamic>> items,
    PageController pageController,
    double pageViewOffset,
  ) {
    if (_isLoading && items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: PulseColors.primary));
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _currentPageIndex == 0
                ? SizedBox(
                    height: 180,
                    child: rive.RiveWidgetBuilder(
                      fileLoader: rive.FileLoader.fromUrl(
                        'https://cdn.rive.app/animations/wano_the_bear.riv',
                        riveFactory: rive.Factory.rive,
                      ),
                      builder: (context, state) {
                        if (state is rive.RiveLoading) {
                          return Center(
                            child: CircularProgressIndicator(color: PulseColors.primary),
                          );
                        }
                        if (state is rive.RiveFailed) {
                          return Icon(
                            Icons.pets_rounded,
                            size: 64,
                            color: PulseColors.textTertiary.withOpacity(0.5),
                          );
                        }
                        if (state is rive.RiveLoaded) {
                          return rive.RiveWidget(controller: state.controller);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  )
                : Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: PulseColors.textTertiary.withOpacity(0.5),
                  ),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: TextStyle(
                color: PulseColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Нет активных объявлений с адресом в этой категории.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Reset page controller if items changed
    if (pageController.hasClients && pageViewOffset >= items.length) {
      pageController.jumpToPage(0);
    }

    if (_isGridView) {
      return PulseMasonryGrid<Map<String, dynamic>>(
        items: items,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        builder: (context, item, index) {
          final title = item['title']?.toString() ?? 'Объявление';
          final category = item['category']?.toString() ?? 'Прочее';
          final description = item['description']?.toString() ?? '';
          final rawImages = SituationHelper.extractImageUrls(item);
          final images = rawImages.isNotEmpty ? rawImages : [_getPlaceholderImageFor(category, title, description, item['id']?.toString())];
          final color = PulseCategories.colorFor(category);
          
          final isDark = ThemeProvider.instance.isDarkMode;
          final cardBg = isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.38);
          final cardBorder = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
          final textCol = isDark ? Colors.white : Colors.black87;
          final descCol = isDark ? Colors.white.withOpacity(0.5) : Colors.black54;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showItemDetails(context, item, items);
            },
            child: AppPanel(
              style: PanelStyle.standard,
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(16),
              borderColor: cardBorder,
              backgroundColor: cardBg,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (images.isNotEmpty)
                      FindingImage(
                        url: images.first,
                        fit: BoxFit.cover,
                        placeholder: _buildPosterPlaceholder(category, color),
                      )
                    else
                      Container(
                        height: 120,
                        color: color.withOpacity(0.15),
                        child: Icon(Icons.pets_rounded, color: color, size: 36),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                color: color,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: TextStyle(
                              color: textCol,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                color: descCol,
                                fontSize: 11,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    final selectedIdx = pageViewOffset.round().clamp(0, items.length - 1);
    final selectedItem = items[selectedIdx];
    final selectedCategory = selectedItem['category']?.toString() ?? 'Прочее';
    final selectedColor = PulseCategories.colorFor(selectedCategory);
    final selectedImagesRaw = SituationHelper.extractImageUrls(selectedItem);
    final selectedImages = selectedImagesRaw.isNotEmpty ? selectedImagesRaw : [_getPlaceholderImageFor(selectedCategory, selectedItem['title']?.toString() ?? '', selectedItem['description']?.toString() ?? '', selectedItem['id']?.toString())];

    // Poster gradient colors
    final List<List<Color>> posterColors = ThemeProvider.instance.isDarkMode 
      ? [
          [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
          [const Color(0xFF0d1b2a), const Color(0xFF1b263b)],
          [const Color(0xFF2d1b3d), const Color(0xFF1a1a2e)],
        ]
      : [
          [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)], // Нежно-голубой
          [const Color(0xFFF3E5F5), const Color(0xFFE1BEE7)], // Нежно-сиреневый
          [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)], // Нежно-зеленый
        ];

    Color topColor = posterColors[0][0];
    Color bottomColor = posterColors[0][1];

    if (pageController.hasClients && pageController.position.haveDimensions) {
      final page = pageViewOffset;
      final i1 = page.floor() % posterColors.length;
      final i2 = page.ceil() % posterColors.length;
      final t = page - page.floor();
      topColor = Color.lerp(posterColors[i1][0], posterColors[i2][0], t) ?? posterColors[0][0];
      bottomColor = Color.lerp(posterColors[i1][1], posterColors[i2][1], t) ?? posterColors[0][1];
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              topColor.withOpacity(ThemeProvider.instance.isDarkMode ? 0.22 : 0.12),
              bottomColor.withOpacity(ThemeProvider.instance.isDarkMode ? 0.22 : 0.12),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // ── 3D Poster Carousel (Movie-style) ──
              SizedBox(
                height: 280,
                child: PageView.builder(
                  controller: pageController,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final title = item['title']?.toString() ?? 'Объявление';
                    final category = item['category']?.toString() ?? 'Прочее';
                    final rawImages = SituationHelper.extractImageUrls(item);
                    final images = rawImages.isNotEmpty ? rawImages : [_getPlaceholderImageFor(category, title, item['description']?.toString() ?? '', item['id']?.toString())];
                    final color = PulseCategories.colorFor(category);

                    double val = 0.0;
                    if (pageController.hasClients && pageController.position.haveDimensions) {
                      val = pageViewOffset - index;
                    } else {
                      val = index == 0 ? 0.0 : 1.0;
                    }
                    final double scale = (1 - val.abs() * 0.16).clamp(0.82, 1.0);
                    final double opacity = (1 - val.abs() * 0.45).clamp(0.5, 1.0);

                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showItemDetails(context, item, items);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 6),
                                  )
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Poster image
                                    if (images.isNotEmpty)
                                      FindingImage(
                                        url: images.first,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            _buildPosterPlaceholder(category, color),
                                      ).animate().fadeIn(duration: const Duration(milliseconds: 350)).shimmer(color: Colors.white24, duration: const Duration(milliseconds: 1500))
                                    else
                                      _buildPosterPlaceholder(category, color).animate().fadeIn(duration: const Duration(milliseconds: 250)),
                                    // Gradient overlay
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.85),
                                            ],
                                            stops: const [0.5, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Category badge top-right
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          category.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Neon Status badge top-left
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: category.contains('Найдено')
                                              ? const Color(0xFF00FF88).withOpacity(0.22)
                                              : const Color(0xFFFF3366).withOpacity(0.22),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: category.contains('Найдено')
                                                ? const Color(0xFF00FF88)
                                                : const Color(0xFFFF3366),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (category.contains('Найдено')
                                                  ? const Color(0xFF00FF88)
                                                  : const Color(0xFFFF3366)).withOpacity(0.4),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            )
                                          ],
                                        ),
                                        child: Text(
                                          category.contains('Найдено') ? '✅ НАЙДЕНО' : '🚨 В РОЗЫСКЕ',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Title + category at bottom
                                    Positioned(
                                      bottom: 16,
                                      left: 16,
                                      right: 16,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '№${item['id'] ?? index + 1}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Poster reflection (wet-floor cinema effect)
              SizedBox(
                height: 60,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white24,
                      Colors.transparent,
                    ],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: Transform(
                    alignment: Alignment.topCenter,
                    transform: Matrix4.identity()
                      ..scale(1.0, -1.0),
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 0.22,
                        child: Opacity(
                          opacity: 0.35,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                            child: selectedImages.isNotEmpty
                                ? Image.network(
                                    selectedImages.first,
                                    width: MediaQuery.of(context).size.width * 0.6,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildPosterPlaceholderReflection(selectedCategory, selectedColor),
                                  )
                                : _buildPosterPlaceholderReflection(selectedCategory, selectedColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Page Dots ──
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(items.length.clamp(0, 12), (i) {
                  final active = i == selectedIdx;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? selectedColor : (ThemeProvider.instance.isDarkMode ? Colors.white24 : Colors.black12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
  }

  Widget _buildPosterPlaceholder(String category, Color color) {
    final String url = category.toLowerCase().contains('животн')
        ? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&q=80&w=600'
        : category.toLowerCase().contains('вещ')
            ? 'https://images.unsplash.com/photo-1582139329536-e7284fece509?auto=format&fit=crop&q=80&w=600'
            : 'https://images.unsplash.com/photo-1527689368864-3a821dbccc34?auto=format&fit=crop&q=80&w=600';
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: color.withOpacity(0.1),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: color.withOpacity(0.15),
        child: Icon(Icons.broken_image_rounded, color: color),
      ),
    );
  }

  Widget _buildPosterPlaceholderReflection(String category, Color color) {
    final String url = category.toLowerCase().contains('животн')
        ? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&q=80&w=300'
        : category.toLowerCase().contains('вещ')
            ? 'https://images.unsplash.com/photo-1582139329536-e7284fece509?auto=format&fit=crop&q=80&w=300'
            : 'https://images.unsplash.com/photo-1527689368864-3a821dbccc34?auto=format&fit=crop&q=80&w=300';
    return Opacity(
      opacity: 0.15,
      child: Image.network(
        url,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildMoviesTab() {
    final activeCity = CityProvider().activeCity.backendCityParam;
    final cityKey = activeCity == 'novosibirsk' ? 'novosibirsk' : 'nizhnevartovsk';
    
    // Filter movies if search query is not empty
    var filteredMovies = _movies;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredMovies = _movies.where((m) {
        final title = m['title']?.toString().toLowerCase() ?? '';
        final genre = m['genre']?.toString().toLowerCase() ?? '';
        final desc = m['description']?.toString().toLowerCase() ?? '';
        return title.contains(q) || genre.contains(q) || desc.contains(q);
      }).toList();
    }

    if (filteredMovies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter_outlined, size: 64, color: PulseColors.textTertiary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Фильмы не найдены',
              style: TextStyle(color: PulseColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // Dynamic PageView-linked gradient colors for the movies tab background
    final colors = [
      const [Color(0xFF020617), Color(0xFF13131A)], // m1
      const [Color(0xFF02261E), Color(0xFF051C17)], // m2
      const [Color(0xFF080D21), Color(0xFF1C053B)], // m3
    ];

    Color topColor = colors[0][0];
    Color bottomColor = colors[0][1];

    if (_moviePageController.hasClients && _moviePageController.position.haveDimensions) {
      double page = _moviePageViewOffset;
      int index1 = page.floor().clamp(0, colors.length - 1);
      int index2 = page.ceil().clamp(0, colors.length - 1);
      double t = page - index1;

      topColor = Color.lerp(colors[index1][0], colors[index2][0], t) ?? colors[0][0];
      bottomColor = Color.lerp(colors[index1][1], colors[index2][1], t) ?? colors[0][1];
    }

    final selectedIdx = _moviePageViewOffset.round().clamp(0, filteredMovies.length - 1);
    final selectedMovie = filteredMovies[selectedIdx];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            // 3D Movie Poster Carousel
            SizedBox(
              height: 280,
              child: PageView.builder(
                controller: _moviePageController,
                itemCount: filteredMovies.length,
                itemBuilder: (context, index) {
                  final movie = filteredMovies[index];
                  final poster = movie['image'] as String;
                  
                  // Calculate scale & opacity based on page scroll offset
                  double val = 0.0;
                  if (_moviePageController.hasClients && _moviePageController.position.haveDimensions) {
                    val = _moviePageViewOffset - index;
                  } else {
                    val = index == 0 ? 0.0 : 1.0;
                  }
                  final double scale = (1 - val.abs() * 0.16).clamp(0.82, 1.0);
                  final double opacity = (1 - val.abs() * 0.45).clamp(0.5, 1.0);

                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showMovieDetails(context, movie);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    poster,
                                    fit: BoxFit.cover,
                                  ),
                                  // Gradient Overlay for readability
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.85),
                                          ],
                                          stops: const [0.6, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 16,
                                    left: 16,
                                    right: 16,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          movie['title'] as String,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          movie['genre'] as String,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Poster reflection (wet-floor cinema effect)
            SizedBox(
              height: 60,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white24,
                    Colors.transparent,
                  ],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.identity()
                    ..scale(1.0, -1.0),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: 0.22,
                      child: Opacity(
                        opacity: 0.35,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                          child: Image.asset(
                            selectedMovie['image'] as String,
                            width: MediaQuery.of(context).size.width * 0.6,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── Page Dots for movies ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(filteredMovies.length, (i) {
                final active = i == selectedIdx;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? PulseColors.primary : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            // ── AI Daily Fun Section ──────────────────────────────────────
            _buildDailyFunSection(),
          ],
        ),
      ),
    );
  }

  // ── Daily Fun Helper Widgets ────────────────────────────────────────────────

  static const Map<String, Color> _funTypeColors = {
    'theatre': Color(0xFF9C27B0),
    'event':   Color(0xFF2196F3),
    'movie':   Color(0xFFE91E63),
  };

  static const Map<String, String> _funTypeLabels = {
    'all':     '🎪 Все',
    'theatre': '🎭 Пьесы',
    'event':   '🎉 Мероприятия',
    'movie':   '🎬 Кино дня',
  };

  Widget _buildDailyFunSection() {
    final filtered = _dailyFunType == 'all'
        ? _dailyFunItems
        : _dailyFunItems.where((i) => i['type'] == _dailyFunType).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
          child: Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Афиша дня от ИИ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_dailyFunDate.isNotEmpty)
                      Text(
                        _dailyFunDate,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              // Refresh button
              InkWell(
                onTap: _loadDailyFun,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _isDailyFunLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white54,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, color: Colors.white54, size: 20),
                ),
              ),
            ],
          ),
        ),
        // Type filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _funTypeLabels.entries.map((entry) {
                final isActive = _dailyFunType == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _dailyFunType = entry.key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? PulseColors.primary.withOpacity(0.22)
                            : Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? PulseColors.primary.withOpacity(0.7)
                              : Colors.white.withOpacity(0.14),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white54,
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Cards
        if (_isDailyFunLoading && filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: PulseColors.primary),
            ),
          )
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const Text('🎪', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text(
                  'Афиша загружается...',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                ),
              ],
            ),
          )
        else
          ...filtered.map((item) => _buildDailyFunCard(item)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDailyFunCard(Map<String, dynamic> item) {
    final type = item['type'] as String? ?? 'event';
    final typeColor = _funTypeColors[type] ?? PulseColors.primary;
    final photoUrl = SituationHelper.resolveImageUrl(item['photo_url'] as String? ?? '');
    final schedule = (item['schedule'] as List<dynamic>? ?? []).cast<String>();
    final tags = (item['tags'] as List<dynamic>? ?? []).cast<String>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: typeColor.withOpacity(0.25), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo
            if (photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    Image.network(
                      photoUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: typeColor.withOpacity(0.12),
                        child: Center(
                          child: Text(
                            item['emoji'] as String? ?? '🎭',
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.72)],
                            stops: const [0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Type badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _funTypeLabels[type]?.replaceAll('🎪 ', '').replaceAll('🎭 ', '🎭 ').replaceAll('🎉 ', '🎉 ').replaceAll('🎬 ', '🎬 ') ?? type,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Rating badge
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.white, size: 11),
                            const SizedBox(width: 2),
                            Text(
                              item['rating']?.toString() ?? '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Emoji
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: Text(
                        item['emoji'] as String? ?? '🎭',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    // Duration badge
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item['duration']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Genre
                  Text(
                    item['title']?.toString() ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['genre']?.toString() ?? '',
                    style: TextStyle(
                      color: typeColor.withOpacity(0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Description
                  Builder(builder: (ctx) {
                    final rawDesc = item['description']?.toString() ?? '';
                    final cleanDesc = rawDesc.replaceAll(RegExp(r'Фото:\s*https?://\S+'), '').trim();
                    final displayDesc = cleanDesc.isNotEmpty
                        ? cleanDesc
                        : (item['summary']?.toString() ?? item['title']?.toString() ?? 'Описание сигнала отсутствует');

                    return Text(
                      displayDesc,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    );
                  }),
                  // Tags
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: typeColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            color: typeColor.withOpacity(0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                  // Venue & Schedule
                  if (item['venue'] != null || schedule.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Colors.white10, height: 1),
                    ),
                    if (item['venue'] != null)
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, color: typeColor, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item['venue'].toString(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (schedule.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, color: typeColor, size: 14),
                          const SizedBox(width: 6),
                          Wrap(
                            spacing: 6,
                            children: schedule.map((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: typeColor.withOpacity(0.35)),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  color: typeColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )).toList(),
                          ),
                        ],
                      ),
                    ],
                    // Book button
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Запрос на "${item["title"]}" отправлен! 🎉'),
                              backgroundColor: typeColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: typeColor.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          side: BorderSide(color: typeColor.withOpacity(0.6)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Хочу сходить! 🎟️',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAiCrossSearchSheet(BuildContext context) {
    if (_searchQuery.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, введите ключевые слова для поиска (например: черный телефон или собака хаски)'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AiCrossSearchModal(query: _searchQuery);
      },
    );
  }

  void _showArRadarDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return _ArLostAndFoundRadarWidget(allItems: _allItems);
      },
    );
  }
}

class _AiCrossSearchModal extends StatefulWidget {
  final String query;
  const _AiCrossSearchModal({required this.query});

  @override
  State<_AiCrossSearchModal> createState() => _AiCrossSearchModalState();
}

class _AiCrossSearchModalState extends State<_AiCrossSearchModal> with SingleTickerProviderStateMixin {
  bool _scanning = true;
  bool _loading = false;
  String _status = 'Инициализация нейросети Гермес...';
  List<dynamic> _results = [];
  String? _error;
  late AnimationController _animController;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startScanningSequence();
  }

  @override
  void dispose() {
    _animController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startScanningSequence() {
    final statuses = [
      'Подключение к Hermes AI & RAG Нижневартовска...',
      'Поиск гео-сигналов, генерация PDF-обращений в ЖКХ...',
      'Анализ адресов домов, новостей и городских камер...',
      'Мониторинг Telegram & VK Бюро Находок...',
      '3D-визуализация (FLUX.1 Schnell) и синтез речи Fish Speech...',
      'Генерация отчета по совпадениям...'
    ];
    int idx = 0;

    _statusTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (idx < statuses.length) {
        setState(() => _status = statuses[idx++]);
      } else {
        t.cancel();
        setState(() {
          _scanning = false;
          _loading = true;
        });
        _executeSearch();
      }
    });
  }

  Future<void> _executeSearch() async {
    try {
      final resp = await BackendApiService.instance.postJson(
        '/api/daily-fun/lost-and-found/cross-search',
        {'query': widget.query},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true) {
          setState(() {
            _results = data['results'] ?? [];
            _loading = false;
          });
          return;
        }
      }
      setState(() {
        _error = 'Не удалось загрузить результаты';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка соединения с сервером';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: media.size.height * 0.8,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A).withOpacity(0.92),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Stack(
        children: [
          // Holographic background grids
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: GridPaper(
                color: Colors.blueAccent,
                interval: 20,
                subdivisions: 1,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header indicator bar
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'ИИ КРОСС-ПОИСК ГЕРМЕСА',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white60),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Divider(color: Colors.white12),
              ),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_scanning) {
      return _buildScannerView();
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 12),
            const Text(
              'Совпадений в соцсетях не найдено',
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Попробуйте изменить запрос "${widget.query}"',
                style: const TextStyle(color: Colors.white30, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, idx) {
        final res = _results[idx];
        final double score = (res['score'] as num?)?.toDouble() ?? 0.0;
        final isSocial = res['type'] == 'social';
        final Color scoreColor = score >= 80
            ? Colors.greenAccent
            : (score >= 60 ? Colors.orangeAccent : Colors.white60);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSocial ? Colors.blueAccent.withOpacity(0.2) : Colors.white12,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSocial ? Colors.blueAccent.withOpacity(0.15) : Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSocial ? Colors.blueAccent.withOpacity(0.3) : Colors.white24,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        res['source'] ?? 'СообщиО',
                        style: TextStyle(
                          color: isSocial ? Colors.blueAccent : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Сходство: ${score.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  res['title'] ?? 'Без названия',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  res['description'] ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.white38, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        res['address'] ?? 'Нижневартовск',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      res['created_at'] ?? 'Недавно',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                if (isSocial && res['source_url'] != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        foregroundColor: Colors.blueAccent,
                        elevation: 0,
                        side: BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        unawaited(launchUrl(Uri.parse(res['source_url'])));
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.open_in_new_rounded, size: 14),
                          SizedBox(width: 6),
                          Text('Перейти к посту источника', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScannerView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.1 + (_animController.value * 0.4)),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.05 + (_animController.value * 0.15)),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.15 + (_animController.value * 0.55),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.blueAccent,
                      size: 48,
                    ),
                  ),
                  CustomPaint(
                    size: const Size(130, 130),
                    painter: _RadarSweepPainter(progress: _animController.value),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'ИИ СКАНИРОВАНИЕ СЕТИ...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            _status,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _RadarSweepPainter extends CustomPainter {
  final double progress;
  _RadarSweepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * progress;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) => oldDelegate.progress != progress;
}

// ── AR LOST & FOUND RADAR WIDGET IMPLEMENTATION ────────────────────────────
class _ArLostAndFoundRadarWidget extends StatefulWidget {
  final List<Map<String, dynamic>> allItems;
  const _ArLostAndFoundRadarWidget({required this.allItems});

  @override
  State<_ArLostAndFoundRadarWidget> createState() => _ArLostAndFoundRadarWidgetState();
}

class _ArLostAndFoundRadarWidgetState extends State<_ArLostAndFoundRadarWidget> with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;
  String? _cameraError;

  // Viewport azimuth/yaw rotation via drag to ensure 360° compatibility
  double _viewportYaw = 180.0; 
  late AnimationController _radarScanController;
  
  Map<String, dynamic>? _selectedRadarItem;
  String _filterType = 'all'; // all | animals | things
  List<Map<String, dynamic>> _radarItems = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
    _prepareRadarItems();
    
    _radarScanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _radarScanController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraError = 'Камеры недоступны');
        return;
      }
      
      // Find back-facing camera
      final backCam = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _cameraReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = 'Не удалось инициализировать камеру: $e';
        });
      }
    }
  }

  void _prepareRadarItems() {
    const double defaultUserLat = 60.9344;
    const double defaultUserLng = 76.5531;

    final rand = math.Random(42);
    _radarItems = widget.allItems.map((item) {
      final id = item['id']?.toString() ?? '';
      final title = item['title']?.toString() ?? 'Без названия';
      final desc = item['description']?.toString() ?? '';
      final category = item['category']?.toString() ?? '';
      final isAnimal = category.toLowerCase().contains('животн') || 
                       title.toLowerCase().contains('собак') || 
                       title.toLowerCase().contains('кот');

      final rawLat = item['lat'] ?? item['latitude'];
      final rawLng = item['lng'] ?? item['longitude'];
      final double lat = rawLat is num ? rawLat.toDouble() : double.tryParse(rawLat?.toString() ?? '') ?? (defaultUserLat + (rand.nextDouble() - 0.5) * 0.02);
      final double lng = rawLng is num ? rawLng.toDouble() : double.tryParse(rawLng?.toString() ?? '') ?? (defaultUserLng + (rand.nextDouble() - 0.5) * 0.02);

      // Real geodesic distance in meters
      final double realDistance = Geolocator.distanceBetween(defaultUserLat, defaultUserLng, lat, lng);
      final double azimuth = rand.nextDouble() * 360.0;

      return {
        'id': id,
        'title': title,
        'description': desc,
        'category': category,
        'isAnimal': isAnimal,
        'azimuth': azimuth,
        'distance': realDistance > 0 ? realDistance : 150.0,
        'raw_item': item,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredRadarItems {
    if (_filterType == 'animals') {
      return _radarItems.where((e) => e['isAnimal'] == true).toList();
    }
    if (_filterType == 'things') {
      return _radarItems.where((e) => e['isAnimal'] == false).toList();
    }
    return _radarItems;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final filtered = _filteredRadarItems;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Live Camera Preview / Futuristic Backdrop ──
          Positioned.fill(
            child: _cameraReady && _cameraController != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize!.height,
                      height: _cameraController!.value.previewSize!.width,
                      child: CameraPreview(_cameraController!),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF020617)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar_rounded, color: Colors.cyanAccent.withOpacity(0.3), size: 72),
                          const SizedBox(height: 16),
                          Text(
                            _cameraError ?? 'Инициализация AR-сенсоров...',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // ── 2. Grid HUD Scan Lines Overlay ──
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HudGridPainter(),
              ),
            ),
          ),

          // ── 3. Swipe-to-Rotate Viewport Area ──
          Positioned.fill(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  // Translate touch drag into viewport rotation
                  _viewportYaw = (_viewportYaw - details.primaryDelta! * 0.4) % 360.0;
                });
              },
              child: Container(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    // AR elements projected relative to viewport azimuth
                    for (final item in filtered) _buildProjectedRadarPin(item, size),
                  ],
                ),
              ),
            ),
          ),

          // ── 4. Floating Holographic Radar HUD (Top Center) ──
          Positioned(
            top: 70,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Radar sweep indicator
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.4),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Sweep line
                      AnimatedBuilder(
                        animation: _radarScanController,
                        builder: (context, _) {
                          return Transform.rotate(
                            angle: _radarScanController.value * 2 * math.pi,
                            child: Container(
                              width: 80,
                              height: 1.5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.cyanAccent,
                                    Colors.cyanAccent.withOpacity(0),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Mini dots representing things
                      for (final item in filtered)
                        Builder(
                          builder: (context) {
                            final distRatio = (item['distance'] as double) / 280.0;
                            final angle = (item['azimuth'] as double) * math.pi / 180.0;
                            final x = 40 * distRatio * math.cos(angle);
                            final y = 40 * distRatio * math.sin(angle);
                            return Transform.translate(
                              offset: Offset(x, y),
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item['isAnimal'] ? Colors.orangeAccent : Colors.cyanAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: item['isAnimal'] ? Colors.orangeAccent : Colors.cyanAccent,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                // Telemetry overlay
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'SYSTEM: AR_RADAR_ACTIVE',
                      style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    Text(
                      'YAW: ${_viewportYaw.toStringAsFixed(1)}°',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                    ),
                    Text(
                      'TARGETS: ${filtered.length}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ],
                )
              ],
            ),
          ),

          // ── 5. Selected Item Glass Details Sheet ──
          if (_selectedRadarItem != null)
            Positioned(
              bottom: 110,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedRadarItem!['title'],
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(_selectedRadarItem!['distance'] as double).round()} метров',
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedRadarItem!['description'] ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                final raw = _selectedRadarItem!['raw_item'];
                                Navigator.pop(context);
                                // Open details sheet in main view
                                // (We can handle calling detail display if parent exposes it)
                              },
                              icon: const Icon(Icons.info_outline_rounded, size: 16, color: Colors.cyanAccent),
                              label: const Text('ПОДРОБНЕЕ', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                              onPressed: () => setState(() => _selectedRadarItem = null),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── 6. Bottom Controls Bar (Filter Buttons + Exit) ──
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              children: [
                // Filter all
                Expanded(
                  child: _buildControlFilterBtn('BCE', 'all', Icons.all_inclusive_rounded),
                ),
                const SizedBox(width: 8),
                // Filter animals
                Expanded(
                  child: _buildControlFilterBtn('ПИТОМЦЫ', 'animals', Icons.pets_rounded),
                ),
                const SizedBox(width: 8),
                // Filter things
                Expanded(
                  child: _buildControlFilterBtn('ВЕЩИ', 'things', Icons.inventory_2_outlined),
                ),
                const SizedBox(width: 16),
                // Close button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withOpacity(0.18),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.6), width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlFilterBtn(String label, String value, IconData icon) {
    final active = _filterType == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _filterType = value;
          _selectedRadarItem = null;
        });
      },
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: active ? Colors.cyanAccent.withOpacity(0.2) : Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? Colors.cyanAccent : Colors.white24,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? Colors.cyanAccent : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.cyanAccent : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectedRadarPin(Map<String, dynamic> item, Size size) {
    final double itemAzimuth = item['azimuth'];
    final double distance = item['distance'];

    // Map item azimuth relative to viewport rotation
    double diff = (itemAzimuth - _viewportYaw) % 360.0;
    if (diff > 180.0) diff -= 360.0;

    // Viewport field-of-view (FOV) width: ~80 degrees
    const fov = 80.0;
    if (diff.abs() > fov / 2) {
      return const SizedBox.shrink(); // Outside screen bounds
    }

    // Horizontal placement ratio (-1.0 left to 1.0 right)
    final double xRatio = diff / (fov / 2);
    final double screenX = (size.width / 2) + xRatio * (size.width / 2) * 0.9;

    // Depth perspective factor (items further away are higher and smaller)
    final double depthScale = (1.0 - (distance / 320.0)).clamp(0.45, 0.95);
    final double screenY = (size.height / 2) - (distance * 0.5) + 30;

    final isAnimal = item['isAnimal'] as bool;
    final pinColor = isAnimal ? Colors.orangeAccent : Colors.cyanAccent;

    return Positioned(
      left: screenX - 55,
      top: screenY - 55,
      child: Transform.scale(
        scale: depthScale,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedRadarItem = item;
            });
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Holographic pin tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pinColor.withOpacity(0.7), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: pinColor.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAnimal ? Icons.pets_rounded : Icons.inventory_2_outlined,
                      color: pinColor,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          item['title'],
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Connecting neon line down
              Container(
                width: 1.5,
                height: 30,
                color: pinColor.withOpacity(0.55),
              ),
              // Radar ping ripple at base
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pinColor,
                  boxShadow: [
                    BoxShadow(
                      color: pinColor,
                      blurRadius: 6,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.04)
      ..strokeWidth = 0.8;

    // Draw vertical HUD lines
    final stepX = size.width / 8;
    for (int i = 1; i < 8; i++) {
      canvas.drawLine(Offset(i * stepX, 0), Offset(i * stepX, size.height), paint);
    }

    // Draw horizontal HUD lines
    final stepY = size.height / 12;
    for (int i = 1; i < 12; i++) {
      canvas.drawLine(Offset(0, i * stepY), Offset(size.width, i * stepY), paint);
    }

    // Draw HUD corners
    final cornerPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.25)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final double pad = 24.0;
    final double len = 15.0;

    // Top-Left corner
    canvas.drawPath(
      Path()
        ..moveTo(pad, pad + len)
        ..lineTo(pad, pad)
        ..lineTo(pad + len, pad),
      cornerPaint,
    );

    // Top-Right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad - len, pad)
        ..lineTo(size.width - pad, pad)
        ..lineTo(size.width - pad, pad + len),
      cornerPaint,
    );

    // Bottom-Left corner
    canvas.drawPath(
      Path()
        ..moveTo(pad, size.height - pad - len)
        ..lineTo(pad, size.height - pad)
        ..lineTo(pad + len, size.height - pad),
      cornerPaint,
    );

    // Bottom-Right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - pad - len, size.height - pad)
        ..lineTo(size.width - pad, size.height - pad)
        ..lineTo(size.width - pad, size.height - pad - len),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HudGridPainter oldDelegate) => false;
}

