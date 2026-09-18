import 'dart:io';
import 'dart:math' as math;
import '../utils/offline_tiles_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui';
import 'profile_screen.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_router/go_router.dart';

import '../core/app_router.dart';
import '../data/district_data.dart';
import '../services/draft_box_service.dart';
import '../services/notification_catalog.dart';
import '../services/reports_repository.dart';
import '../services/sound_service.dart';
import '../widgets/dynamic_animated_background.dart';
import '../widgets/pulse_glass_dropdown.dart';
import '../theme/pulse_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_ui.dart';
import '../services/app_state_service.dart';
import '../engine/aurae_render_governor.dart';
import '../map/map_config.dart';
import '../widgets/aura_living_background.dart';
import '../core/living/aura_living_engine.dart';
import '../core/living/aura_theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _soundVolumeLevel = 0.8;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _voiceAnnouncementsEnabled = true;
  bool _weatherAlertsEnabled = true;
  bool _highPerformanceMode = false;
  int _pendingDraftCount = 0;
  bool _hasOfflineMap = false;
  bool _isDownloadingMap = false;
  double _downloadProgress = 0.0;
  bool _isSyncingDrafts = false;
  String _splashTheme = 'gravity';
  bool _isMenuOnRight = false;
  bool _autoReturnCamera = true;
  bool _isVip = false;
  bool _splashSoundsEnabled = true;

  // Бесплатные фоны (2 шт)
    // Бесплатные фоны (2 шт)
  static const List<(String, String)> _freeThemes = [
    ('gravity',  'Цифровая гравитация'),
    ('ai_core',  'Ядро ИИ'),
  ];

  // VIP фоны (8 шт)
  static const List<(String, String)> _vipThemes = [
    ('premium_glass', '💎 Дорогое стекло (Premium)'),
    ('glass_vip_gold', '👑 Жидкое Золото (Premium Glass)'),
    ('glass_vip_nebula', '🌌 Звёздная Туманность (Premium Glass)'),
    ('glass_vip_emerald', '🟢 Изумрудное Сияние (Premium Glass)'),
    ('glass_vip_arctic', '❄️ Кристальная Арктика (Premium Glass)'),
    ('glass_vip_sunset', '🌅 Бархатный Закат (Premium Glass)'),
    ('aurora_living', '🔮 Аура Дайджеста'),
    ('plasma_storm', '⚡ Плазменный шторм'),
    ('constellation', '🌌 Созвездия'),
    ('aurora_borealis', '🌌 Северное сияние'),
    ('quantum_foam', '⚛️ Квантовая пена'),
    ('rain_on_glass', '🌧️ Дождь на стекле'),
    ('starfield',    '⭐ Звёздное поле'),
    ('matrix',       '📟 Матрица'),
    ('neon',         '🔮 Неоновый пульс'),
    ('cyberpunk',    '🌆 Киберпанк'),
  ];

  List<NotificationCategoryDescriptor> _categories =
      NotificationCatalog.defaults;
  final Map<String, bool> _categoryState = <String, bool>{};

  // Фильтр микрорайонов
  final Set<String> _selectedDistricts = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = AppStateService.instance.state;
    final prefs = await SharedPreferences.getInstance();
    final isVip = prefs.getBool('is_premium_vip') ?? prefs.getBool('is_vip') ?? false;
    final highPerf = prefs.getBool('high_performance_mode') ?? false;

    List<String> serverCategories = const [];
    try {
      serverCategories = await ReportsRepository.instance.fetchServerCategories();
    } catch (_) {
      serverCategories = const [];
    }

    final mergedCategories = NotificationCatalog.mergeServerCategories(
      serverCategories,
    );
    final nextCategoryState = <String, bool>{};
    for (final descriptor in mergedCategories) {
      nextCategoryState[descriptor.name] =
          s.notifCategories[descriptor.name] ?? true;
    }

    if (!mounted) return;
    final splashSounds = prefs.getBool('splash_sounds_enabled') ?? true;
    final draftCount = await DraftBoxService.instance.pendingCount();
    setState(() {
      _splashSoundsEnabled = splashSounds;
      _isVip = isVip;
      _notificationsEnabled = s.notifEnabled;
      _soundEnabled = s.soundEnabled;
      _soundVolumeLevel = s.soundVolume;
      _voiceAnnouncementsEnabled = s.voiceEnabled;
      _weatherAlertsEnabled = s.weatherAlerts;
      _highPerformanceMode = highPerf;
      _splashTheme = s.splashTheme;
      _isMenuOnRight = s.isMenuOnRight;
      _autoReturnCamera = s.autoReturnCamera;
      _pendingDraftCount = draftCount;
      // Check offline map file presence
      _checkOfflineMap();
      _categories = mergedCategories;
      _categoryState
        ..clear()
        ..addAll(nextCategoryState);
      _selectedDistricts
        ..clear()
        ..addAll(s.mapDistricts);
    });
    SoundService().setMute(!_soundEnabled);
  }

  (int, String)? _parseDistrictNumber(String name) {
    final reg = RegExp(r'(\d+)([а-яА-Я]*)');
    final match = reg.firstMatch(name);
    if (match != null) {
      final numVal = int.parse(match.group(1)!);
      final suffix = match.group(2) ?? '';
      return (numVal, suffix);
    }
    return null;
  }

  Future<void> _saveSettings() async {
    await AppStateService.instance.saveNotificationSettings(
      enabled: _notificationsEnabled,
      sound: _soundEnabled,
      volume: _soundVolumeLevel,
      voice: _voiceAnnouncementsEnabled,
      weatherAlerts: _weatherAlertsEnabled,
      categories: _categoryState,
    );
    // Also save splash theme to state
    await AppStateService.instance.patch((s) => s.copyWith(
      splashTheme: _splashTheme,
      mapDistricts: _selectedDistricts.toList(),
      isMenuOnRight: _isMenuOnRight,
      autoReturnCamera: _autoReturnCamera,
    ));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('splash_sounds_enabled', _splashSoundsEnabled);
    await prefs.setBool('high_performance_mode', _highPerformanceMode);
    AuraeRenderGovernor.instance.setTier(
      _highPerformanceMode ? AuraeVisualTier.ritual : AuraeVisualTier.calm,
    );
    SoundService().setMute(!_soundEnabled);
  }

  Future<void> _checkOfflineMap() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/nizhnevartovsk.pmtiles');
    final exists = await file.exists();
    if (mounted) {
      setState(() {
        _hasOfflineMap = exists;
      });
    }
  }

  Future<void> _downloadOfflineMap() async {
    setState(() {
      _isDownloadingMap = true;
      _downloadProgress = 0.0;
    });
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/nizhnevartovsk.pmtiles');

      // Скачиваем PMTiles-файл Нижневартовска с бэкенда (или Protomaps CDN)
      final urls = [
        '${MapConfig.backendBaseUrl}/static/nizhnevartovsk.pmtiles',
        // Fallback: A small targeted PMTiles slice of Nizhnevartovsk region from public protomaps mirror
        'https://protomaps.github.io/basemaps-assets/nizhnevartovsk.pmtiles',
        'https://build.protomaps.com/20240801T000000Z.pmtiles',
      ];

      bool success = false;
      for (final url in urls) {
        try {
          debugPrint('Trying to download PMTiles from $url...');
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 15);
          final request = await client.getUrl(Uri.parse(url));
          final response = await request.close();

          if (response.statusCode != 200) {
            debugPrint('PMTiles download $url returned ${response.statusCode}, trying next...');
            continue;
          }

          final total = response.contentLength;
          num downloaded = 0;

          // Stream writing directly to disk to prevent Out Of Memory crashes
          final sink = file.openWrite();

          await for (final chunk in response) {
            sink.add(chunk);
            downloaded += chunk.length;
            if (total > 0 && mounted) {
              setState(() {
                _downloadProgress = downloaded / total;
              });
            } else if (mounted) {
              setState(() {
                _downloadProgress = -1; // Indeterminate loading
              });
            }
          }

          await sink.close();

          if (await file.exists() && await file.length() > 1000) {
            success = true;
            break;
          }
        } catch (e) {
          debugPrint('PMTiles download attempt failed ($url): $e');
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      if (success) {
        await OfflineTilesService.instance.initOfflineTiles();
        await _checkOfflineMap();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Офлайн-карта Нижневартовска успешно загружена')),
          );
        }
      } else {
        // Fallback: кэширование тайлов при просмотре (SQLite auto-cache)
        await _preCacheTilesForCity();
        if (mounted) {
          // Создаем пустой файл-маркер чтобы показать что кэш скачан
          await file.writeAsString('cached_tiles_mode');
          await _checkOfflineMap();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Офлайн-тайлы кэшированы для текущего района')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки карты: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingMap = false;
        });
      }
    }
  }

  /// Кэширование тайлов для текущего города (уровни зума 10-16)
  Future<void> _preCacheTilesForCity() async {
    // Нижневартовск: bounding box ~60.90-60.97 lat, 76.51-76.60 lng
    // Загружаем тайлы через HTTP и сохраняем в кэш CachedTileProvider
    const lat1 = 60.90;
    const lat2 = 60.97;
    const lng1 = 76.50;
    const lng2 = 76.62;
    
    final client = HttpClient();
    int totalTiles = 0;
    int downloadedTiles = 0;
    
    // Считаем тайлы для зумов 12-15
    for (int z = 12; z <= 15; z++) {
      final x1 = _lngToTile(lng1, z);
      final x2 = _lngToTile(lng2, z);
      final y1 = _latToTile(lat2, z);
      final y2 = _latToTile(lat1, z);
      totalTiles += (x2 - x1 + 1) * (y2 - y1 + 1);
    }
    
    for (int z = 12; z <= 15; z++) {
      final x1 = _lngToTile(lng1, z);
      final x2 = _lngToTile(lng2, z);
      final y1 = _latToTile(lat2, z);
      final y2 = _latToTile(lat1, z);
      
      for (int x = x1; x <= x2; x++) {
        for (int y = y1; y <= y2; y++) {
          try {
            final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
            final req = await client.getUrl(Uri.parse(url));
            req.headers.set('User-Agent', 'CityPulseApp/1.0');
            final resp = await req.close();
            // Drain response to trigger caching
            await resp.drain();
          } catch (_) {}
          downloadedTiles++;
          if (mounted && totalTiles > 0) {
            setState(() {
              _downloadProgress = downloadedTiles / totalTiles;
            });
          }
        }
      }
    }
    client.close();
  }

  int _lngToTile(double lng, int z) {
    return ((lng + 180.0) / 360.0 * (1 << z)).floor();
  }

  int _latToTile(double lat, int z) {
    final latRad = lat * math.pi / 180.0;
    final y = ((1.0 - (math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi)) / 2.0 * (1 << z)).floor();
    return y.clamp(0, (1 << z) - 1);
  }

  Future<void> _deleteOfflineMap() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/nizhnevartovsk.pmtiles');
      if (await file.exists()) {
        await file.delete();
      }
      await OfflineTilesService.instance.initOfflineTiles();
      await _checkOfflineMap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Офлайн-карта удалена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }

  Future<void> _syncDrafts() async {
    if (_isSyncingDrafts) return;
    setState(() => _isSyncingDrafts = true);
    try {
      await DraftBoxService.instance.syncOnline();
      final count = await DraftBoxService.instance.pendingCount();
      if (!mounted) return;
      setState(() => _pendingDraftCount = count);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'Все черновики отправлены'
                : 'Осталось черновиков: $count',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось синхронизировать: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSyncingDrafts = false);
    }
  }

  Future<void> _playTestSound() async {
    final descriptor = _categories.firstWhere(
      (item) => _categoryState[item.name] ?? true,
      orElse: () => NotificationCatalog.describe('Безопасность'),
    );
    await SoundService().playCategorySound(descriptor.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Проигран тестовый звук: ${descriptor.name}')),
    );
  }

  void _triggerHaptic() {
    // Vibration setting is removed
  }

  AuraWeather _getAuraWeatherForTheme(String key) {
    switch (key) {
      case 'starfield':
      case 'gravity':
        return AuraWeather.starfield;
      case 'cyberpunk':
      case 'ai_core':
        return AuraWeather.cyberpunk;
      case 'premium_glass':
        return AuraWeather.fluid;
      case 'glass_vip_gold':
        return AuraWeather.fractal;
      case 'glass_vip_nebula':
        return AuraWeather.nebula;
      case 'glass_vip_emerald':
        return AuraWeather.voronoi;
      case 'glass_vip_arctic':
        return AuraWeather.snow;
      case 'glass_vip_sunset':
        return AuraWeather.sunset;
      case 'aurora_living':
        return AuraWeather.aurora;
      case 'plasma_storm':
        return AuraWeather.waveFunc;
      case 'constellation':
        return AuraWeather.cosmos;
      case 'aurora_borealis':
        return AuraWeather.aurora;
      case 'quantum_foam':
        return AuraWeather.waveFunc;
      case 'rain_on_glass':
        return AuraWeather.rain;
      case 'neon':
        return AuraWeather.neon;
      case 'matrix':
        return AuraWeather.matrix;
      default:
        return AuraWeather.aura;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeProvider.instance.isDarkMode;

    return ListenableBuilder(
      listenable: AuraThemeService.instance,
      builder: (context, _) {
        final currentTheme = AuraThemeService.instance.theme;
        return AuraLivingBackground(
          scene: currentTheme.toScene(),
          showSignatureObject: false,
          showConstellationVeil: false,
          interactive: true,
          child: Scaffold(
            backgroundColor: isDark ? Colors.transparent : Colors.white.withOpacity(0.24),
            body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      BackButton(
                        color: PulseColors.primary,
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            context.goNamed('map');
                          }
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Настройки', style: AppTextStyles.section),
                            const SizedBox(height: 2),
                            Text(
                              'Уведомления, звук, озвучка и черновики',
                              style: AppTextStyles.bodyMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xxl,
                    ),
                    children: [
                      _buildOfflineSection(),
                      const SizedBox(height: AppSpacing.md),
                      AppPanel(
                        style: PanelStyle.standard,
                        child: _buildMainControls(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppPanel(
                        style: PanelStyle.standard,
                        child: _buildCategoriesSection(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppPanel(
                        style: PanelStyle.standard,
                        child: _buildDistrictsSection(),
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
  );
}

  Widget _buildOfflineSection() {
    final hasDrafts = _pendingDraftCount > 0;
    return AppPanel(
      style: hasDrafts ? PanelStyle.aurora : PanelStyle.standard,
      accent: hasDrafts ? PulseColors.warning : null,
      showAuroraGlow: hasDrafts,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Офлайн-режим', style: AppTextStyles.section),
              if (hasDrafts)
                AppStatusBadge(
                  label: 'Есть черновики',
                  color: PulseColors.warning,
                  icon: Icons.warning_amber_rounded,
                )
              else
                AppStatusBadge(
                  label: 'Синхронизировано',
                  color: PulseColors.success,
                  icon: Icons.check_circle_outline,
                )
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasDrafts
                      ? PulseColors.warning.withOpacity(0.16)
                      : PulseColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inbox_outlined,
                  color: hasDrafts ? PulseColors.warning : PulseColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDrafts
                          ? 'Черновиков на устройстве: $_pendingDraftCount'
                          : 'Локальные черновики отсутствуют',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Жалобы сохраняются при отсутствии сети',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (hasDrafts) ...[
                OutlinedButton(
                  onPressed: () {
                    _triggerHaptic();
                    AppRouter.goToComplaintForm(context: context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: PulseColors.warning.withOpacity(0.5)),
                    foregroundColor: PulseColors.warning,
                  ),
                  child: const Text('Открыть форму'),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              FilledButton.icon(
                onPressed: _isSyncingDrafts
                    ? null
                    : () {
                        _triggerHaptic();
                        _syncDrafts();
                      },
                icon: _isSyncingDrafts
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: Colors.white70,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(_isSyncingDrafts ? 'Синхронизация...' : 'Синхронизировать'),
              ),
            ],
          ),
          Divider(color: PulseColors.border, height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _hasOfflineMap
                      ? PulseColors.success.withOpacity(0.12)
                      : PulseColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.map_outlined,
                  color: _hasOfflineMap ? PulseColors.success : PulseColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasOfflineMap
                          ? 'Офлайн-карта Нижневартовска'
                          : 'Векторная офлайн-карта',
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasOfflineMap
                          ? 'Карта загружена (офлайн-тайлы)'
                          : 'Экономит 90% трафика и работает без сети',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isDownloadingMap) ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(PulseColors.primary),
                    ),
                  ),
                ),
                Text(
                  '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: PulseColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ] else ...[
                if (_hasOfflineMap) ...[
                  OutlinedButton.icon(
                    onPressed: _deleteOfflineMap,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Удалить'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: _downloadOfflineMap,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Скачать (28 МБ)'),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSwitchRow(
          label: 'Push-уведомления',
          subtitle: 'Локальные и фоновые сигналы',
          icon: Icons.notifications_active_outlined,
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() => _notificationsEnabled = value);
            _saveSettings();
          },
        ),
        _buildSwitchRow(
          label: 'Боковое меню слева',
          subtitle: 'Позиция меню: слева или справа',
          icon: Icons.view_sidebar_outlined,
          value: !_isMenuOnRight,
          onChanged: (value) {
            setState(() => _isMenuOnRight = !value);
            _saveSettings();
          },
        ),
        _buildSwitchRow(
          label: 'Автовозврат на карту при бездействии',
          subtitle: 'Камера возвращается к границам города через 1 мин',
          icon: Icons.center_focus_weak_rounded,
          value: _autoReturnCamera,
          onChanged: (value) {
            setState(() => _autoReturnCamera = value);
            _saveSettings();
          },
        ),
        _buildSwitchRow(
          label: 'Звук',
          subtitle: 'Категорийные аудио-сигналы',
          icon: Icons.volume_up_outlined,
          value: _soundEnabled,
          onChanged: (value) {
            setState(() => _soundEnabled = value);
            _saveSettings();
            if (value) {
              _playTestSound();
            }
          },
        ),
        _buildSwitchRow(
          label: 'Звук заставки при старте',
          subtitle: 'Звуковое сопровождение сплэш-экрана',
          icon: Icons.music_note_outlined,
          value: _splashSoundsEnabled,
          onChanged: (value) {
            setState(() => _splashSoundsEnabled = value);
            _saveSettings();
          },
        ),

        _buildSwitchRow(
          label: 'Озвучка городских сигналов',
          subtitle: 'Голосовое воспроизведение входящих событий',
          icon: Icons.record_voice_over_outlined,
          value: _voiceAnnouncementsEnabled,
          onChanged: (value) {
            setState(() => _voiceAnnouncementsEnabled = value);
            _saveSettings();
          },
        ),
        _buildSwitchRow(
          label: 'Погодные предупреждения',
          subtitle: 'Уведомления об аномалиях погоды и геомагнитных бурях',
          icon: Icons.thunderstorm_outlined,
          value: _weatherAlertsEnabled,
          onChanged: (value) {
            setState(() => _weatherAlertsEnabled = value);
            _saveSettings();
          },
        ),
        _buildPerformanceSelector(),
        _buildThemeSelector(),
        _buildDropdownRow(
          label: 'Тема оформления',
          subtitle: 'Тёмная, светлая или системная',
          icon: Icons.dark_mode_rounded,
          value: ThemeProvider.instance.themeMode.name,
          items: const [
            ('dark', 'Тёмная'),
            ('light', 'Светлая'),
            ('system', 'Системная'),
          ],
          onChanged: (value) async {
            if (value == null) return;
            final mode = switch (value) {
              'light' => ThemeMode.light,
              'system' => ThemeMode.system,
              _ => ThemeMode.dark,
            };
            await ThemeProvider.instance.setThemeMode(mode);
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: AppRadii.md,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: PulseColors.surfaceGlass,
              borderRadius: AppRadii.md,
              border: Border.all(
                color: value 
                    ? PulseColors.primary 
                    : PulseColors.border,
                width: value ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(value ? 0.3 : 0.22),
                  blurRadius: value ? 24 : 28,
                  offset: value ? const Offset(0, 8) : const Offset(0, 14),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: AppRadii.md,
              onTap: () {
                _triggerHaptic();
                onChanged(!value);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: value
                            ? PulseColors.primary.withOpacity(0.18)
                            : PulseColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: AnimatedScale(
                        scale: value ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          icon,
                          size: 20,
                          color: value ? PulseColors.primary : PulseColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(subtitle, style: AppTextStyles.bodyMuted),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Switch.adaptive(
                      value: value,
                      onChanged: (newValue) {
                        _triggerHaptic();
                        onChanged(newValue);
                      },
                      activeColor: PulseColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String?> onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: AppRadii.md,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: PulseColors.surfaceGlass,
              borderRadius: AppRadii.md,
              border: Border.all(
                color: PulseColors.borderStrong,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: PulseColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: PulseColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: AppTextStyles.bodyMuted),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 155,
                    child: PulseGlassDropdown<String>(
                      value: value,
                      isNightMode: ThemeProvider.instance.isDarkMode,
                      fillColor: Colors.transparent,
                      onChanged: (newValue) {
                        if (newValue != null) {
                          _triggerHaptic();
                          onChanged(newValue);
                        }
                      },
                      items: items.map((item) {
                        return PulseGlassDropdownItem<String>(
                          value: item.$1,
                          child: Text(
                            item.$2,
                            style: AppTextStyles.cardTitle.copyWith(fontSize: 13, color: PulseColors.primary),
                          ),
                        );
                      }).toList(),
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

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Категории уведомлений', style: AppTextStyles.section),
              const SizedBox(height: 2),
              Text(
                'Выберите категории для получения важных пушей',
                style: AppTextStyles.bodyMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: _notificationsEnabled ? 1.0 : 0.38,
          child: IgnorePointer(
            ignoring: !_notificationsEnabled,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.3,
              ),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final active = _categoryState[cat.name] ?? true;
                
                return ClipRRect(
                  borderRadius: AppRadii.md,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: active 
                            ? cat.color.withOpacity(0.08) 
                            : PulseColors.surfaceGlass,
                        borderRadius: AppRadii.md,
                        border: Border.all(
                          color: active 
                              ? cat.color.withOpacity(0.4) 
                              : PulseColors.borderStrong,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(active ? 0.25 : 0.15),
                            blurRadius: active ? 12 : 16,
                            offset: active ? const Offset(0, 4) : const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: AppRadii.md,
                        onTap: () {
                          _triggerHaptic();
                          setState(() {
                            _categoryState[cat.name] = !active;
                          });
                          _saveSettings();
                          SoundService().playCategorySound(cat.name);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: active 
                                      ? cat.color.withOpacity(0.2) 
                                      : PulseColors.surfaceSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: AnimatedScale(
                                  scale: active ? 1.15 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    cat.icon,
                                    size: 16,
                                    color: active ? cat.color : PulseColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs + 2),
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: AppTextStyles.cardTitle.copyWith(
                                    fontSize: 13,
                                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                    color: active ? PulseColors.textPrimary : PulseColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistrictsSection() {
    final hasSelection = _selectedDistricts.isNotEmpty;
    
    // Sort districts to have numbered ones first, then alphabetical ones
    final list = List<DistrictData>.from(NizhnevartovskDistricts.districts);
    list.sort((a, b) {
      final aNum = _parseDistrictNumber(a.name);
      final bNum = _parseDistrictNumber(b.name);
      if (aNum != null && bNum != null) {
        if (aNum.$1 != bNum.$1) {
          return aNum.$1.compareTo(bNum.$1);
        }
        return aNum.$2.compareTo(bNum.$2);
      }
      if (aNum != null) return -1;
      if (bNum != null) return 1;
      return a.name.compareTo(b.name);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Фильтр по микрорайонам', style: AppTextStyles.section),
                    const SizedBox(height: 2),
                    Text(
                      hasSelection
                          ? 'Выбрано районов: ${_selectedDistricts.length}'
                          : 'Все микрорайоны (нажмите для выбора)',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),
              if (hasSelection)
                TextButton(
                  onPressed: () {
                    setState(() => _selectedDistricts.clear());
                    _saveSettings();
                  },
                  child: Text('Сбросить',
                      style: TextStyle(color: PulseColors.primary, fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: list.map((d) {
            final isActive = _selectedDistricts.contains(d.id);
            
            // Extract compact name
            String compactName = d.name;
            final mkrReg = RegExp(r'^(\d+[а-яА-Я]*)(?:\-й)?\s+(?:микрорайон|мкр)', caseSensitive: false);
            final mkrMatch = mkrReg.firstMatch(d.name);
            if (mkrMatch != null) {
              compactName = mkrMatch.group(1)!;
            } else {
              final numReg = RegExp(r'(\d+[а-яА-Я]*)');
              final numMatch = numReg.firstMatch(d.name);
              if (numMatch != null) {
                final numPart = numMatch.group(1)!;
                compactName = d.name.toLowerCase().contains('квартал') ? 'К$numPart' : numPart;
              } else if (d.name.length > 5) {
                compactName = '${d.name.substring(0, 3)}.';
              }
            }

            return Tooltip(
              message: d.name,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isActive) {
                      _selectedDistricts.remove(d.id);
                    } else {
                      _selectedDistricts.add(d.id);
                    }
                  });
                  _saveSettings();

                  // Write/show full name when clicking on the icon
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(d.name),
                      duration: const Duration(milliseconds: 1500),
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  width: 44,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive
                        ? PulseColors.primary.withOpacity(0.16)
                        : PulseColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive
                          ? PulseColors.primary.withOpacity(0.6)
                          : PulseColors.borderStrong,
                      width: isActive ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    compactName,
                    style: TextStyle(
                      fontSize: compactName.length > 3 ? 10 : 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? PulseColors.primary : PulseColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildThemeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Row(
            children: [
              Icon(Icons.wallpaper_rounded, size: 18, color: PulseColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Тема фона приложения',
                style: TextStyle(color: PulseColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: PulseColors.primary,
            collapsedIconColor: PulseColors.textSecondary,
            title: Text(
              'Бесплатные темы',
              style: TextStyle(color: PulseColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            leading: Icon(Icons.palette_outlined, color: PulseColors.textSecondary, size: 20),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 4),
            children: _freeThemes.map((t) => _buildThemeTile(t.$1, t.$2, false)).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: Colors.amber,
            collapsedIconColor: Colors.amber.withOpacity(0.6),
            title: const Text(
              'Премиальные VIP фоны (10 тем)',
              style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            leading: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  '💡 Все 10 VIP тем доступны по подписке Премиум. Ознакомиться с ними подробнее и примерить можно в интерактивной галерее на экране покупки Премиум-статуса.',
                  style: TextStyle(color: PulseColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic, height: 1.3),
                ),
              ),
              ..._vipThemes.map((t) => _buildThemeTile(t.$1, t.$2, true)),
            ],
          ),
        ),
      ],
    );
  }

  String _mapThemeKeyToAuraId(String key) {
    switch (key) {
      case 'aurora_borealis':
      case 'aurora_living':
        return 'aurora_borealis';
      case 'neon':
      case 'cyberpunk':
      case 'ai_core':
        return 'neon_tokyo';
      case 'glass_vip_sunset':
        return 'golden_sakura';
      case 'starfield':
      case 'gravity':
      case 'glass_vip_nebula':
      case 'constellation':
        return 'deep_cosmos';
      case 'premium_glass':
      case 'glass_vip_gold':
        return 'liquid_gold';
      case 'glass_vip_arctic':
      case 'matrix':
        return 'polar_night';
      case 'plasma_storm':
        return 'phoenix_fire';
      case 'glass_vip_emerald':
        return 'emerald_forest';
      case 'rain_on_glass':
        return 'blue_lagoon';
      case 'quantum_foam':
        return 'quantum_hologram';
      default:
        return 'aurora_borealis';
    }
  }

  Widget _buildThemeTile(String key, String label, bool isVip) {
    final isActive = _splashTheme == key;
    return GestureDetector(
      onTap: () async {
        if (isVip && !_isVip) {
          _showVipUpgradeDialog();
          return;
        }
        setState(() => _splashTheme = key);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('splash_theme', key);
        await AppStateService.instance.patch((s) => s.copyWith(splashTheme: key));
        
        // Update AuraThemeService to trigger real-time background transition
        final auraId = _mapThemeKeyToAuraId(key);
        await AuraThemeService.instance.selectTheme(auraId);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? (isVip ? Colors.amber.withOpacity(0.1) : PulseColors.primary.withOpacity(0.1))
              : PulseColors.surfaceGlass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? (isVip ? Colors.amber.withOpacity(0.5) : PulseColors.primary.withOpacity(0.5))
                : PulseColors.borderStrong,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            if (isVip)
              const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.amber)
            else
              Icon(Icons.wallpaper_rounded, size: 14, color: PulseColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? PulseColors.primary : PulseColors.textSecondary,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle_rounded,
                  size: 18,
                  color: isVip ? Colors.amber : PulseColors.primary),
          ],
        ),
      ),
    );
  }

  void _showVipUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ThemeProvider.instance.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.amber, width: 2.0),
          ),
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 48),
              SizedBox(height: 12),
              Text(
                'АКТИВАЦИЯ VIP PREMIUM',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Разблокируйте ультимативные возможности приложения СообщиО:',
                style: TextStyle(color: PulseColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildVipBenefitItem(Icons.wallpaper_rounded, 'Все 10 живых анимированных VIP-фонов'),
              _buildVipBenefitItem(Icons.bolt_rounded, 'Режим максимальной плавности (120 FPS)'),
              _buildVipBenefitItem(Icons.receipt_long_rounded, 'ИИ-Аудит тарифов ЖКХ по официальным нормам'),
              _buildVipBenefitItem(Icons.videocam_rounded, 'Доступ к скрытым камерам Нижневартовска'),
              _buildVipBenefitItem(Icons.psychology_rounded, 'Приоритетный AI-поиск по камерам и чат-помощник'),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Всего 199 ₽ / месяц\n(Первый месяц бесплатно в Демо-режиме)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ОТМЕНА', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('is_premium_vip', true);
                await prefs.setBool('is_vip', true);
                setState(() => _isVip = true);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Поздравляем! VIP Premium успешно активирован!'),
                    backgroundColor: Colors.amber,
                  ),
                );
              },
              child: const Text('АКТИВИРОВАТЬ БЕСПЛАТНО', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildVipBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSelector() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: PulseColors.surfaceGlass,
        borderRadius: AppRadii.md,
        border: Border.all(color: PulseColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 20, color: PulseColors.primary),
              const SizedBox(width: 8),
              Text(
                'Режим производительности',
                style: TextStyle(color: PulseColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Выберите частоту кадров и качество анимаций',
            style: TextStyle(color: PulseColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Eco
              Expanded(
                child: _buildPerformanceOption(
                  label: 'Эко (30 FPS)',
                  active: !_highPerformanceMode,
                  color: Colors.greenAccent,
                  onTap: () {
                    setState(() => _highPerformanceMode = false);
                    _saveSettings();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Balance
              Expanded(
                child: _buildPerformanceOption(
                  label: 'Баланс (60 FPS)',
                  active: _highPerformanceMode && !_isVip,
                  color: PulseColors.primary,
                  onTap: () {
                    setState(() => _highPerformanceMode = true);
                    _saveSettings();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Ultra VIP
              Expanded(
                child: _buildPerformanceOption(
                  label: 'Ультра (120 FPS)',
                  active: _highPerformanceMode && _isVip,
                  color: Colors.amber,
                  isVipOnly: true,
                  onTap: () {
                    if (!_isVip) {
                      _showVipUpgradeDialog();
                      return;
                    }
                    setState(() => _highPerformanceMode = true);
                    _saveSettings();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceOption({
    required String label,
    required bool active,
    required Color color,
    bool isVipOnly = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : PulseColors.textPrimary.withOpacity(0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? color.withOpacity(0.6) : PulseColors.textPrimary.withOpacity(0.08),
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            if (isVipOnly) ...[
              const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 14),
              const SizedBox(height: 2),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? color : PulseColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
