// services/Frontend/lib/screens/lost_and_found_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../map/map_config.dart';
import '../theme/theme_provider.dart';
import '../services/sound_service.dart';
import '../utils/situation_helper.dart';
import 'lost_and_found/widgets/add_finding_sheet.dart';
import '../widgets/lost_found_geo_radar.dart';

class LostAndFoundScreen extends StatefulWidget {
  const LostAndFoundScreen({super.key});

  @override
  State<LostAndFoundScreen> createState() => _LostAndFoundScreenState();
}

String _getThematicFallbackPhoto(String category, String title) {
  final t = '$category $title'.toLowerCase();
  if (t.contains('кот') || t.contains('кош') || t.contains('котен')) {
    return 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&q=80&w=800';
  } else if (t.contains('хаски') || t.contains('шпиц') || t.contains('лабрадор') || t.contains('собак') || t.contains('щенок') || t.contains('пес') || t.contains('животн')) {
    return 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&q=80&w=800';
  } else if (t.contains('ключ') || t.contains('брелок')) {
    return 'https://images.unsplash.com/photo-1582139329536-e7284fece509?auto=format&fit=crop&q=80&w=800';
  } else if (t.contains('паспорт') || t.contains('документ') || t.contains('права') || t.contains('снилс') || t.contains('карт')) {
    return 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&q=80&w=800';
  } else if (t.contains('телефон') || t.contains('iphone') || t.contains('айфон') || t.contains('смартфон')) {
    return 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&q=80&w=800';
  } else if (t.contains('велик') || t.contains('велосипед') || t.contains('самокат')) {
    return 'https://images.unsplash.com/photo-1485965120184-e220f721d03e?auto=format&fit=crop&q=80&w=800';
  } else if (t.contains('рюкзак') || t.contains('сумк') || t.contains('портфель')) {
    return 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&q=80&w=800';
  } else if (t.contains('кольц') || t.contains('серьг') || t.contains('золот') || t.contains('серебр') || t.contains('украшен')) {
    return 'https://images.unsplash.com/photo-1605100804763-247f67b3557e?auto=format&fit=crop&q=80&w=800';
  }
  return 'https://images.unsplash.com/photo-1586769852044-692d6e3703f0?auto=format&fit=crop&q=80&w=800';
}

class FindingImage extends StatelessWidget {
  const FindingImage({
    super.key,
    required this.url,
    required this.placeholder,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.category = '',
    this.title = '',
  });

  final String url;
  final Widget placeholder;
  final double? height;
  final double? width;
  final BoxFit fit;
  final String category;
  final String title;

  Widget _buildFallbackContainer() {
    final isPet = category.toLowerCase().contains('животн') || 
                  category.toLowerCase().contains('питомец') ||
                  title.toLowerCase().contains('кот') ||
                  title.toLowerCase().contains('собак');
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPet ? Icons.pets_rounded : Icons.inventory_2_rounded,
            color: const Color(0xFF00E5FF).withOpacity(0.7),
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            title.isNotEmpty ? title : (isPet ? 'Потерянный питомец' : 'Найденная вещь'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var finalUrl = url.trim();
    // Clean stringified JSON arrays like ["http..."] or 'http...'
    finalUrl = finalUrl.replaceAll(RegExp(r'^\["|";?\]$|^"|"$|^\[|\]$'), '').trim();
    
    if (finalUrl.startsWith('//')) {
      finalUrl = 'https:$finalUrl';
    }

    if (finalUrl.isEmpty) {
      finalUrl = _getThematicFallbackPhoto(category, title);
    }
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://') && !finalUrl.startsWith('file://')) {
      finalUrl = SituationHelper.resolveImageUrl(finalUrl);
    }

    if (finalUrl.startsWith('data:image/')) {
      try {
        final base64Str = finalUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallbackContainer(),
        );
      } catch (e) {
        return _buildFallbackContainer();
      }
    }

    if (finalUrl.startsWith('file://')) {
      final path = finalUrl.replaceFirst('file://', '');
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallbackContainer(),
        );
      } else {
        return _buildFallbackContainer();
      }
    }

    final resolvedUrl = SituationHelper.resolveImageUrl(finalUrl);

    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      height: height,
      width: width,
      fit: fit,
      placeholder: (context, url) => SizedBox(
        height: height,
        width: width,
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00E5FF),
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        final fallbackUrl = _getThematicFallbackPhoto(category, title);
        if (resolvedUrl != fallbackUrl) {
          return CachedNetworkImage(
            imageUrl: fallbackUrl,
            height: height,
            width: width,
            fit: fit,
            errorWidget: (_, __, ___) => _buildFallbackContainer(),
          );
        }
        return _buildFallbackContainer();
      },
    );
  }
}

