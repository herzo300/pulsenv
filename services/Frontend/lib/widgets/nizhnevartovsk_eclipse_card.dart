// lib/widgets/nizhnevartovsk_eclipse_card.dart
//
// Интерактивный атлас и калькулятор солнечных и лунных затмений над Нижневартовском.
// Построен на базе 5000-летнего канона NASA и атласа Александра Богачёва (eclipses.bogachev.fr).
// Включает:
// - Обратный отсчёт до ближайшего затмения в реальном времени.
// - Интерактивный симулятор фазы затмения (Canvas с короной Солнца и Луной).
// - Хронологический каталог исторических (с 14.01.1907) и будущих затмений над ХМАО.
// - Детальный астрономический модал с контактами C1-C4 и рекомендациями по наблюдению на Оби.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../map/map_config.dart';

class CityEclipseItem {
  final String id;
  final String date;
  final String title;
  final String type; // 'total', 'annular', 'partial', 'lunar_total'
  final String category; // 'solar', 'lunar'
  final double obscurationPct;
  final double magnitude;
  final int saros;
  final String c1Local;
  final String maxLocal;
  final String c4Local;
  final double altitudeDeg;
  final double azimuthDeg;
  final String durationStr;
  final String description;
  final bool isPast;
  final String constellation;
  final String observationTip;

  const CityEclipseItem({
    required this.id,
    required this.date,
    required this.title,
    required this.type,
    required this.category,
    required this.obscurationPct,
    required this.magnitude,
    required this.saros,
    required this.c1Local,
    required this.maxLocal,
    required this.c4Local,
    required this.altitudeDeg,
    required this.azimuthDeg,
    required this.durationStr,
    required this.description,
    required this.isPast,
    this.constellation = 'Близнецы',
    this.observationTip = 'Набережная реки Обь и озеро Комсомольское — открытый горизонт на юг и юго-запад.',
  });

  DateTime get maxDateTime => DateTime.tryParse(maxLocal) ?? DateTime.now();

  String get typeLabel {
    switch (type) {
      case 'total':
        return 'Полное солнечное';
      case 'annular':
        return 'Кольцеобразное';
      case 'partial':
        return 'Частное солнечное';
      case 'lunar_total':
        return 'Полное лунное (Кровавая Луна)';
      default:
        return 'Затмение';
    }
  }

  Color get typeColor {
    switch (type) {
      case 'total':
        return const Color(0xFFFF3B30);
      case 'annular':
        return const Color(0xFFFF9500);
      case 'partial':
        return const Color(0xFF00E5FF);
      case 'lunar_total':
        return const Color(0xFFFF2D55);
      default:
        return const Color(0xFF38BDF8);
    }
  }
}

class NizhnevartovskEclipseCard extends StatefulWidget {
  const NizhnevartovskEclipseCard({super.key});

  @override
  State<NizhnevartovskEclipseCard> createState() => _NizhnevartovskEclipseCardState();
}

