import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../core/app_router.dart';
import '../map/map_config.dart';
import '../services/notification_catalog.dart';
import '../services/city_provider.dart';
import '../services/sound_service.dart';
import '../theme/pulse_colors.dart';
import '../theme/pulse_categories.dart';
import '../utils/situation_helper.dart';
import '../widgets/app_ui.dart';
import '../widgets/dynamic_animated_background.dart';
import '../widgets/hologram_effect.dart';
import '../widgets/category_icon_3d.dart';
import 'dart:ui';
import '../widgets/premium/index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/aura_living_background.dart';
import '../core/living/aura_living_engine.dart';

class AiDigestScreen extends StatefulWidget {
  const AiDigestScreen({super.key});

  @override
  State<AiDigestScreen> createState() => _AiDigestScreenState();
}

class _AiDigestScreenState extends State<AiDigestScreen> {
  bool _isLoading = true;
  String _summary = '';
  bool _isVip = false;
  int _totalReports = 0;
  List<dynamic> _preview = [];
  String _error = '';
  String? _selectedCategory;
  bool _isSummaryExpanded = false;

  Color _selectedCategoryColor = const Color(0xFF130924);

  Color _getCategoryColor(String? category) {
    if (category == null) return const Color(0xFF130924);
    final normalized = NotificationCatalog.normalize(category);
    switch (normalized) {
      case 'Дороги':
      case 'road':
        return const Color(0xFFFFB300);
      case 'Освещение':
      case 'lighting':
        return const Color(0xFF00B0FF);
      case 'ЖКХ':
      case 'housing':
        return const Color(0xFF2979FF);
      case 'Двор':
      case 'yard':
        return const Color(0xFF00E676);
      case 'Мусор':
      case 'trash':
      case 'Экология':
        return const Color(0xFF1DE9B6);
      case 'Транспорт':
      case 'transport':
        return const Color(0xFFD500F9);
      case 'Безопасность':
      case 'safety':
        return const Color(0xFFFF1744);
      default:
        return const Color(0xFF7C4DFF);
    }
  }

  int _calculateCityPulseIndex() {
    int score = 100;
    for (final repo in _preview) {
      final cat = (repo['category'] ?? 'Прочее').toString().toUpperCase();
      if (cat.contains('ЧП') || cat.contains('БЕЗОПАСНОСТЬ')) {
        score -= 15;
      } else if (cat.contains('ЖКХ') || cat.contains('ДОРОГИ') || cat.contains('ДТП') || cat.contains('ПОЖАР')) {
        score -= 6;
      } else {
        score -= 3;
      }
    }
    return score.clamp(35, 100);
  }

  List<double> _generate24hPulseData(int currentHour, int finalPulseIndex) {
    final data = <double>[];
    for (int h = 0; h <= 24; h++) {
      final double sinVal = math.sin(h * 0.5) * 12;
      final double cosVal = math.cos(h * 0.8) * 8;
      double val = 85.0 + sinVal + cosVal;
      val = val.clamp(50, 100);
      data.add(val);
    }
    if (currentHour >= 0 && currentHour < data.length) {
      data[currentHour] = finalPulseIndex.toDouble();
    }
    return data.sublist(0, (currentHour + 1).clamp(1, 25));
  }

  @override
  void initState() {
    super.initState();
    SoundService().playDigestClick();
    _fetchDigest();
  }