class _LostAndFoundScreenState extends State<LostAndFoundScreen> with TickerProviderStateMixin {
  static const String _complaintsCachePrefKey = 'my_lost_and_found_items';

  static String _extractImageUrl(Map<String, dynamic> item) {
    var url = (item['image_url'] ?? item['photo_url'] ?? item['image'] ?? item['photo'])?.toString() ?? '';
    if (url.isNotEmpty) return url;
    if (item['images'] != null) {
      final imgs = item['images'];
      if (imgs is List && imgs.isNotEmpty) return imgs.first.toString();
      if (imgs is String && imgs.isNotEmpty) return imgs;
    }
    if (item['photos'] != null) {
      final photos = item['photos'];
      if (photos is List && photos.isNotEmpty) return photos.first.toString();
      if (photos is String && photos.isNotEmpty) return photos;
    }
    final desc = (item['description'] ?? '').toString();
    final match = RegExp(r'https?://[^\s<>"{}|\^~\[\]`]+\.(?:jpg|jpeg|png|webp|gif)(?:\?[^\s<>"{}|\^~\[\]`]*)?', caseSensitive: false).firstMatch(desc);
    if (match != null) return match.group(0)!;
    final matchAnyUrl = RegExp(r'https?://images\.unsplash\.com/[^\s<>"{}|\^~\[\]`]+').firstMatch(desc);
    if (matchAnyUrl != null) return matchAnyUrl.group(0)!;
    return '';
  }

  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredAnimals = [];
  List<Map<String, dynamic>> _filteredThings = [];
  int _currentPageIndex = 0; // 0 = Питомцы, 1 = Вещи и документы

  late final PageController _pageController;
  late final PageController _animalsPageController;
  double _animalsPageViewOffset = 0.0;
  late final PageController _thingsPageController;
  double _thingsPageViewOffset = 0.0;

  late final ConfettiController _confettiController;
  late final AnimationController _pulseBtnController;
  int _totalThisMonth = 0;
  int _resolvedThisMonth = 0;
  double _successRate = 0.0;

  @override
  void initState() {
    super.initState();
    SoundService().playLostFound();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _pageController = PageController(initialPage: 0);

    _pulseBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _animalsPageController = PageController(viewportFraction: 0.86, initialPage: 0);
    _animalsPageController.addListener(() {
      final p = _animalsPageController.page ?? 0.0;
      if ((p - _animalsPageViewOffset).abs() > 0.08) {
        _animalsPageViewOffset = p;
      }
    });

    _thingsPageController = PageController(viewportFraction: 0.86, initialPage: 0);
    _thingsPageController.addListener(() {
      final p = _thingsPageController.page ?? 0.0;
      if ((p - _thingsPageViewOffset).abs() > 0.08) {
        _thingsPageViewOffset = p;
      }
    });

    _loadData();
  }

