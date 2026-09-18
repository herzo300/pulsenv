// services/Frontend/lib/screens/lost_and_found_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/backend_api_service.dart';

import '../core/app_router.dart';
import '../map/map_config.dart';
import '../theme/pulse_colors.dart';
import '../theme/pulse_categories.dart';
import '../widgets/app_ui.dart';
import '../widgets/category_icon_3d.dart';
import '../utils/situation_helper.dart';
import '../services/city_provider.dart';

class LostAndFoundScreen extends StatefulWidget {
  const LostAndFoundScreen({super.key});

  @override
  State<LostAndFoundScreen> createState() => _LostAndFoundScreenState();
}

class _LostAndFoundScreenState extends State<LostAndFoundScreen> {
  static const String _complaintsCachePrefKey = 'map_cached_markers_v2';
  
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = false;
  String _searchQuery = '';
  int _currentPageIndex = 0; // 0 = Животные, 1 = Вещи, 2 = Кино

  late PageController _pageController;
  late PageController _moviePageController;
  double _moviePageViewOffset = 0.0;

  late PageController _itemPageController;
  double _itemPageViewOffset = 0.0;

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
    _itemPageController = PageController(viewportFraction: 0.78, initialPage: 0);
    _itemPageController.addListener(() {
      if (mounted) {
        setState(() {
          _itemPageViewOffset = _itemPageController.page ?? 0.0;
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
    _itemPageController.dispose();
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
      var category = item['category']?.toString() ?? '';
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
      final excludedCats = ['ЖКХ', 'Дороги', 'Благоустройство', 'Транспорт', 'Безопасность', 'Экология', 'Мероприятие', 'Камеры', 'Здравоохранение', 'Образование'];
      if (excludedCats.any((ec) => category.contains(ec))) return false;
      
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
    var result = _allItems;

    // Filter by type (Животные vs Вещи vs Кино)
    if (_currentPageIndex == 0) {
      result = result.where((item) => (item['category']?.toString() ?? '').toLowerCase().contains('животн')).toList();
    } else if (_currentPageIndex == 1) {
      result = result.where((item) => (item['category']?.toString() ?? '').toLowerCase().contains('вещ')).toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((item) {
        final title = item['title']?.toString().toLowerCase() ?? '';
        final desc = item['description']?.toString().toLowerCase() ?? '';
        final address = (item['_derivedAddress'] ?? item['address'])?.toString().toLowerCase() ?? '';
        return title.contains(q) || desc.contains(q) || address.contains(q);
      }).toList();
    }

    setState(() {
      _filteredItems = result;
    });
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

  void _showItemDetails(BuildContext context, Map<String, dynamic> item) {
    final initialIndex = _filteredItems.indexWhere((x) => x['id'] == item['id']).clamp(0, _filteredItems.length - 1);
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
              itemCount: _filteredItems.length,
              itemBuilder: (context, idx) {
                final curItem = _filteredItems[idx];
                final title = curItem['title'] ?? 'Объявление';
                final desc = curItem['description'] ?? 'Нет описания';
                final category = curItem['category'] ?? 'Прочее';
                final address = (curItem['_derivedAddress'] ?? curItem['address'])?.toString() ?? CityProvider().activeCity.name;
                final images = SituationHelper.extractImageUrls(curItem);
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
                                      ? Image.network(
                                          images.first,
                                          height: 220,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Image.asset(
                                            category.toString().toLowerCase().contains('животн')
                                                ? 'assets/poster_taiga.png'
                                                : 'assets/poster_samotlor.png',
                                            height: 220,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Image.asset(
                                          category.toString().toLowerCase().contains('животн')
                                              ? 'assets/poster_taiga.png'
                                              : 'assets/poster_samotlor.png',
                                          height: 220,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
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
        preferredSize: const Size.fromHeight(60),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PulseColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: PulseColors.primary.withAlpha(180),
                          blurRadius: 8,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.travel_explore_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
              backgroundColor: Colors.white.withAlpha(12),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Фоновый градиент ──────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF07122A),
                  Color(0xFF0D1F3C),
                  Color(0xFF0B2840),
                  Color(0xFF071525),
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
          // ── Декоративные размытые пятна ────────────────────────
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PulseColors.primary.withAlpha(55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -50,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withAlpha(40),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // ── Стекло-слой ──────────────────────────────────────
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              color: Colors.black.withAlpha(30),
            ),
          ),
          // ── Контент ──────────────────────────────────────────
          SafeArea(
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
                          RefreshIndicator(
                            onRefresh: _fetchFromNetwork,
                            color: PulseColors.primary,
                            backgroundColor: Colors.white.withAlpha(20),
                            child: _buildContent(),
                          ),
                          // Вкладка 2: Вещи
                          RefreshIndicator(
                            onRefresh: _fetchFromNetwork,
                            color: PulseColors.primary,
                            backgroundColor: Colors.white.withAlpha(20),
                            child: _buildContent(),
                          ),
                          // Вкладка 3: Афиша Кино
                          _buildMoviesTab(),
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
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          // Search input field
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilters();
                  },
                  style: TextStyle(color: PulseColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _currentPageIndex == 2 ? 'Поиск фильмов...' : 'Поиск вещей и животных...',
                    hintStyle: TextStyle(color: PulseColors.textTertiary.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.search_rounded, color: PulseColors.textSecondary),
                    filled: true,
                    fillColor: PulseColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadii.md,
                      borderSide: BorderSide(color: PulseColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadii.md,
                      borderSide: const BorderSide(color: PulseColors.primaryDeep),
                    ),
                  ),
                ),
              ),
              if (_currentPageIndex != 2) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showAiCrossSearchSheet(context),
                  borderRadius: AppRadii.md,
                  child: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.12),
                      borderRadius: AppRadii.md,
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
            ],
          ),
          const SizedBox(height: 12),
          // Type Segmented Filter Buttons
          Row(
            children: ['Животные', 'Вещи', 'Афиша Кино'].map((type) {
              final index = type == 'Животные' ? 0 : (type == 'Вещи' ? 1 : 2);
              final isSelected = _currentPageIndex == index;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOutQuad,
                      );
                    },
                    borderRadius: AppRadii.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? PulseColors.primary.withOpacity(0.15) 
                            : PulseColors.surface,
                        borderRadius: AppRadii.sm,
                        border: Border.all(
                          color: isSelected ? PulseColors.primary : PulseColors.border,
                        ),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? PulseColors.primary : PulseColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _filteredItems.isEmpty) {
      return Center(child: CircularProgressIndicator(color: PulseColors.primary));
    }

    if (_filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _currentPageIndex == 0
                  ? Icons.pets_rounded
                  : Icons.shopping_bag_outlined,
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
    if (_itemPageController.hasClients && _itemPageViewOffset >= _filteredItems.length) {
      _itemPageViewOffset = 0.0;
    }

    final selectedIdx = _itemPageViewOffset.round().clamp(0, _filteredItems.length - 1);
    final selectedItem = _filteredItems[selectedIdx];
    final selectedCategory = selectedItem['category']?.toString() ?? 'Прочее';
    final selectedColor = PulseCategories.colorFor(selectedCategory);
    final selectedImages = SituationHelper.extractImageUrls(selectedItem);

    // Poster gradient colors
    final List<List<Color>> posterColors = [
      [const Color(0xFF1a1a2e), const Color(0xFF16213e)],
      [const Color(0xFF0d1b2a), const Color(0xFF1b263b)],
      [const Color(0xFF2d1b3d), const Color(0xFF1a1a2e)],
    ];

    Color topColor = posterColors[0][0];
    Color bottomColor = posterColors[0][1];

    if (_itemPageController.hasClients && _itemPageController.position.haveDimensions) {
      final page = _itemPageViewOffset;
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
            colors: [topColor, bottomColor],
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
                  controller: _itemPageController,
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final images = SituationHelper.extractImageUrls(item);
                    final title = item['title']?.toString() ?? 'Объявление';
                    final category = item['category']?.toString() ?? 'Прочее';
                    final color = PulseCategories.colorFor(category);

                    double val = 0.0;
                    if (_itemPageController.hasClients && _itemPageController.position.haveDimensions) {
                      val = _itemPageViewOffset - index;
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
                              _showItemDetails(context, item);
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
                                      Image.network(
                                        images.first,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildPosterPlaceholder(category, color),
                                      )
                                    else
                                      _buildPosterPlaceholder(category, color),
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
                children: List.generate(_filteredItems.length.clamp(0, 12), (i) {
                  final active = i == selectedIdx;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? selectedColor : Colors.white24,
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.3),
            color.withOpacity(0.08),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          category.toLowerCase().contains('животн')
              ? Icons.pets_rounded
              : category.toLowerCase().contains('вещ')
                  ? Icons.shopping_bag_rounded
                  : Icons.travel_explore_rounded,
          color: color.withOpacity(0.25),
          size: 80,
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholderReflection(String category, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.6,
      height: 280 * 0.22,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.3),
            color.withOpacity(0.08),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          category.toLowerCase().contains('животн')
              ? Icons.pets_rounded
              : category.toLowerCase().contains('вещ')
                  ? Icons.shopping_bag_rounded
                  : Icons.travel_explore_rounded,
          color: color.withOpacity(0.25),
          size: 24,
        ),
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
                  Text(
                    item['description']?.toString() ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
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
      'Подключение к RAG-серверу Нижневартовска...',
      'Анализ внутренних репортов и сигналов...',
      'Сканирование городских VK-пабликов и каналов...',
      'Анализ Telegram Бюро Находок Нижневартовск...',
      'Сопоставление ключевых признаков Гермесом...',
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