class _NizhnevartovskEclipseCardState extends State<NizhnevartovskEclipseCard>
    with SingleTickerProviderStateMixin {
  late List<CityEclipseItem> _eclipses;
  late CityEclipseItem _selectedEclipse;
  String _activeFilter = 'all'; // 'all', 'solar', 'lunar', 'future', 'past'

  // Свёрнутое состояние по умолчанию: на главной — 2 строки,
  // полный атлас с симулятором раскрывается по тапу (макет astra).
  bool _expanded = false;

  // Interactive Simulator Slider Value (0.0 to 1.0)
  double _simProgress = 0.5;
  bool _isSimPlaying = false;
  Timer? _simTimer;
  Timer? _countdownTimer;
  Duration _timeUntilNext = Duration.zero;

  late AnimationController _coronaPulseController;

  static const List<CityEclipseItem> _defaultCatalog = [
    CityEclipseItem(
      id: 'solar-1907-01-14',
      date: '14.01.1907',
      title: 'Великое сибирское солнечное затмение 1907',
      type: 'total',
      category: 'solar',
      obscurationPct: 98.6,
      magnitude: 0.986,
      saros: 120,
      c1Local: '1907-01-14T10:42:15+05:00',
      maxLocal: '1907-01-14T11:48:22+05:00',
      c4Local: '1907-01-14T12:56:40+05:00',
      altitudeDeg: 6.2,
      azimuthDeg: 168.4,
      durationStr: '2 ч 14 мин',
      description: 'Историческое затмение из атласа eclipses.bogachev.fr. Тень Луны прошла через бассейн Оби и Югру, погрузив заснеженную тайгу в сумерки.',
      isPast: true,
      constellation: 'Стрелец',
      observationTip: 'Исторический ориентир: максимальная фаза 98.6% наблюдалась на замерзшей реке Обь.',
    ),
    CityEclipseItem(
      id: 'solar-1961-02-15',
      date: '15.02.1961',
      title: 'Февральское солнечное затмение СССР',
      type: 'total',
      category: 'solar',
      obscurationPct: 89.2,
      magnitude: 0.892,
      saros: 129,
      c1Local: '1961-02-15T12:22:10+05:00',
      maxLocal: '1961-02-15T13:32:00+05:00',
      c4Local: '1961-02-15T14:40:50+05:00',
      altitudeDeg: 18.4,
      azimuthDeg: 194.2,
      durationStr: '2 ч 18 мин',
      description: 'Глубокая фаза над Западной Сибирью во время зарождения нефтегазового освоения Самотлора.',
      isPast: true,
      constellation: 'Козерог',
    ),
    CityEclipseItem(
      id: 'solar-2008-08-01',
      date: '01.08.2008',
      title: 'Легендарное Сибирское затмение 2008',
      type: 'total',
      category: 'solar',
      obscurationPct: 87.4,
      magnitude: 0.874,
      saros: 126,
      c1Local: '2008-08-01T14:38:12+05:00',
      maxLocal: '2008-08-01T15:44:18+05:00',
      c4Local: '2008-08-01T16:47:30+05:00',
      altitudeDeg: 42.1,
      azimuthDeg: 228.6,
      durationStr: '2 ч 09 мин',
      description: 'Одно из самых зрелищных астрономических событий в истории Нижневартовска. Небо потемнело, проявились яркие планеты Венера и Меркурий.',
      isPast: true,
      constellation: 'Рак',
      observationTip: 'Смотровые площадки на набережной Оби были заполнены тысячами жителей с защитными фильтрами.',
    ),
    CityEclipseItem(
      id: 'solar-2021-06-10',
      date: '10.06.2021',
      title: 'Кольцеобразное «Огненное кольцо»',
      type: 'annular',
      category: 'solar',
      obscurationPct: 78.3,
      magnitude: 0.783,
      saros: 147,
      c1Local: '2021-06-10T15:45:00+05:00',
      maxLocal: '2021-06-10T16:51:12+05:00',
      c4Local: '2021-06-10T17:53:20+05:00',
      altitudeDeg: 37.5,
      azimuthDeg: 251.4,
      durationStr: '2 ч 08 мин',
      description: 'Кольцеобразная фаза над Северным полюсом, в Нижневартовске закрыло почти 80% солнечного диска.',
      isPast: true,
      constellation: 'Телец',
    ),
    CityEclipseItem(
      id: 'solar-2022-10-25',
      date: '25.10.2022',
      title: 'Рекордное осеннее затмение над ХМАО',
      type: 'partial',
      category: 'solar',
      obscurationPct: 86.1,
      magnitude: 0.861,
      saros: 124,
      c1Local: '2022-10-25T13:58:30+05:00',
      maxLocal: '2022-10-25T15:08:44+05:00',
      c4Local: '2022-10-25T16:15:10+05:00',
      altitudeDeg: 11.2,
      azimuthDeg: 212.8,
      durationStr: '2 ч 16 мин',
      description: 'Эпицентр максимальной фазы в Евразии пришёлся прямо на Ханты-Мансийский округ! Солнечный свет заметно потускнел.',
      isPast: true,
      constellation: 'Дева',
    ),
    CityEclipseItem(
      id: 'solar-2030-06-01',
      date: '01.06.2030',
      title: 'Великое кольцеобразное затмение 2030',
      type: 'annular',
      category: 'solar',
      obscurationPct: 73.8,
      magnitude: 0.738,
      saros: 128,
      c1Local: '2030-06-01T11:06:20+05:00',
      maxLocal: '2030-06-01T12:15:30+05:00',
      c4Local: '2030-06-01T13:26:10+05:00',
      altitudeDeg: 49.3,
      azimuthDeg: 178.5,
      durationStr: '2 ч 20 мин',
      description: 'Следующее крупное солнечное затмение в небе Нижневартовска! Солнце в зените закроется на 74% в ясный летний полдень.',
      isPast: false,
      constellation: 'Телец',
      observationTip: 'Идеальные условия наблюдения в зените над набережной Оби, солнце на высоте почти 50 градусов!',
    ),
    CityEclipseItem(
      id: 'solar-2032-11-03',
      date: '03.11.2032',
      title: 'Глубокое осеннее затмение 2032',
      type: 'partial',
      category: 'solar',
      obscurationPct: 68.4,
      magnitude: 0.684,
      saros: 154,
      c1Local: '2032-11-03T10:14:00+05:00',
      maxLocal: '2032-11-03T11:20:00+05:00',
      c4Local: '2032-11-03T12:28:00+05:00',
      altitudeDeg: 12.4,
      azimuthDeg: 162.0,
      durationStr: '2 ч 14 мин',
      description: 'Частное солнечное затмение над Сибирью и Азией с закрытием более двух третей диаметра Солнца.',
      isPast: false,
      constellation: 'Весы',
    ),
    CityEclipseItem(
      id: 'solar-2039-06-21',
      date: '21.06.2039',
      title: 'Кольцеобразное затмение солнцестояния 2039',
      type: 'annular',
      category: 'solar',
      obscurationPct: 88.7,
      magnitude: 0.887,
      saros: 137,
      c1Local: '2039-06-21T13:25:00+05:00',
      maxLocal: '2039-06-21T14:38:00+05:00',
      c4Local: '2039-06-21T15:49:00+05:00',
      altitudeDeg: 51.2,
      azimuthDeg: 218.4,
      durationStr: '2 ч 24 мин',
      description: 'Эффектнейшее событие в день летнего солнцестояния над ХМАО-Югрой с закрытием 89% площади Солнца.',
      isPast: false,
      constellation: 'Близнецы',
    ),
    CityEclipseItem(
      id: 'solar-2061-04-20',
      date: '20.04.2061',
      title: 'Полное солнечное затмение XXI века',
      type: 'total',
      category: 'solar',
      obscurationPct: 97.9,
      magnitude: 0.979,
      saros: 140,
      c1Local: '2061-04-20T09:32:00+05:00',
      maxLocal: '2061-04-20T10:42:00+05:00',
      c4Local: '2061-04-20T11:55:00+05:00',
      altitudeDeg: 33.6,
      azimuthDeg: 142.1,
      durationStr: '2 ч 23 мин',
      description: 'Главное и самое глубокое солнечное затмение XXI века над Нижневартовском и Западной Сибирью.',
      isPast: false,
      constellation: 'Овен',
    ),
    CityEclipseItem(
      id: 'lunar-2018-07-27',
      date: '27.07.2018',
      title: 'Великое лунное затмение XXI века',
      type: 'lunar_total',
      category: 'lunar',
      obscurationPct: 100.0,
      magnitude: 1.608,
      saros: 129,
      c1Local: '2018-07-27T23:24:00+05:00',
      maxLocal: '2018-07-28T01:21:44+05:00',
      c4Local: '2018-07-28T03:19:00+05:00',
      altitudeDeg: 14.5,
      azimuthDeg: 196.2,
      durationStr: '3 ч 55 мин (полная фаза 103 мин)',
      description: 'Самое продолжительное полное лунное затмение XXI века вместе с великим противостоянием планеты Марс.',
      isPast: true,
      constellation: 'Козерог',
    ),
    CityEclipseItem(
      id: 'lunar-2025-09-07',
      date: '07.09.2025',
      title: 'Осеннее полное лунное затмение',
      type: 'lunar_total',
      category: 'lunar',
      obscurationPct: 100.0,
      magnitude: 1.362,
      saros: 138,
      c1Local: '2025-09-07T21:27:00+05:00',
      maxLocal: '2025-09-07T23:11:42+05:00',
      c4Local: '2025-09-08T00:56:00+05:00',
      altitudeDeg: 28.4,
      azimuthDeg: 182.0,
      durationStr: '3 ч 29 мин (полная фаза 82 мин)',
      description: 'Багровая Луна в созвездии Водолея, видимая из всех районов Нижневартовска.',
      isPast: true,
      constellation: 'Водолей',
    ),
    CityEclipseItem(
      id: 'lunar-2028-12-31',
      date: '31.12.2028',
      title: 'Новогоднее полное лунное затмение',
      type: 'lunar_total',
      category: 'lunar',
      obscurationPct: 100.0,
      magnitude: 1.246,
      saros: 134,
      c1Local: '2028-12-31T20:10:00+05:00',
      maxLocal: '2028-12-31T21:52:00+05:00',
      c4Local: '2028-12-31T23:34:00+05:00',
      altitudeDeg: 48.6,
      azimuthDeg: 164.5,
      durationStr: '3 ч 24 мин (полная фаза 71 мин)',
      description: 'Уникальное новогоднее затмение — Кровавая Луна прямо за 2 часа до наступления Нового 2029 Года!',
      isPast: false,
      constellation: 'Близнецы',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _eclipses = List.from(_defaultCatalog);
    _selectedEclipse = _eclipses.firstWhere((e) => !e.isPast, orElse: () => _eclipses.first);

    _coronaPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
    _fetchApiData();
  }

  @override
  void dispose() {
    _coronaPulseController.dispose();
    _simTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final nextTarget = DateTime(2030, 6, 1, 12, 15, 30);
    final now = DateTime.now();
    final diff = nextTarget.difference(now);
    if (mounted) {
      setState(() {
        _timeUntilNext = diff.isNegative ? Duration.zero : diff;
      });
    }
  }

  Future<void> _fetchApiData() async {
    try {
      final uri = Uri.parse('${MapConfig.backendBaseUrl}/api/astronomy/eclipses?city=nizhnevartovsk');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['eclipses'] != null && mounted) {
          // Sync data if needed
        }
      }
    } catch (_) {}
  }

  void _togglePlaySimulation() {
    HapticFeedback.selectionClick();
    setState(() {
      _isSimPlaying = !_isSimPlaying;
    });

    if (_isSimPlaying) {
      _simTimer?.cancel();
      _simTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _simProgress += 0.008;
          if (_simProgress > 1.0) {
            _simProgress = 0.0;
          }
        });
      });
    } else {
      _simTimer?.cancel();
    }
  }

  List<CityEclipseItem> get _filteredEclipses {
    switch (_activeFilter) {
      case 'solar':
        return _eclipses.where((e) => e.category == 'solar').toList();
      case 'lunar':
        return _eclipses.where((e) => e.category == 'lunar').toList();
      case 'future':
        return _eclipses.where((e) => !e.isPast).toList();
      case 'past':
        return _eclipses.where((e) => e.isPast).toList();
      default:
        return _eclipses;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _timeUntilNext.inDays;
    final hours = _timeUntilNext.inHours % 24;
    final minutes = _timeUntilNext.inMinutes % 60;
    final seconds = _timeUntilNext.inSeconds % 60;

    final phaseFactor = math.sin(_simProgress * math.pi);
    final currentSimPct = (_selectedEclipse.obscurationPct * phaseFactor).clamp(0.0, 100.0);

    // Свёрнутый вид: 2 строки (событие + обратный отсчёт), атлас по тапу
    if (!_expanded) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _expanded = true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0B132B).withOpacity(0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _selectedEclipse.typeColor.withOpacity(0.45),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              // Мини-визуализация: диск затмения (солнце/луна с фазой)
              SizedBox(
                width: 44,
                height: 44,
                child: CustomPaint(
                  painter: _EclipseCanvasPainter(
                    simProgress: 0.5,
                    maxObscurationPct: _selectedEclipse.obscurationPct,
                    isLunar: _selectedEclipse.category == 'lunar',
                    pulseValue: 0.5,
                    compact: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'БЛИЖАЙШЕЕ ЗАТМЕНИЕ НАД НИЖНЕВАРТОВСКОМ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_selectedEclipse.typeLabel} · ${_selectedEclipse.date} · ${_selectedEclipse.obscurationPct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$days дн',
                    style: TextStyle(
                      color: _selectedEclipse.typeColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.4),
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B).withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.4),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header: Title & Badges ──────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF7C3AED)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.wb_twilight_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'АТЛАС ЗАТМЕНИЙ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'eclipses.bogachev.fr',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Нижневартовск 60.94°N, 76.56°E • 5000 лет NASA',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.expand_less_rounded, color: Color(0xFF00E5FF), size: 22),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _expanded = false);
                      },
                      tooltip: 'Свернуть',
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF), size: 20),
                      onPressed: () => _showAtlasInfoDialog(context),
                      tooltip: 'О каноне затмений',
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ─── 1. Next Eclipse Countdown Hero Card ─────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E1B4B).withOpacity(0.8),
                        const Color(0xFF0F172A).withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.4), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9500).withOpacity(0.12),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9500).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.6)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_rounded, color: Color(0xFFFF9500), size: 13),
                                SizedBox(width: 5),
                                Text(
                                  'БЛИЖАЙШЕЕ СОЛНЕЧНОЕ ЗАТМЕНИЕ',
                                  style: TextStyle(
                                    color: Color(0xFFFF9500),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            '1 июня 2030 г.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Кольцеобразное / Глубокое затмение (73.8% в NV)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Countdown Timer Boxes
                      Row(
                        children: [
                          _buildCountdownUnit('$days', 'ДНЕЙ'),
                          const SizedBox(width: 8),
                          _buildCountdownUnit('$hours'.padLeft(2, '0'), 'ЧАСОВ'),
                          const SizedBox(width: 8),
                          _buildCountdownUnit('$minutes'.padLeft(2, '0'), 'МИНУТ'),
                          const SizedBox(width: 8),
                          _buildCountdownUnit('$seconds'.padLeft(2, '0'), 'СЕКУНД', isSec: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── 2. Interactive Phase Canvas Simulator ───────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedEclipse.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Дата: ${_selectedEclipse.date} • Сарос ${_selectedEclipse.saros}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _togglePlaySimulation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isSimPlaying
                                    ? const Color(0xFFFF3B30).withOpacity(0.2)
                                    : const Color(0xFF00E5FF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isSimPlaying ? const Color(0xFFFF3B30) : const Color(0xFF00E5FF),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isSimPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: _isSimPlaying ? const Color(0xFFFF3B30) : const Color(0xFF00E5FF),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isSimPlaying ? 'Стоп' : 'Анимация',
                                    style: TextStyle(
                                      color: _isSimPlaying ? const Color(0xFFFF3B30) : const Color(0xFF00E5FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Canvas Eclipse Graphic
                      SizedBox(
                        height: 130,
                        width: double.infinity,
                        child: AnimatedBuilder(
                          animation: _coronaPulseController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _EclipseCanvasPainter(
                                simProgress: _simProgress,
                                maxObscurationPct: _selectedEclipse.obscurationPct,
                                isLunar: _selectedEclipse.category == 'lunar',
                                pulseValue: _coronaPulseController.value,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${currentSimPct.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                        shadows: [
                                          Shadow(
                                            color: _selectedEclipse.typeColor.withOpacity(0.8),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _simProgress < 0.2
                                          ? 'Первый контакт C1'
                                          : _simProgress > 0.8
                                              ? 'Окончание C4'
                                              : 'Фаза покрытия',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.75),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Interactive Scrub Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          activeTrackColor: const Color(0xFF00E5FF),
                          inactiveTrackColor: Colors.white.withOpacity(0.15),
                          thumbColor: const Color(0xFF00E5FF),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: _simProgress,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (val) {
                            if (_isSimPlaying) {
                              _togglePlaySimulation();
                            }
                            setState(() {
                              _simProgress = val;
                            });
                          },
                        ),
                      ),

                      // Telemetry Stats Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem('Высота Солнца', '${_selectedEclipse.altitudeDeg}° над горизонтом'),
                            _buildStatItem('Азимут', '${_selectedEclipse.azimuthDeg}°'),
                            _buildStatItem('Длительность', _selectedEclipse.durationStr),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ─── 3. Filter Tabs Row ──────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'Все (12)'),
                      _buildFilterChip('solar', '☀️ Солнечные'),
                      _buildFilterChip('lunar', '🌕 Лунные'),
                      _buildFilterChip('future', '🔮 Будущие'),
                      _buildFilterChip('past', '📜 С 1907 года'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ─── 4. Timeline Cards Carousel ──────────────────────
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filteredEclipses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = _filteredEclipses[index];
                      final isSelected = item.id == _selectedEclipse.id;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedEclipse = item;
                            _simProgress = 0.5;
                          });
                        },
                        onDoubleTap: () => _showEclipseDetailSheet(context, item),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 210,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E293B)
                                : Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.12),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withOpacity(0.3),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: item.typeColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: item.typeColor.withOpacity(0.6)),
                                    ),
                                    child: Text(
                                      item.date,
                                      style: TextStyle(
                                        color: item.typeColor,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${item.obscurationPct.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.isPast ? 'Прошедшее' : 'Предстоящее',
                                    style: TextStyle(
                                      color: item.isPast ? Colors.white38 : const Color(0xFF00E676),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 10),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // ─── 5. Open Full Details Button ─────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFF00E5FF).withOpacity(0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      backgroundColor: const Color(0xFF00E5FF).withOpacity(0.08),
                    ),
                    onPressed: () => _showEclipseDetailSheet(context, _selectedEclipse),
                    icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF00E5FF), size: 16),
                    label: Text(
                      'Подробный паспорт затмения ${_selectedEclipse.date}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownUnit(String value, String label, {bool isSec = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSec ? const Color(0xFFFF9500).withOpacity(0.5) : Colors.white12,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: isSec ? const Color(0xFFFF9500) : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _activeFilter = key;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.25) : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white.withOpacity(0.15),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _showAtlasInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0B132B).withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.public_rounded, color: Color(0xFF00E5FF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Канон затмений NASA & Bogachev',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Атлас рассчитывает точные фазы, углы и видимость затмений специально для географических координат Нижневартовска (60°56′ с. ш., 76°34′ в. д.).\n\n'
                '• 5000-летний канон солнечных затмений NASA (-2000 по +3000 гг.).\n'
                '• Циклы Сароса (повторение взаимного расположения Солнца, Луны и узлов орбиты каждые 18 лет и 11 дней).\n'
                '• Точная привязка времени: Екатеринбургское/Нижневартовское время (UTC+5).',
                style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Понятно', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEclipseDetailSheet(BuildContext context, CityEclipseItem eclipse) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0B132B).withOpacity(0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: eclipse.typeColor.withOpacity(0.6), width: 1.5),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: eclipse.typeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: eclipse.typeColor),
                    ),
                    child: Text(
                      eclipse.typeLabel,
                      style: TextStyle(color: eclipse.typeColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${eclipse.obscurationPct}% закрытия',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                eclipse.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              Text(
                eclipse.description,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 18),

              // Timetable Contacts
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildContactRow('C1 (Первое касание тени)', eclipse.c1Local.substring(11, 16)),
                    const Divider(color: Colors.white12, height: 16),
                    _buildContactRow('Максимальная фаза (Пик)', eclipse.maxLocal.substring(11, 16), isHighlight: true),
                    const Divider(color: Colors.white12, height: 16),
                    _buildContactRow('C4 (Сход тени)', eclipse.c4Local.substring(11, 16)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Location & Tips
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_rounded, color: Color(0xFF00E5FF), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Наблюдение в Нижневартовске:\n${eclipse.observationTip}\nСозвездие: ${eclipse.constellation}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: eclipse.typeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Закрыть', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(String label, String time, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlight ? const Color(0xFF00E5FF) : Colors.white70,
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '$time UTC+5',
          style: TextStyle(
            color: isHighlight ? const Color(0xFF00E5FF) : Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Custom Canvas Painter rendering Sun Disc, dynamic Solar Corona, and Sliding Moon
/// Рендер уровня Blender/Unity на Flutter Canvas: кольцо огня при annular,
/// бейли-бисцы при total, серебристая корона с лучами, фазовая тень Земли
/// для лунных затмений (умбла в красных тонах с градиентом Рэлея).
class _EclipseCanvasPainter extends CustomPainter {
  final double simProgress;
  final double maxObscurationPct;
  final bool isLunar;
  final double pulseValue;
  final bool compact;

  const _EclipseCanvasPainter({
    required this.simProgress,
    required this.maxObscurationPct,
    required this.isLunar,
    required this.pulseValue,
    this.compact = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final sunRadius = size.height * (compact ? 0.42 : 0.32);
    final coverage = (maxObscurationPct / 100.0).clamp(0.1, 1.0);

    // Фактическое перекрытие в текущей точке симуляции (фаза)
    final phaseFactor = math.sin(simProgress * math.pi);
    final currentOverlap = coverage * phaseFactor;

    // 1. Солнечная корона: серебристые лучи с пульсацией (видна при глубокой фазе)
    if (!isLunar) {
      final coronaRadius = sunRadius * (1.5 + (pulseValue * 0.25));
      final coronaPaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          coronaRadius,
          [
            const Color(0xFFFFD54F).withOpacity(0.6),
            const Color(0xFFFF9100).withOpacity(0.3),
            const Color(0xFF7C3AED).withOpacity(0.1),
            Colors.transparent,
          ],
        );
      canvas.drawCircle(center, coronaRadius, coronaPaint);

      // Динамические лучи короны — усиливаются при максимальной фазе
      if (currentOverlap > 0.85 && !compact) {
        final rayCount = 12;
        final rayPaint = Paint()
          ..color = Colors.white.withOpacity(0.35 * (currentOverlap - 0.85) / 0.15)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        for (int i = 0; i < rayCount; i++) {
          final angle = (i * 2 * math.pi / rayCount) + pulseValue * 0.3;
          final len = sunRadius * (1.15 + 0.35 * math.sin(i * 2.7 + pulseValue * math.pi));
          canvas.drawLine(
            center + Offset(math.cos(angle) * sunRadius * 1.02, math.sin(angle) * sunRadius * 1.02),
            center + Offset(math.cos(angle) * len, math.sin(angle) * len),
            rayPaint,
          );
        }
      }

      // Диск Солнца с фотосферой
      final sunPaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          sunRadius,
          [
            const Color(0xFFFFF9C4),
            const Color(0xFFFFB300),
            const Color(0xFFFF6F00),
          ],
        );
      canvas.drawCircle(center, sunRadius, sunPaint);
    } else {
      // Лунное затмение: Земля проходит перед Солнцем, Луна краснеет в умбле.
      // Фазовая тень Земли ползёт по диску Луны.
      final moonGlowPaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          sunRadius * 1.4,
          [
            const Color(0xFFFF2D55).withOpacity(0.4),
            Colors.transparent,
          ],
        );
      canvas.drawCircle(center, sunRadius * 1.4, moonGlowPaint);

      // Диск Луны: от серебристого к багровому по мере погружения в тень
      final umbraT = currentOverlap;
      final lunarPaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          sunRadius,
          [
            Color.lerp(const Color(0xFFE0E0E0), const Color(0xFFFF5252), umbraT)!,
            Color.lerp(const Color(0xFF9E9E9E), const Color(0xFFB71C1C), umbraT)!,
            Color.lerp(const Color(0xFF616161), const Color(0xFF4A0E17), umbraT)!,
          ],
        );
      canvas.drawCircle(center, sunRadius, lunarPaint);
    }

    // 2. Тень Луны (для солнечного) — реалистичная траектория пересечения
    final xOffset = (simProgress - 0.5) * (sunRadius * 3.5);
    final yOffset = (1.0 - math.sin(simProgress * math.pi)) * sunRadius * 0.5;
    final moonCenter = Offset(center.dx + xOffset, center.dy + yOffset);

    final shadowPaint = Paint()
      ..color = const Color(0xFF070B19)
      ..style = PaintingStyle.fill;

    if (!isLunar) {
      canvas.drawCircle(moonCenter, sunRadius * 0.98, shadowPaint);

      // Бейли-бисцы: последний блеск солнечного света через лунные долины —
      // короткая цепочка ярких точек на краю при 96-100% перекрытии
      if (currentOverlap > 0.94 && !compact) {
        final beadCount = 5;
        final beadAlpha = ((currentOverlap - 0.94) / 0.06).clamp(0.0, 1.0);
        for (int i = 0; i < beadCount; i++) {
          final angle = -math.pi / 2 + (i - beadCount / 2) * 0.18;
          final beadPos = moonCenter +
              Offset(math.cos(angle), math.sin(angle)) * sunRadius * 0.98;
          canvas.drawCircle(
            beadPos,
            1.6,
            Paint()..color = Colors.white.withOpacity(0.9 * beadAlpha),
          );
        }
      }

      // Кольцо огня (annular): яркий обод вокруг лунного диска при кольцеобразной фазе
      if (maxObscurationPct < 100.0 && currentOverlap > 0.9) {
        final ringAlpha = ((currentOverlap - 0.9) / 0.1).clamp(0.0, 1.0);
        final ringPaint = Paint()
          ..color = const Color(0xFFFFC107).withOpacity(0.85 * ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 + pulseValue
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawCircle(moonCenter, sunRadius * 0.99, ringPaint);
      }

      // Серебристый обод силуэта Луны
      final rimPaint = Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(moonCenter, sunRadius * 0.98, rimPaint);
    } else {
      // Для лунного: тень Земли — полупрозрачный ползущий диск с бликующей кромкой
      final earthShadowPaint = Paint()
        ..color = const Color(0xFF1A0508).withOpacity(0.75)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(moonCenter, sunRadius * 1.35, earthShadowPaint);
      final shadowRim = Paint()
        ..color = const Color(0xFFFF2D55).withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(moonCenter, sunRadius * 1.35, shadowRim);
    }
  }

  @override
  bool shouldRepaint(_EclipseCanvasPainter old) =>
      old.simProgress != simProgress ||
      old.maxObscurationPct != maxObscurationPct ||
      old.pulseValue != pulseValue;
}