  @override
  void dispose() {
    _pulseBtnController.dispose();
    _confettiController.dispose();
    _pageController.dispose();
    _animalsPageController.dispose();
    _thingsPageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final cached = await _getCachedData();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _allItems = cached;
        _applyFilters();
        _calcStatistics();
      });
    }

    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/reports?city=nizhnevartovsk&limit=100');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(resp.bodyBytes));
        final items = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final lostItems = items.where((it) {
          final cat = (it['category'] ?? '').toString();
          return cat == 'Животные' || cat == 'Вещи' || cat.contains('животн') || cat.contains('вещ') || cat.contains('Потер') || cat.contains('Найден');
        }).toList();

        if (lostItems.isNotEmpty) {
          await _saveCache(lostItems);
          if (mounted) {
            setState(() {
              _allItems = lostItems;
              _applyFilters();
              _calcStatistics();
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (_allItems.isEmpty) {
      final fallback = _generateCuratedMockItems();
      await _saveCache(fallback);
      if (mounted) {
        setState(() {
          _allItems = fallback;
          _applyFilters();
          _calcStatistics();
        });
      }
    }
  }

  void _calcStatistics() {
    int total = _allItems.length;
    int resolved = _allItems.where((i) => (i['status'] ?? '').toString().toLowerCase() == 'resolved').length;
    if (total == 0) {
      total = 14;
      resolved = 11;
    }
    setState(() {
      _totalThisMonth = total;
      _resolvedThisMonth = resolved;
      _successRate = total > 0 ? (resolved / total) * 100 : 80.0;
    });
  }

  Future<List<Map<String, dynamic>>> _getCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_complaintsCachePrefKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveCache(List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_complaintsCachePrefKey, jsonEncode(items));
    } catch (_) {}
  }

  List<Map<String, dynamic>> _generateCuratedMockItems() {
    return [
      {
        'id': 'mock_animal_1',
        'title': 'Найден молодой Хаски с голубыми глазами',
        'category': 'Животные',
        'address': 'Комсомольский бульвар, д. 5',
        'description': 'Бегал около сквера Космонавтов, в черном тканевом ошейнике без бирки. Очень контактный и ухоженный, временно приютили в кв. 14.',
        'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'image_url': 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&q=80&w=800',
        'status': 'open',
        'contact': '+7 (912) 938-44-12',
        'reward': 'Ищу хозяина',
        'lat': 60.9385,
        'lng': 76.5620,
      },
      {
        'id': 'mock_animal_2',
        'title': 'Потерялся шотландский вислоухий кот Маркиз',
        'category': 'Животные',
        'address': 'ул. Ленина, 15 (16 микрорайон)',
        'description': 'Окрас серый табби, янтарные глаза. Выскочил в приоткрытую дверь подъезда №2. Вознаграждение нашедшему гарантируется!',
        'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
        'image_url': 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&q=80&w=800',
        'status': 'open',
        'contact': '+7 (922) 401-88-99',
        'reward': 'Вознаграждение 5 000 ₽',
        'lat': 60.9412,
        'lng': 76.5840,
      },
      {
        'id': 'mock_animal_3',
        'title': 'Найден рыжий пушистый щенок корги',
        'category': 'Животные',
        'address': 'Парк Победы (у центрального фонтана)',
        'description': 'Сидел на скамейке возле аллеи Героев. В кожаном ошейнике с колокольчиком. Отзовитесь, хозяева!',
        'created_at': DateTime.now().subtract(const Duration(hours: 9)).toIso8601String(),
        'image_url': 'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&q=80&w=800',
        'status': 'resolved',
        'contact': '+7 (904) 882-11-55',
        'reward': 'Возвращен хозяину',
        'lat': 60.9360,
        'lng': 76.5590,
      },
      {
        'id': 'mock_thing_1',
        'title': 'Найден iPhone 15 Pro в синем чехле MagSafe',
        'category': 'Вещи',
        'address': 'Набережная р. Обь (у памятника Защитникам Отечества)',
        'description': 'Лежал на парапете смотровой площадки. Телефон заряжен, включен, на заставке фото набережной. Верну владельцу при разблокировке паролем.',
        'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'image_url': 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?auto=format&fit=crop&q=80&w=800',
        'status': 'open',
        'contact': '+7 (982) 534-77-01',
        'reward': 'Бесплатно владельцу',
        'lat': 60.9280,
        'lng': 76.5710,
      },
      {
        'id': 'mock_thing_2',
        'title': 'Потеряна связка ключей от авто Hyundai с брелоком StarLine',
        'category': 'Вещи',
        'address': 'ТЦ «Югра Молл» (парковка со стороны ул. Ленина)',
        'description': 'На связке выкидной ключ, брелок сигнализации StarLine и кожаный плетеный ремешок. Нашедшему огромная благодарность и вознаграждение.',
        'created_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
        'image_url': 'https://images.unsplash.com/photo-1582139329536-e7284fece509?auto=format&fit=crop&q=80&w=800',
        'status': 'open',
        'contact': '+7 (912) 555-01-92',
        'reward': 'Вознаграждение 3 000 ₽',
        'lat': 60.9420,
        'lng': 76.5910,
      },
      {
        'id': 'mock_thing_3',
        'title': 'Найден портмоне с водительским удостоверением',
        'category': 'Вещи',
        'address': 'ул. Мира, д. 60 (остановка «Сити Молл»)',
        'description': 'Черный кожаный кошелек с документами на имя Смирнова А.В., карта Газпромбанк. Передан в диспетчерскую.',
        'created_at': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
        'image_url': 'https://images.unsplash.com/photo-1627123424574-724758594e93?auto=format&fit=crop&q=80&w=800',
        'status': 'resolved',
        'contact': '+7 (902) 853-22-11',
        'reward': 'Возвращено владельцу',
        'lat': 60.9450,
        'lng': 76.5820,
      },
    ];
  }

  void _applyFilters() {
    final animals = <Map<String, dynamic>>[];
    final things = <Map<String, dynamic>>[];

    for (final item in _allItems) {
      final cat = (item['category'] ?? '').toString();
      final isAnimal = cat == 'Животные' || cat.contains('животн') || cat.contains('Питом');

      if (isAnimal) {
        animals.add(item);
      } else {
        things.add(item);
      }
    }

    setState(() {
      _filteredAnimals = animals;
      _filteredThings = things;
    });
  }

  Future<void> _openAddFindingSheet(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final res = await AddFindingSheet.show(context);
    if (res == true && mounted) {
      _loadData();
      _confettiController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4), width: 1),
              ),
              child: const Icon(Icons.travel_explore_rounded, color: Color(0xFF00E5FF), size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'БЮРО НАХОДОК',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                ),
                Text(
                  'Нижневартовск • Поиск по фото и радар',
                  style: TextStyle(fontSize: 9.5, color: Colors.white60, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Анимированная пульсирующая кнопка «➕ Нашел / Потерял» в шапке
          AnimatedBuilder(
            animation: _pulseBtnController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseBtnController.value * 0.06);
              return Transform.scale(
                scale: scale,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withOpacity(0.4 + _pulseBtnController.value * 0.3),
                        blurRadius: 10 + _pulseBtnController.value * 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => _openAddFindingSheet(context),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Нашел/Потерял',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: const Color(0xFF070B14).withOpacity(0.75)),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF070B14), Color(0xFF0F172A), Color(0xFF0B132B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppleSegmentedHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentPageIndex = idx;
                    });
                  },
                  children: [
                    _buildCarouselView(_filteredAnimals, _animalsPageController, _animalsPageViewOffset, isAnimals: true),
                    _buildCarouselView(_filteredThings, _thingsPageController, _thingsPageViewOffset, isAnimals: false),
                  ],
                ),
              ),
              // Разворачиваемый интерактивный гео-радар с радиусом до 5 км
              LostFoundGeoRadar(
                address: 'Нижневартовск • Соседние микрорайоны',
                activeSearchesCount: _currentPageIndex == 0 ? _filteredAnimals.length : _filteredThings.length,
                onSendAlert: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppleSegmentedHeader() {
    final percentage = _successRate.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Apple Style Liquid Glass Tabs (Премиальные капсульные вкладки)
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
            ),
            child: Row(
              children: [
                {
                  'title': '🐾 ПИТОМЦЫ',
                  'count': _filteredAnimals.length,
                  'index': 0,
                  'color1': const Color(0xFFF59E0B),
                  'color2': const Color(0xFF10B981),
                },
                {
                  'title': '🔑 ВЕЩИ И ДОКУМЕНТЫ',
                  'count': _filteredThings.length,
                  'index': 1,
                  'color1': const Color(0xFF00E5FF),
                  'color2': const Color(0xFF8B5CF6),
                },
              ].map((tab) {
                final idx = tab['index'] as int;
                final isSelected = _currentPageIndex == idx;
                final count = tab['count'] as int;
                final c1 = tab['color1'] as Color;
                final c2 = tab['color2'] as Color;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _pageController.animateToPage(
                        idx,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutQuart,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [c1, c2],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: c1.withOpacity(0.40),
                                  blurRadius: 14,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tab['title'] as String,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: isSelected ? Colors.black : const Color(0xFF00E5FF),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Mini statistics bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                  const SizedBox(width: 5),
                  Text(
                    'Возвращено владельцам: $percentage%',
                    style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Text(
                'Нижневартовск • 24/7 Поиск',
                style: TextStyle(color: Colors.white38, fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselView(
    List<Map<String, dynamic>> items,
    PageController controller,
    double pageOffset, {
    required bool isAnimals,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAnimals ? Icons.pets_rounded : Icons.inventory_2_outlined,
              size: 56,
              color: Colors.white24,
            ),
            const SizedBox(height: 14),
            const Text(
              'Нет объявлений в этой категории',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Нажмите «Нашел/Потерял» вверху, чтобы подать заявку!',
              style: TextStyle(color: Colors.white54, fontSize: 11.5),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: controller,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isResolved = (item['status'] ?? '').toString().toLowerCase() == 'resolved';
        final title = item['title']?.toString() ?? 'Объявление';
        final address = item['address']?.toString() ?? 'Нижневартовск';
        final desc = item['description']?.toString() ?? '';
        var imageUrl = _extractImageUrl(item);
        final category = item['category']?.toString() ?? (isAnimals ? 'Животные' : 'Вещи');
        final contact = item['contact']?.toString() ?? '';
        final reward = item['reward']?.toString() ?? (isResolved ? 'Возвращено' : 'На связи');

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _showFindingDetailModal(context, item);
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF131D31).withOpacity(0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isResolved ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFF00E5FF).withOpacity(0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isResolved ? const Color(0xFF10B981) : const Color(0xFF00E5FF)).withOpacity(0.12),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Фото карточки
                Expanded(
                  flex: 11,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FindingImage(
                        url: imageUrl,
                        category: category,
                        title: title,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: Colors.black26,
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFF00E5FF), strokeWidth: 2),
                          ),
                        ),
                      ),
                      // Status Badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isResolved ? const Color(0xFF10B981) : const Color(0xFF00E5FF)).withOpacity(0.92),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isResolved ? Icons.check_circle_rounded : Icons.search_rounded,
                                color: isResolved ? Colors.white : Colors.black,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isResolved ? 'ВОЗВРАЩЕНО' : 'АКТИВНЫЙ ПОИСК',
                                style: TextStyle(
                                  color: isResolved ? Colors.white : Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Reward Badge
                      if (reward.isNotEmpty)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withOpacity(0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFD54F), width: 1),
                            ),
                            child: Text(
                              reward,
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Описание и контакты
                Expanded(
                  flex: 9,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, color: Color(0xFF00E5FF), size: 12),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5, height: 1.3),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        // Кнопка связи
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E5FF).withOpacity(0.18),
                                  foregroundColor: const Color(0xFF00E5FF),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  if (contact.isNotEmpty) {
                                    final clean = contact.replaceAll(RegExp(r'[^\d+]'), '');
                                    launchUrl(Uri.parse('tel:$clean'));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Контакт указан в описании объявления')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                                label: Text(
                                  contact.isNotEmpty ? 'Позвонить: $contact' : 'Связаться с нашедшим',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

  void _showFindingDetailModal(BuildContext context, Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? 'Объявление Бюро Находок';
    final address = item['address']?.toString() ?? 'Нижневартовск';
    final desc = item['description']?.toString() ?? '';
    final imageUrl = item['image_url']?.toString() ?? '';
    final category = item['category']?.toString() ?? 'Находка';
    final contact = item['contact']?.toString() ?? '+7 (3466) 63-11-12';
    final isResolved = (item['status'] ?? '').toString().toLowerCase() == 'resolved';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0xFF00E5FF), width: 1.5)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: FindingImage(
                            url: imageUrl,
                            category: category,
                            title: title,
                            fit: BoxFit.cover,
                            placeholder: Container(color: Colors.black26),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isResolved ? const Color(0xFF10B981) : const Color(0xFF00E5FF)).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isResolved ? const Color(0xFF10B981) : const Color(0xFF00E5FF)),
                          ),
                          child: Text(
                            isResolved ? '✅ НАЙДЕНО / ВОЗВРАЩЕНО' : '🔍 АКТИВНЫЙ ПОИСК',
                            style: TextStyle(
                              color: isResolved ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(category, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Color(0xFF00E5FF), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(address, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('ПОДРОБНОЕ ОПИСАНИЕ:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    const SizedBox(height: 6),
                    Text(desc.isNotEmpty ? desc : 'Описание отсутствует.', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13.5, height: 1.4)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('КОНТАКТЫ ДЛЯ СВЯЗИ:', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                          const SizedBox(height: 8),
                          SelectableText(
                            contact,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5FF),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                final clean = contact.replaceAll(RegExp(r'[^\d+]'), '');
                                if (clean.isNotEmpty) {
                                  launchUrl(Uri.parse('tel:$clean'));
                                }
                              },
                              icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                              label: const Text('Связаться прямо сейчас', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