  Future<void> _fetchDigest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isVip = prefs.getBool('is_premium_vip') ?? prefs.getBool('is_vip') ?? false;
      if (mounted) {
        setState(() {
          _isVip = isVip;
        });
      }
      final cityParam = CityProvider().activeCity.backendCityParam;
      final response = await http
          .get(Uri.parse('${MapConfig.backendApiBaseUrl}/daily-digest?city=$cityParam'))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          setState(() {
            _summary = data['ai_summary']?.toString().trim() ??
                'Сегодня в пабликах нет событий с точным адресом в городе.';
            _totalReports = data['total_reports'] is int
                ? data['total_reports'] as int
                : int.tryParse('${data['total_reports']}') ?? 0;
            
            final rawList = data['reports_preview'] is List
                ? List<dynamic>.from(data['reports_preview'] as List)
                : <dynamic>[];
            _preview = _deduplicateReports(rawList);

            if (_selectedCategory != null) {
              final newCats = _preview
                  .map((repo) => NotificationCatalog.normalize(repo['category']))
                  .toSet();
              if (!newCats.contains(_selectedCategory)) {
                _selectedCategory = null;
              }
            }
            _error = '';
            _isLoading = false;
          });
          return;
        }
        setState(() {
          _error = 'Сводка за день пока формируется. Попробуйте позже.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _error =
            'Сервер временно недоступен (${response.statusCode}). Попробуйте позже.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить сводку. Проверьте интернет и попробуйте снова.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Calculate category counts from active preview list
    final Map<String, int> categoryCounts = {};
    for (final report in _preview) {
      final category = (report['category'] ?? 'Прочее').toString();
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    return Stack(
      children: [
        if (_isVip)
          AuraLivingBackground(
            scene: AuraLivingEngine.resolve(
              mood: 5,
              streak: 5,
              meditationMinutes: 10,
              practicesCompleted: 5,
              isPremium: true,
              hour: DateTime.now().hour,
            ).copyWith(
              weather: AuraWeather.technoCivic,
            ),
            interactive: true,
            showConstellationVeil: false,
            child: const SizedBox.shrink(),
          )
        else
          const DynamicAnimatedBackground(forceAuroraVIP: true),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                _selectedCategoryColor.withOpacity(0.20),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: BackButton(
          color: PulseColors.textPrimary,
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.goNamed('map');
            }
          },
        ),
        title: Text(
          'AI Дайджест',
          style: TextStyle(
            color: PulseColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppScreenBackground(
        child: HologramEffect(
          isEnabled: true,
          showScanLine: false,
          child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off_rounded,
                                color: PulseColors.textSecondary, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _error,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: PulseColors.textSecondary),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _error = '';
                                });
                                _fetchDigest();
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Повторить'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : PulseRefresher(
                      onRefresh: _fetchDigest,
                      style: PulseRefreshStyle.bezier,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. ПОСЛЕДНИЕ СИГНАЛЫ (теперь на самом верху)
                            if (_preview.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_searching_rounded,
                                    color: PulseColors.textSecondary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ПОСЛЕДНИЕ СИГНАЛЫ',
                                    style: TextStyle(
                                      color: PulseColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ).animate().fade(delay: 100.ms, duration: 400.ms),
                              const SizedBox(height: 12),
                              (() {
                                final Map<String, int> categoriesMap = {};
                                for (final repo in _preview) {
                                  final cat = (repo['category'] ?? 'Прочее') as String;
                                  final normalized = NotificationCatalog.normalize(cat);
                                  categoriesMap[normalized] = (categoriesMap[normalized] ?? 0) + 1;
                                }

                                final filteredPreview = _preview.where((repo) {
                                  if (_selectedCategory == null) return true;
                                  final cat = (repo['category'] ?? 'Прочее') as String;
                                  return NotificationCatalog.normalize(cat) == _selectedCategory;
                                }).toList();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCategoryFilters(categoriesMap, scheme),
                                    if (filteredPreview.isEmpty)
                                      const SizedBox.shrink()
                                    else
                                      ...filteredPreview.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final repo = entry.value;
                                        final repoId = repo['id']?.toString() ?? repo.hashCode.toString();
                                        
                                        return Dismissible(
                                          key: Key('dismiss_$repoId'),
                                          direction: DismissDirection.horizontal,
                                          background: Container(
                                            margin: const EdgeInsets.only(bottom: 16),
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            alignment: Alignment.centerLeft,
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.85),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Icon(Icons.map_rounded, color: Colors.white, size: 28),
                                          ),
                                          secondaryBackground: Container(
                                            margin: const EdgeInsets.only(bottom: 16),
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            alignment: Alignment.centerRight,
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent.withOpacity(0.85),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
                                          ),
                                          confirmDismiss: (direction) async {
                                            if (direction == DismissDirection.startToEnd) {
                                              // Swipe right -> navigate to map
                                              final Map<String, String?> payload = {
                                                'id': repo['id']?.toString(),
                                                'lat': repo['lat']?.toString(),
                                                'lng': repo['lng']?.toString(),
                                                'category': repo['category']?.toString(),
                                                'address': repo['address']?.toString(),
                                                'description': repo['description']?.toString(),
                                                'title': repo['title']?.toString(),
                                              };
                                              AppRouter.goToMap(context: context, payload: payload);
                                              return false; // Slide back, don't remove from list
                                            }
                                            return true; // Swipe left -> delete
                                          },
                                          onDismissed: (direction) {
                                            if (direction == DismissDirection.endToStart) {
                                              final repoIndexInPreview = _preview.indexOf(repo);
                                              if (repoIndexInPreview != -1) {
                                                setState(() {
                                                  _preview.removeAt(repoIndexInPreview);
                                                });
                                              }
                                            }
                                          },
                                          child: _buildReportTile(repo, scheme)
                                              .animate()
                                              .fade(
                                                delay: (50 + index * 60).ms,
                                                duration: 400.ms,
                                              )
                                              .slideX(
                                                begin: 0.05,
                                                end: 0,
                                                curve: Curves.easeOutCubic,
                                              ),
                                        );
                                      }),
                                  ],
                                );
                              }()),
                            ],

                            const SizedBox(height: 32),

                            // 2. ДЕТАЛИ И ИНДЕКС ПУЛЬСА (остальное снизу)
                            AppPanel(
                              style: PanelStyle.aurora,
                              accent: PulseColors.primaryDeep,
                              showAuroraGlow: true,
                              padding: const EdgeInsets.all(0),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: -40,
                                    right: -40,
                                    child: Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 150,
                                      color: PulseColors.primary.withOpacity(0.05),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        (() {
                                           final pulseIndex = _calculateCityPulseIndex();
                                           return Row(
                                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                               Column(
                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                 children: [
                                                   Text(
                                                     'ИНДЕКС ГОРОДСКОГО ПУЛЬСА',
                                                     style: AppTextStyles.overline.copyWith(
                                                       color: PulseColors.primary,
                                                       fontWeight: FontWeight.bold,
                                                     ),
                                                   ),
                                                   const SizedBox(height: 4),
                                                   Row(
                                                     textBaseline: TextBaseline.alphabetic,
                                                     crossAxisAlignment: CrossAxisAlignment.baseline,
                                                     children: [
                                                       Text(
                                                         '$pulseIndex',
                                                         style: AppTextStyles.hero.copyWith(
                                                           fontSize: 48,
                                                         ),
                                                       ),
                                                       Text(
                                                         ' / 100',
                                                         style: AppTextStyles.bodyMuted.copyWith(
                                                           fontSize: 16,
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                   Text(
                                                     'основан на полной картине событий',
                                                     style: AppTextStyles.caption.copyWith(
                                                       fontSize: 11,
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                               CityPulseAnimation(pulseIndex: pulseIndex),
                                             ],
                                           );
                                         })(),
                                        // Note: DailyDigestChartWidget (pie chart) deleted here because categoryCounts duplications are already fully shown in category filters.
                                        const SizedBox(height: 20),
                                        (() {
                                          final pulseIndex = _calculateCityPulseIndex();
                                          final currentHour = DateTime.now().hour;
                                          final dataPoints = _generate24hPulseData(currentHour, pulseIndex);
                                          final Color chartColor = pulseIndex > 85
                                              ? const Color(0xFF00E676)
                                              : (pulseIndex > 65
                                                  ? const Color(0xFFFF9100)
                                                  : const Color(0xFFFF1744));
                                          return Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: PulseColors.surfaceGlass,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'СУТОЧНЫЙ ПУЛЬС ГОРОДА (24Ч)',
                                                  style: TextStyle(
                                                    color: PulseColors.textSecondary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.0,
                                                  ),
                                                ),
                                                const SizedBox(height: 14),
                                                PulseChartWidget(
                                                  dataPoints: dataPoints,
                                                  chartColor: chartColor,
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text('00:00', style: AppTextStyles.caption.copyWith(fontSize: 9)),
                                                    Text('06:00', style: AppTextStyles.caption.copyWith(fontSize: 9)),
                                                    Text('12:00', style: AppTextStyles.caption.copyWith(fontSize: 9)),
                                                    Text('18:00', style: AppTextStyles.caption.copyWith(fontSize: 9)),
                                                    Text('Текущий час ($currentHour:00)', style: AppTextStyles.caption.copyWith(fontSize: 9, color: chartColor, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        })(),
                                        const SizedBox(height: 16),
                                        DailyDigestStoriesWidget(
                                          summary: _summary,
                                          onCategorySelected: (category) {
                                            setState(() {
                                              _selectedCategory = category;
                                              _selectedCategoryColor = _getCategoryColor(category);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fade(duration: 500.ms).slideY(
                                  begin: 0.05,
                                  end: 0,
                                  curve: Curves.easeOutCubic,
                                ),
                          ],
                      ),
                    ),
                  ),
        ),
      ),
        ),
      ),
      ],
    );
  }

  Widget _buildCategoryFilters(Map<String, int> categoriesMap, ColorScheme scheme) {
    final defaultNames = NotificationCatalog.defaults.map((d) => d.name).toList();
    final categories = categoriesMap.keys.toList()
      ..sort((a, b) {
        final indexA = defaultNames.indexOf(a);
        final indexB = defaultNames.indexOf(b);
        if (indexA == -1 && indexB == -1) return a.compareTo(b);
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PulseColors.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PulseColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              (() {
                return _buildSquareCategoryButton(
                  label: 'Все',
                  icon: Icons.grid_view_rounded,
                  color: PulseColors.textSecondary,
                  count: _preview.length,
                  isSelected: _selectedCategory == null,
                  onTap: () {
                    SoundService().playDigestClick();
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                );
              }()),
              ...categories.map((category) {
                final count = categoriesMap[category] ?? 0;
                final isSelected = _selectedCategory == category;
                final descriptor = NotificationCatalog.describe(category);
 
                return _buildSquareCategoryButton(
                  label: category,
                  icon: descriptor.icon,
                  color: descriptor.color,
                  count: count,
                  isSelected: isSelected,
                  onTap: () {
                    SoundService().playDigestClick();
                    setState(() {
                      if (isSelected) {
                        _selectedCategory = null;
                      } else {
                        _selectedCategory = category;
                      }
                    });
                  },
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedCategory != null 
                    ? 'Категория: $_selectedCategory'
                    : 'Категория: Все происшествия',
                style: TextStyle(
                  color: _selectedCategory != null
                      ? NotificationCatalog.describe(_selectedCategory!).color
                      : PulseColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (_selectedCategory != null)
                Text(
                  '${categoriesMap[_selectedCategory] ?? 0} событий',
                  style: TextStyle(
                    color: PulseColors.textSecondary,
                    fontSize: 13,
                  ),
                )
              else
                Text(
                  '${_preview.length} событий',
                  style: TextStyle(
                    color: PulseColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquareCategoryButton({
    required String label,
    required IconData icon,
    required Color color,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected 
                  ? color.withOpacity(0.2) 
                  : PulseColors.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? color 
                    : PulseColors.border,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                )
              ] : [],
            ),
            child: Center(
              child: Icon(
                icon,
                color: isSelected ? color : PulseColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? color : PulseColors.border,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: PulseColors.background, // matching screen background color
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : PulseColors.textPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportTile(dynamic repo, ColorScheme scheme) {
    final category = (repo['category'] ?? 'Прочее') as String;
    final descriptor = NotificationCatalog.describe(category);
    final itemColor = descriptor.color;
    final title = repo['title'] ?? 'Без заголовка';
    final address = repo['address'] ?? repo['category'] ?? 'Без адреса';
    final descText = (repo['description'] ?? repo['summary'] ?? '').toString();
    final images = SituationHelper.extractImageUrls(repo);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          SoundService().playDigestClick();
          _showReportMiniWindow(repo, itemColor, descriptor);
        },
        borderRadius: AppRadii.lg,
        child: ClipRRect(
          borderRadius: AppRadii.lg,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: PulseColors.surface.withOpacity(0.3),
                borderRadius: AppRadii.lg,
                border: Border.all(color: itemColor.withOpacity(0.4), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  // Left side image/badge
                  Container(
                    width: 100,
                    height: 110,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                      child: images.isNotEmpty
                          ? Image.network(
                              images.first.toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Category3DBadge(category: category, title: title, size: 70),
                            )
                          : Container(
                              color: itemColor.withOpacity(0.1),
                              child: Center(
                                child: Category3DBadge(category: category, title: title, size: 70),
                              ),
                            ),
                    ),
                  ),
                  // Right side text
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: itemColor.withOpacity(0.15),
                                  borderRadius: AppRadii.sm,
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: itemColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    address,
                                    style: TextStyle(
                                      color: PulseColors.textSecondary,
                                      fontSize: 10.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: TextStyle(
                              color: PulseColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Expanded(
                            child: Text(
                              descText,
                              style: TextStyle(
                                color: PulseColors.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showReportMiniWindow(dynamic repo, Color itemColor, dynamic descriptor) {
    // Build filtered list for swipe navigation
    final filteredList = _preview.where((r) {
      if (_selectedCategory == null) return true;
      final cat = (r['category'] ?? 'Прочее') as String;
      return NotificationCatalog.normalize(cat) == _selectedCategory;
    }).toList();

    final initialIndex = filteredList.indexOf(repo).clamp(0, filteredList.length - 1);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return _SignalSwipeSheet(
          reports: filteredList,
          initialIndex: initialIndex,
          parentContext: context,
        );
      },
    );
  }

  List<dynamic> _deduplicateReports(List<dynamic> reports) {
    final List<dynamic> uniqueReports = [];
    
    for (final r in reports) {
      if (r is! Map) {
        uniqueReports.add(r);
        continue;
      }
      final addr = r['address']?.toString().toLowerCase().trim() ?? '';
      final title = r['title']?.toString() ?? '';
      final desc = r['description']?.toString() ?? '';
      final text = '$title $desc';
      final textNorm = text.toLowerCase().replaceAll(RegExp(r'[^\w\sа-яёА-ЯЁa-zA-Z]'), '');
      final words = textNorm.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();

      bool isDuplicate = false;
      for (int i = 0; i < uniqueReports.length; i++) {
        final u = uniqueReports[i];
        final uAddr = u['address']?.toString().toLowerCase().trim() ?? '';
        
        if (addr.isNotEmpty && uAddr.isNotEmpty && addr == uAddr) {
          final uTitle = u['title']?.toString() ?? '';
          final uDesc = u['description']?.toString() ?? '';
          final uText = '$uTitle $uDesc';
          final uTextNorm = uText.toLowerCase().replaceAll(RegExp(r'[^\w\sа-яёА-ЯЁa-zA-Z]'), '');
          final uWords = uTextNorm.split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();

          if (words.isEmpty || uWords.isEmpty) continue;
          final intersection = words.intersection(uWords);
          final union = words.union(uWords);
          final similarity = intersection.length / union.length;

          if (similarity > 0.25 || intersection.length >= 3) {
            isDuplicate = true;
            final currentDesc = u['description']?.toString() ?? '';
            final newDesc = r['description']?.toString() ?? '';
            
            if (newDesc.isNotEmpty && !currentDesc.contains(newDesc.substring(0, math.min(newDesc.length, 12)))) {
              u['description'] = '$currentDesc\nДополнительно из другого источника: $newDesc';
            }
            break;
          }
        }
      }

      if (!isDuplicate) {
        uniqueReports.add(Map<String, dynamic>.from(r));
      }
    }
    return uniqueReports;
  }

  List<Widget> _parseAndBuildSummaryWidgets(String summaryText) {
    if (summaryText.isEmpty) return [];

    final lines = summaryText.split('\n');
    final List<Widget> widgets = [];

    List<String> locations = [];
    List<String> events = [];
    List<String> incidents = [];
    List<String> aiTextParagraphs = [];
    String dateHeader = '';
    String totalAddressText = '';

    String currentSection = '';

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('📅')) {
        dateHeader = line;
        currentSection = '';
      } else if (line.startsWith('С точным адресом в городе:')) {
        totalAddressText = line;
        currentSection = '';
      } else if (line.startsWith('📍')) {
        currentSection = 'locations';
      } else if (line.startsWith('🎭')) {
        currentSection = 'events';
      } else if (line.startsWith('🚨')) {
        currentSection = 'incidents';
      } else if (line.startsWith('📡')) {
        currentSection = '';
      } else {
        if (currentSection == 'locations') {
          locations.add(line.replaceAll('—', '').replaceAll('-', '').replaceAll('•', '').trim());
        } else if (currentSection == 'events') {
          events.add(line.replaceAll('•', '').replaceAll('-', '').replaceAll('—', '').trim());
        } else if (currentSection == 'incidents') {
          incidents.add(line.replaceAll('•', '').replaceAll('-', '').replaceAll('—', '').trim());
        } else {
          aiTextParagraphs.add(line);
        }
      }
    }

    if (dateHeader.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            dateHeader,
            style: TextStyle(
              color: PulseColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (totalAddressText.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: PulseColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PulseColors.primary.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    totalAddressText,
                    style: TextStyle(
                      color: PulseColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (aiTextParagraphs.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  PulseColors.primary.withOpacity(0.12),
                  const Color(0xFF673AB7).withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PulseColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: PulseColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'РЕЗЮМЕ ДНЯ ОТ AI',
                      style: TextStyle(
                        color: PulseColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  aiTextParagraphs.join('\n\n'),
                  style: TextStyle(
                    color: PulseColors.textPrimary,
                    fontSize: 14.5,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (locations.isNotEmpty) {
      widgets.add(
        _buildSectionCard(
          title: 'ПОПУЛЯРНЫЕ ЛОКАЦИИ',
          icon: Icons.location_on_rounded,
          iconColor: Colors.redAccent,
          items: locations,
        ),
      );
    }

    if (events.isNotEmpty) {
      widgets.add(
        _buildSectionCard(
          title: 'МЕРОПРИЯТИЯ И СОБЫТИЯ',
          icon: Icons.event_note_rounded,
          iconColor: Colors.amber,
          items: events,
        ),
      );
    }

    if (incidents.isNotEmpty) {
      widgets.add(
        _buildSectionCard(
          title: 'СИГНАЛЫ И ПРОИСШЕСТВИЯ',
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.orangeAccent,
          items: incidents,
        ),
      );
    }

    return widgets;
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> items,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PulseColors.surfaceGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PulseColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: PulseColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            Divider(height: 20, color: PulseColors.border),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: iconColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            color: PulseColors.textPrimary,
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _SignalSwipeSheet extends StatefulWidget {
  final List<dynamic> reports;
  final int initialIndex;
  final BuildContext parentContext;

  const _SignalSwipeSheet({
    required this.reports,
    required this.initialIndex,
    required this.parentContext,
  });

  @override
  State<_SignalSwipeSheet> createState() => _SignalSwipeSheetState();
}

class _SignalSwipeSheetState extends State<_SignalSwipeSheet> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, bool> _unlockedAnalysis = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reports.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 64),
      decoration: BoxDecoration(
        color: PulseColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: PulseColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PulseColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: widget.reports.length,
              itemBuilder: (context, index) {
                return _buildPage(context, widget.reports[index]);
              },
            ),
          ),
          
          // Page indicators
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.reports.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? PulseColors.primary
                        : PulseColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, dynamic repo) {
    final index = widget.reports.indexOf(repo);
    final title = repo['title'] ?? 'Без заголовка';
    final category = repo['category'] ?? 'Прочее';
    final address = repo['address'] ?? 'Без адреса';
    final descText = (repo['description'] ?? repo['summary'] ?? '').toString();
    var cleanDesc = SituationHelper.cleanDescription(descText, title);
    if (category.toString().toLowerCase().contains('животн')) {
      cleanDesc = cleanDesc
          .replaceAll(RegExp(r'(?:пожалуйста,?\s*)?(?:пришлите|сделайте|загрузите|сфотографируйте|добавьте)\s+(?:фото|фотографию|снимок)[^.]*\.?', caseSensitive: false), '')
          .replaceAll(RegExp(r'напоминание о необходимости фото[^.]*\.?', caseSensitive: false), '')
          .replaceAll(RegExp(r'необходим[оа]\s+фото[^.]*\.?', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+фото\s+для\s+идентификации[^.]*\.?', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*фото\s*отсутствует[^.]*\.?', caseSensitive: false), '')
          .trim();
    }
    final analysis = SituationHelper.analyzeSituation(category, descText);

    final lat = repo['lat']?.toString() ?? repo['latitude']?.toString();
    final lng = repo['lng']?.toString() ?? repo['longitude']?.toString();
    final reportId = repo['id']?.toString() ?? '';
    final hasCoords = lat != null && lng != null;
    
    final descriptor = NotificationCatalog.describe(category);
    final itemColor = descriptor.color;

    String? imageUrl;
    if (repo['images'] is List && (repo['images'] as List).isNotEmpty) {
      imageUrl = (repo['images'] as List).first?.toString();
    } else if (repo['images'] is String && (repo['images'] as String).isNotEmpty) {
      imageUrl = repo['images'] as String;
    } else if (repo['photo_url'] != null && repo['photo_url'].toString().isNotEmpty) {
      imageUrl = repo['photo_url'].toString();
    } else if (repo['image_url'] != null && repo['image_url'].toString().isNotEmpty) {
      imageUrl = repo['image_url'].toString();
    }

    if (descText.contains('Фото: ')) {
      final parts = descText.split('Фото: ');
      final urlPartWithEnrichment = parts[1].trim();
      String urlPart = urlPartWithEnrichment;
      final newlineIndex = urlPartWithEnrichment.indexOf('\n');
      if (newlineIndex != -1) {
        urlPart = urlPartWithEnrichment.substring(0, newlineIndex).trim();
      }
      imageUrl ??= urlPart;
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageUrl = SituationHelper.resolveImageUrl(imageUrl);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: itemColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(descriptor.icon, color: itemColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.toString().toUpperCase(),
                      style: TextStyle(
                        color: itemColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: PulseColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: PulseColors.textSecondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: PulseColors.border, height: 1),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_rounded, color: itemColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            color: PulseColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PulseColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PulseColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description_outlined,
                                color: PulseColors.textSecondary,
                                size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Описание ситуации',
                              style: TextStyle(
                                color: PulseColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          cleanDesc.isNotEmpty ? cleanDesc : 'Описание отсутствует.',
                          style: TextStyle(
                            color: PulseColors.textPrimary,
                            fontSize: 14.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),


                  // Photo
                  if (imageUrl != null && imageUrl.isNotEmpty && !category.toString().toLowerCase().contains('животн')) ...[
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, err, stack) => Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: PulseColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 20),
                              SizedBox(width: 12),
                              Text(
                                'Фото загружается или недоступно',
                                style: TextStyle(color: Colors.redAccent, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // Map Button
                  if (hasCoords) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          final payload = <String, String?>{};
                          if (reportId.isNotEmpty) payload['report_id'] = reportId;
                          payload['lat'] = lat;
                          payload['lng'] = lng;
                          payload['from_digest'] = 'true';
                          payload['category'] = category;
                          payload['title'] = repo['title']?.toString();
                          payload['description'] = repo['description']?.toString();

                          final addr = repo['address']?.toString() ?? repo['category']?.toString();
                          if (addr != null && addr.trim().isNotEmpty) {
                            payload['address'] = addr.trim();
                          }

                          AppRouter.goToMap(context: context, payload: payload);
                        },
                        icon: const Icon(Icons.map_rounded, size: 20),
                        label: const Text('Показать на карте', style: TextStyle(fontSize: 16)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: itemColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Назад к просмотру', style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PulseColors.primarySoft,
                        side: BorderSide(color: PulseColors.primary.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: PulseColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: PulseColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// A premium real-time category distribution bar chart.
class DailyDigestChartWidget extends StatelessWidget {
  final Map<String, int> categoryCounts;

  const DailyDigestChartWidget({super.key, required this.categoryCounts});

  @override
  Widget build(BuildContext context) {
    if (categoryCounts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PulseColors.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'РАСПРЕДЕЛЕНИЕ СИГНАЛОВ ПО КАТЕГОРИЯМ',
            style: TextStyle(
              color: PulseColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          // Flex Bar (Multi-color bar)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  for (final entry in categoryCounts.entries)
                    Expanded(
                      flex: entry.value,
                      child: Container(
                        color: PulseCategories.colorFor(entry.key),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Legend list
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final entry in categoryCounts.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: PulseCategories.colorFor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.key} (${entry.value})',
                      style: TextStyle(
                        color: PulseColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class CityPulseAnimation extends StatefulWidget {
  final int pulseIndex;
  const CityPulseAnimation({super.key, required this.pulseIndex});

  @override
  State<CityPulseAnimation> createState() => _CityPulseAnimationState();
}

class _CityPulseAnimationState extends State<CityPulseAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final int speedMs = (400 + (widget.pulseIndex * 14)).clamp(500, 1800);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: speedMs),
    )..repeat();
  }

  @override
  void didUpdateWidget(CityPulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulseIndex != widget.pulseIndex) {
      _controller.dispose();
      _initController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color pulseColor = widget.pulseIndex > 85
        ? const Color(0xFF00E676)
        : (widget.pulseIndex > 65
            ? const Color(0xFFFF9100)
            : const Color(0xFFFF1744));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(44, 44),
          painter: _PulsePainter(
            progress: _controller.value,
            color: pulseColor,
            severity: (100 - widget.pulseIndex) / 100.0,
          ),
        );
      },
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double severity;

  _PulsePainter({required this.progress, required this.color, required this.severity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.22;

    final Paint wavePaint = Paint()
      ..color = color.withOpacity((1.0 - progress).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + (severity * 2.0);

    final waveRadius = baseRadius + (progress * (size.width / 2 - baseRadius));
    canvas.drawCircle(center, waveRadius, wavePaint);

    if (severity > 0.35) {
      final double secProgress = (progress + 0.5) % 1.0;
      final Paint secWavePaint = Paint()
        ..color = color.withOpacity((0.6 * (1.0 - secProgress)).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final secWaveRadius = baseRadius + (secProgress * (size.width / 2 - baseRadius));
      canvas.drawCircle(center, secWaveRadius, secWavePaint);
    }

    final Paint corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final Paint glowPaint = Paint()
      ..color = color.withOpacity(0.3 + (severity * 0.3))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + (severity * 6));
    canvas.drawCircle(center, baseRadius + 2, glowPaint);
    
    final double coreScale = 1.0 + (math.sin(progress * math.pi * 2) * (0.08 + (severity * 0.12)));
    canvas.drawCircle(center, baseRadius * coreScale, corePaint);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.severity != severity;
}

class PulseChartWidget extends StatefulWidget {
  final List<double> dataPoints;
  final Color chartColor;
  const PulseChartWidget({super.key, required this.dataPoints, required this.chartColor});

  @override
  State<PulseChartWidget> createState() => _PulseChartWidgetState();
}

class _PulseChartWidgetState extends State<PulseChartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(PulseChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 80),
          painter: _LineChartPainter(
            dataPoints: widget.dataPoints,
            progress: _animation.value,
            color: widget.chartColor,
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final double progress;
  final Color color;

  _LineChartPainter({required this.dataPoints, required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final Paint linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final Paint fillPaint = Paint()
      ..style = PaintingStyle.fill;

    final double widthStep = size.width / 24.0;
    final double maxVal = 100.0;
    final double minVal = 40.0;
    final double valRange = maxVal - minVal;

    Offset getPointOffset(int index, double val) {
      final x = index * widthStep;
      final y = size.height - ((val - minVal) / valRange * size.height);
      return Offset(x, y);
    }

    final path = Path();
    final fillPath = Path();

    fillPath.moveTo(0, size.height);

    final points = <Offset>[];
    for (int i = 0; i < dataPoints.length; i++) {
      points.add(getPointOffset(i, dataPoints[i]));
    }

    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      fillPath.lineTo(points[0].dx, points[0].dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final controlOffset = Offset((p0.dx + p1.dx) / 2, p0.dy);
        final controlOffset2 = Offset((p0.dx + p1.dx) / 2, p1.dy);

        path.cubicTo(
          controlOffset.dx, controlOffset.dy,
          controlOffset2.dx, controlOffset2.dy,
          p1.dx, p1.dy,
        );
        fillPath.cubicTo(
          controlOffset.dx, controlOffset.dy,
          controlOffset2.dx, controlOffset2.dy,
          p1.dx, p1.dy,
        );
      }
    }

    final Iterator<PathMetric> pathMetrics = path.computeMetrics().iterator;
    final Path animatedPath = Path();
    
    double totalLength = 0;
    final metricsList = <PathMetric>[];
    while (pathMetrics.moveNext()) {
      metricsList.add(pathMetrics.current);
      totalLength += pathMetrics.current.length;
    }

    final double targetLength = totalLength * progress;
    double currentLength = 0;
    Offset lastOffset = points.isNotEmpty ? points[0] : Offset.zero;

    for (final metric in metricsList) {
      if (currentLength + metric.length <= targetLength) {
        animatedPath.addPath(metric.extractPath(0, metric.length), Offset.zero);
        currentLength += metric.length;
        lastOffset = metric.getTangentForOffset(metric.length)?.position ?? lastOffset;
      } else {
        final double remaining = targetLength - currentLength;
        animatedPath.addPath(metric.extractPath(0, remaining), Offset.zero);
        lastOffset = metric.getTangentForOffset(remaining)?.position ?? lastOffset;
        break;
      }
    }

    final fillShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.25),
        color.withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    fillPaint.shader = fillShader;

    final animatedFillPath = Path.from(animatedPath);
    animatedFillPath.lineTo(lastOffset.dx, size.height);
    animatedFillPath.lineTo(0, size.height);
    animatedFillPath.close();

    canvas.drawPath(animatedFillPath, fillPaint);

    final Paint glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(animatedPath, glowPaint);

    canvas.drawPath(animatedPath, linePaint);

    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1.0;
    
    for (int h = 4; h <= 24; h += 4) {
      final x = h * widthStep;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    if (points.isNotEmpty && progress > 0.0) {
      final Paint dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final Paint dotGlow = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(lastOffset, 6.0, dotGlow);
      canvas.drawCircle(lastOffset, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.dataPoints != dataPoints;
}



class StorySlide {
  final String title;
  final String content;
  final IconData icon;
  final Color color;
  final String? category;
  
  StorySlide({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
    this.category,
  });
}

class DailyDigestStoriesWidget extends StatefulWidget {
  final String summary;
  final Function(String?) onCategorySelected;

  const DailyDigestStoriesWidget({
    super.key,
    required this.summary,
    required this.onCategorySelected,
  });

  @override
  State<DailyDigestStoriesWidget> createState() => _DailyDigestStoriesWidgetState();
}

class _DailyDigestStoriesWidgetState extends State<DailyDigestStoriesWidget> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentIndex = 0;
  List<StorySlide> _slides = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _slides = _buildSlidesFromSummary(widget.summary);
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextSlide();
      }
    });

    _startStory();
  }

  @override
  void didUpdateWidget(DailyDigestStoriesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary != widget.summary) {
      setState(() {
        _slides = _buildSlidesFromSummary(widget.summary);
        _currentIndex = 0;
      });
      _pageController.jumpToPage(0);
      _startStory();
    }
  }

  void _startStory() {
    _progressController.reset();
    _progressController.forward();
    if (_slides.isNotEmpty && _currentIndex < _slides.length) {
      widget.onCategorySelected(_slides[_currentIndex].category);
    }
  }

  void _nextSlide() {
    if (_currentIndex < _slides.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
    } else {
      setState(() {
        _currentIndex = 0;
      });
      _pageController.jumpToPage(0);
      _startStory();
    }
  }

  void _prevSlide() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
    }
  }

  List<StorySlide> _buildSlidesFromSummary(String summaryText) {
    if (summaryText.isEmpty) {
      return [
        StorySlide(
          title: 'AI Дайджест',
          content: 'Загрузка сводных данных...',
          icon: Icons.auto_awesome,
          color: const Color(0xFF7C4DFF),
        )
      ];
    }

    final lines = summaryText.split('\n');
    final List<StorySlide> slides = [];

    List<String> locations = [];
    List<String> events = [];
    List<String> incidents = [];
    List<String> general = [];
    String dateHeader = 'Городской дайджест';
    String totalAddressText = '';

    String currentSection = '';

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('📅')) {
        dateHeader = line;
        currentSection = '';
      } else if (line.startsWith('С точным адресом в городе:')) {
        totalAddressText = line;
        currentSection = '';
      } else if (line.startsWith('📍')) {
        currentSection = 'locations';
      } else if (line.startsWith('🎭')) {
        currentSection = 'events';
      } else if (line.startsWith('🚨')) {
        currentSection = 'incidents';
      } else if (line.startsWith('📡')) {
        currentSection = 'general';
      } else {
        if (currentSection == 'locations') {
          locations.add(line);
        } else if (currentSection == 'events') {
          events.add(line);
        } else if (currentSection == 'incidents') {
          incidents.add(line);
        } else {
          general.add(line);
        }
      }
    }

    slides.add(
      StorySlide(
        title: dateHeader,
        content: totalAddressText.isNotEmpty 
            ? totalAddressText + '\n\nКоснитесь правой стороны карточки для переключения слайдов.'
            : 'Сводка событий в городе за последние сутки.\n\nКоснитесь правой стороны карточки для перехода.',
        icon: Icons.auto_awesome,
        color: const Color(0xFF00E5FF),
      )
    );

    if (locations.isNotEmpty) {
      slides.add(
        StorySlide(
          title: '📍 Локации активности',
          content: locations.join('\n'),
          icon: Icons.map_rounded,
          color: const Color(0xFFFFB300),
          category: 'Дороги',
        )
      );
    }

    if (events.isNotEmpty) {
      slides.add(
        StorySlide(
          title: '🎭 Городские события',
          content: events.join('\n'),
          icon: Icons.event_note_rounded,
          color: const Color(0xFFD500F9),
          category: 'Транспорт',
        )
      );
    }

    if (incidents.isNotEmpty) {
      slides.add(
        StorySlide(
          title: '🚨 Происшествия и инциденты',
          content: incidents.join('\n'),
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFFF1744),
          category: 'Безопасность',
        )
      );
    }

    if (general.isNotEmpty) {
      slides.add(
        StorySlide(
          title: '📡 Сводный ИИ-анализ',
          content: general.join('\n'),
          icon: Icons.analytics_rounded,
          color: const Color(0xFF00E676),
          category: 'ЖКХ',
        )
      );
    }

    return slides;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_slides.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return GestureDetector(
          onLongPressStart: (_) => _progressController.stop(),
          onLongPressEnd: (_) => _progressController.forward(),
          onTapUp: (details) {
            final width = MediaQuery.of(context).size.width;
            final dx = details.localPosition.dx;
            if (dx < width * 0.3) {
              _prevSlide();
            } else {
              _nextSlide();
            }
          },
          child: Container(
            height: 240,
            decoration: BoxDecoration(
              color: PulseColors.surfaceGlass,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: _slides[_currentIndex].color.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FloatingParticlesOverlay(color: _slides[_currentIndex].color),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: List.generate(_slides.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    double fillWidth = 0.0;
                                    if (index < _currentIndex) {
                                      fillWidth = constraints.maxWidth;
                                    } else if (index == _currentIndex) {
                                      fillWidth = constraints.maxWidth * _progressController.value;
                                    }
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: fillWidth,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: _slides[_currentIndex].color,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            _slides[_currentIndex].icon,
                            color: _slides[_currentIndex].color,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _slides[_currentIndex].title.toUpperCase(),
                              style: TextStyle(
                                color: PulseColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                            decoration: BoxDecoration(
                              color: _slides[_currentIndex].color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Слайд ' + (_currentIndex + 1).toString() + '/' + _slides.length.toString(),
                              style: TextStyle(
                                color: _slides[_currentIndex].color,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Text(
                            _slides[_currentIndex].content,
                            style: TextStyle(
                              color: PulseColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FloatingParticlesOverlay extends StatefulWidget {
  final Color color;
  const FloatingParticlesOverlay({super.key, required this.color});

  @override
  State<FloatingParticlesOverlay> createState() => _FloatingParticlesOverlayState();
}

class _FloatingParticlesOverlayState extends State<FloatingParticlesOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<math.Point<double>> _offsets = [];
  final List<double> _speeds = [];
  final List<double> _sizes = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    final rand = math.Random(123);
    for (int i = 0; i < 6; i++) {
      _offsets.add(math.Point(rand.nextDouble(), rand.nextDouble()));
      _speeds.add(0.2 + rand.nextDouble() * 0.4);
      _sizes.add(3.0 + rand.nextDouble() * 8.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlesPainter(
            progress: _controller.value,
            offsets: _offsets,
            speeds: _speeds,
            sizes: _sizes,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final double progress;
  final List<math.Point<double>> offsets;
  final List<double> speeds;
  final List<double> sizes;
  final Color color;

  _ParticlesPainter({
    required this.progress,
    required this.offsets,
    required this.speeds,
    required this.sizes,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < offsets.length; i++) {
      final x = (offsets[i].x * size.width) % size.width;
      final speed = speeds[i];
      final y = (offsets[i].y * size.height - (progress * size.height * speed)) % size.height;
      final r = sizes[i];
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter old) =>
      old.progress != progress || old.color != color;
}
