import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/city_weather_service.dart';
import 'weather/weekly_forecast_chart.dart';
import 'weather/weather_ambient_painter.dart';
import 'weather/city_alert_ticker.dart';
import 'weather/tilt_widget.dart';
import 'weather/flood_level_chart.dart';
import '../../../../widgets/aura_living_background.dart';
import '../../../../core/living/aura_living_engine.dart';
import '../../../../widgets/hologram_effect.dart';


/// Full-screen weather card with ambient animation for the map.
class WeatherOverlayPanel extends StatefulWidget {
  const WeatherOverlayPanel({
    super.key,
    required this.weather,
    required this.alerts,
    required this.onClose,
    required this.isNightMode,
    required this.accent,
  });

  final CityWeatherSnapshot weather;
  final CityAlertTickerData alerts;
  final VoidCallback onClose;
  final bool isNightMode;
  final Color accent;

  @override
  State<WeatherOverlayPanel> createState() => _WeatherOverlayPanelState();
}

class _WeatherOverlayPanelState extends State<WeatherOverlayPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _slowController;
  int _activeTab = 0;
  bool _showWeeklyForecastOnBack = false;

  // Selected weather kind and simulated stats
  late String _selectedKind;
  late int? _displayTemp;
  late int? _displayFeels;
  late String _displayCondition;
  late String _displayAqiLevel;
  late String _displayAqiSummary;
  late num? _displayAqiValue;
  late double? _displayWindSpeed;
  late double? _displayWindGusts;
  late int? _displayHumidity;
  late double? _displayPressure;
  late String? _displaySolarFlare;
  late double? _displaySchumannFreq;
  late double? _displaySchumannAmp;
  double? _displayUvIndex;
  double? _displayKpIndex;

  final List<Map<String, dynamic>> _demoConditions = [
    {
      'kind': 'clear',
      'label': 'Ясно',
      'icon': Icons.wb_sunny_rounded,
      'nightIcon': Icons.nightlight_round,
      'temp': 22,
      'feels': 21,
      'conditionText': 'Ясно',
      'aqi': 25,
      'aqiText': 'ОТЛИЧНО',
      'aqiSummary': 'Индекс качества воздуха в норме. Идеальное время для прогулок и спорта на открытом воздухе.',
      'wind': 3.0,
      'gusts': 5.0,
      'humidity': 45,
      'pressure': 762.0,
      'flare': 'C1.2',
      'schumannFreq': 7.83,
      'schumannAmp': 14.2,
      'uv': 6.2,
      'kp': 1.8,
    },
    {
      'kind': 'cloudy',
      'label': 'Облачно',
      'icon': Icons.cloud_rounded,
      'nightIcon': Icons.cloud_rounded,
      'temp': 17,
      'feels': 16,
      'conditionText': 'Пасмурно',
      'aqi': 35,
      'aqiText': 'ХОРОШО',
      'aqiSummary': 'Качество воздуха хорошее. Загрязнение атмосферы минимальное, риски отсутствуют.',
      'wind': 4.5,
      'gusts': 8.0,
      'humidity': 60,
      'pressure': 754.0,
      'flare': null,
      'schumannFreq': 7.83,
      'schumannAmp': 11.5,
      'uv': 2.5,
      'kp': 2.0,
    },
    {
      'kind': 'rain',
      'label': 'Дождь',
      'icon': Icons.grain_rounded,
      'nightIcon': Icons.grain_rounded,
      'temp': 12,
      'feels': 10,
      'conditionText': 'Умеренный дождь',
      'aqi': 15,
      'aqiText': 'ОТЛИЧНО',
      'aqiSummary': 'Осадки очистили воздух от пыли и взвешенных частиц. Дышится легко.',
      'wind': 5.5,
      'gusts': 11.0,
      'humidity': 88,
      'pressure': 748.0,
      'flare': null,
      'schumannFreq': 7.85,
      'schumannAmp': 12.8,
      'uv': 0.8,
      'kp': 1.5,
    },
    {
      'kind': 'storm',
      'label': 'Гроза',
      'icon': Icons.thunderstorm_rounded,
      'nightIcon': Icons.thunderstorm_rounded,
      'temp': 15,
      'feels': 13,
      'conditionText': 'Гроза с ливнем',
      'aqi': 18,
      'aqiText': 'ОТЛИЧНО',
      'aqiSummary': 'Возможна повышенная концентрация озона во время разрядов молний. Будьте осторожны.',
      'wind': 9.0,
      'gusts': 18.0,
      'humidity': 95,
      'pressure': 742.0,
      'flare': 'M3.4',
      'schumannFreq': 8.12,
      'schumannAmp': 24.5,
      'uv': 0.4,
      'kp': 5.2,
    },
    {
      'kind': 'snow',
      'label': 'Снег',
      'icon': Icons.ac_unit_rounded,
      'nightIcon': Icons.ac_unit_rounded,
      'temp': -4,
      'feels': -9,
      'conditionText': 'Снегопад',
      'aqi': 20,
      'aqiText': 'ОТЛИЧНО',
      'aqiSummary': 'Свежий снегопад. Воздух кристально чистый, оседание выхлопных газов.',
      'wind': 6.0,
      'gusts': 12.0,
      'humidity': 85,
      'pressure': 750.0,
      'flare': null,
      'schumannFreq': 7.83,
      'schumannAmp': 9.8,
      'uv': 0.2,
      'kp': 1.2,
    },
    {
      'kind': 'wind',
      'label': 'Ветер',
      'icon': Icons.air_rounded,
      'nightIcon': Icons.air_rounded,
      'temp': 14,
      'feels': 11,
      'conditionText': 'Штормовой ветер',
      'aqi': 55,
      'aqiText': 'УМЕРЕННО',
      'aqiSummary': 'Сильный ветер поднимает пыль с земли. Людям с аллергией рекомендуется носить маски.',
      'wind': 12.0,
      'gusts': 22.0,
      'humidity': 50,
      'pressure': 745.0,
      'flare': 'C2.1',
      'schumannFreq': 7.92,
      'schumannAmp': 16.4,
      'uv': 3.1,
      'kp': 4.0,
    },
    {
      'kind': 'fog',
      'label': 'Туман',
      'icon': Icons.blur_on_rounded,
      'nightIcon': Icons.blur_on_rounded,
      'temp': 8,
      'feels': 7,
      'conditionText': 'Густой туман',
      'aqi': 75,
      'aqiText': 'ЗАГРЯЗНЕНИЕ',
      'aqiSummary': 'Высокая влажность способствует накоплению вредных примесей у поверхности земли.',
      'wind': 1.5,
      'gusts': 3.0,
      'humidity': 98,
      'pressure': 756.0,
      'flare': null,
      'schumannFreq': 7.83,
      'schumannAmp': 10.2,
      'uv': 0.7,
      'kp': 1.0,
    },
  ];

  bool get _isNight {
    if (widget.weather.available) {
      return !widget.weather.isDay;
    }
    final hour = DateTime.now().hour;
    return hour < 7 || hour > 21;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _slowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _initDisplayData();
  }

  void _initDisplayData() {
    _selectedKind = widget.weather.kind;
    _displayTemp = widget.weather.temperatureC?.round();
    _displayFeels = widget.weather.feelsLikeC?.round();
    _displayCondition = widget.weather.condition;
    _displayAqiLevel = widget.weather.airQualityLevel;
    _displayAqiSummary = widget.weather.airQualitySummary;
    _displayAqiValue = widget.weather.europeanAqi;
    _displayWindSpeed = widget.weather.windSpeedMs;
    _displayWindGusts = widget.weather.windGustsMs;
    _displayHumidity = widget.weather.humidityPct;
    _displayPressure = widget.weather.pressureMmHg;
    _displaySolarFlare = widget.weather.solarFlare;
    _displaySchumannFreq = widget.weather.schumannFreqHz;
    _displaySchumannAmp = widget.weather.schumannAmpPt;
    _displayUvIndex = widget.weather.uvIndex;
    _displayKpIndex = widget.weather.kpIndex;

    // If API returned empty/missing, assign defaults of current kind
    if (!widget.weather.available || _displayTemp == null) {
      _selectCondition(_selectedKind, updateState: false);
    }

    // Play alert sound if anomaly exists on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasAnomaly) {
        _playAlertSound();
      }
    });
  }

  @override
  void didUpdateWidget(WeatherOverlayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weather.kind != widget.weather.kind ||
        oldWidget.weather.temperatureC != widget.weather.temperatureC) {
      _initDisplayData();
    }
  }

  bool get _hasAnomaly {
    if (_displaySchumannFreq != null && (_displaySchumannFreq! < 7.7 || _displaySchumannFreq! > 8.0)) return true;
    if (_displayPressure != null && (_displayPressure! < 748 || _displayPressure! > 768)) return true;
    if (_displaySolarFlare != null && (_displaySolarFlare!.startsWith('M') || _displaySolarFlare!.startsWith('X') || _displaySolarFlare!.startsWith('C'))) return true;
    if (_displaySchumannAmp != null && _displaySchumannAmp! > 15.0) return true;
    if (_displayWindSpeed != null && _displayWindSpeed! > 10.0) return true;
    return false;
  }



  void _playAlertSound() {
    SystemSound.play(SystemSoundType.click);
    Future.delayed(const Duration(milliseconds: 150), () {
      SystemSound.play(SystemSoundType.click);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      SystemSound.play(SystemSoundType.click);
    });
  }

  void _selectCondition(String kind, {bool updateState = true}) {
    final demo = _demoConditions.firstWhere(
      (e) => e['kind'] == kind,
      orElse: () => _demoConditions.first,
    );
    void newState() {
      _selectedKind = kind;
      _displayTemp = demo['temp'];
      _displayFeels = demo['feels'];
      _displayCondition = demo['conditionText'];
      _displayAqiLevel = demo['aqiText'];
      _displayAqiSummary = demo['aqiSummary'];
      _displayAqiValue = demo['aqi'];
      _displayWindSpeed = demo['wind'];
      _displayWindGusts = demo['gusts'];
      _displayHumidity = demo['humidity'];
      _displayPressure = demo['pressure'];
      _displaySolarFlare = demo['flare'];
      _displaySchumannFreq = demo['schumannFreq'];
      _displaySchumannAmp = demo['schumannAmp'];
      _displayUvIndex = demo['uv'];
      _displayKpIndex = demo['kp'];
    }

    if (updateState) {
      setState(newState);
      if (_hasAnomaly) {
        _playAlertSound();
      }
    } else {
      newState();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _slowController.dispose();
    super.dispose();
  }

  Widget _spaceParam(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap ?? () => _showParamDetailDialog(label, value),
        child: Row(
          children: [
            Icon(icon, size: 20, color: widget.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: _isNight ? Colors.white54 : Colors.black45,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: _isNight ? Colors.white : Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showParamDetailDialog(String paramName, String currentValue) {
    final Map<String, Map<String, String>> paramInfo = {
      'Давление': {
        'description': 'Атмосферное давление — сила, с которой столб воздуха давит на поверхность.',
        'norm': '755–770 мм рт.ст. (нормальное давление для Нижневартовска)',
        'low': '< 740 — возможны головные боли, усталость',
        'high': '> 780 — дискомфорт у метеочувствительных людей',
      },
      'Вспышки': {
        'description': 'Солнечные вспышки — мощные выбросы энергии на Солнце, влияющие на магнитосферу.',
        'norm': 'Классы A-B: спокойная обстановка',
        'low': 'Класс C: слабые вспышки, минимальное влияние',
        'high': 'Классы M-X: сильные вспышки, возможны геомагнитные бури',
      },
      'Резонанс Шумана': {
        'description': 'Стоячие электромагнитные волны в полости Земля-ионосфера.',
        'norm': '7.83 Гц — основная частота (норма)',
        'low': '< 7.5 Гц — пониженная активность',
        'high': '> 15 Гц — повышенная электромагнитная активность, стресс',
      },
      'Амплитуда': {
        'description': 'Амплитуда резонанса Шумана — показатель интенсивности электромагнитного фона.',
        'norm': '1–5 pT — нормальные значения',
        'low': '< 1 pT — тихий фон',
        'high': '> 10 pT — повышенная активность, влияет на самочувствие',
      },
      'Ветер': {
        'description': 'Скорость ветра — горизонтальное перемещение воздушных масс.',
        'norm': '0–5 м/с — штиль/слабый ветер',
        'low': '5–10 м/с — умеренный',
        'high': '> 15 м/с — сильный ветер, возможны предупреждения',
      },
      'Порывы': {
        'description': 'Порывы ветра — кратковременное усиление скорости выше средней.',
        'norm': '< 10 м/с — безопасные порывы',
        'low': '10–15 м/с — умеренные',
        'high': '> 20 м/с — опасные порывы, МЧС предупреждения',
      },
      'Сейсмика': {
        'description': 'Сейсмическая активность — колебания земной коры в регионе.',
        'norm': '0–2 балла — фоновая активность, не ощущается',
        'low': '2–4 балла — слабые толчки, ощущаются в зданиях',
        'high': '> 5 баллов — значимое землетрясение, возможны разрушения',
      },
      'Видимость': {
        'description': 'Метеорологическая дальность видимости — расстояние различимости объектов.',
        'norm': '> 10 км — отличная видимость',
        'low': '1–4 км — пониженная (туман, дымка)',
        'high': '< 1 км — плохая видимость, опасно для движения',
      },
    };

    final info = paramInfo[paramName] ?? {
      'description': 'Информация о параметре $paramName',
      'norm': 'Данные загружаются...',
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isNight
            ? const Color(0xFF0F172A).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: widget.accent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                paramName,
                style: TextStyle(
                  color: _isNight ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    'Сейчас: ',
                    style: TextStyle(
                      color: _isNight ? Colors.white54 : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      currentValue,
                      style: TextStyle(
                        color: widget.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              info['description'] ?? '',
              style: TextStyle(
                color: _isNight ? Colors.white70 : Colors.black87,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            _paramInfoRow('✅ Норма', info['norm'] ?? ''),
            const SizedBox(height: 6),
            _paramInfoRow('⚠️ Внимание', info['low'] ?? ''),
            const SizedBox(height: 6),
            _paramInfoRow('🔴 Опасно', info['high'] ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Закрыть', style: TextStyle(color: widget.accent)),
          ),
        ],
      ),
    );
  }

  Widget _paramInfoRow(String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
          color: _isNight ? Colors.white54 : Colors.black54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(
            color: _isNight ? Colors.white70 : Colors.black87,
            fontSize: 12,
          )),
        ),
      ],
    );
  }

  Widget _buildConditionSelector() {
    final themeBg = _isNight
        ? Colors.white.withAlpha(20)
        : Colors.black.withAlpha(12);

    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: themeBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.accent.withAlpha(60),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: _demoConditions.length,
          itemBuilder: (context, index) {
            final item = _demoConditions[index];
            final kind = item['kind'] as String;
            final label = item['label'] as String;
            final isSelected = _selectedKind == kind;
            final icon = (_isNight ? item['nightIcon'] : item['icon']) as IconData;

            final activeBg = isSelected
                ? widget.accent.withAlpha(70)
                : Colors.transparent;

            final activeBorder = isSelected
                ? widget.accent.withAlpha(140)
                : Colors.transparent;

            final scale = isSelected ? 1.08 : 1.0;

            return GestureDetector(
              onTap: () => _selectCondition(kind),
              child: AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: activeBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: activeBorder, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: isSelected
                            ? Colors.white
                            : (_isNight ? Colors.white60 : Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (_isNight ? Colors.white70 : Colors.black87),
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
  }

  Widget _buildGlassCard({required Widget child, Key? key}) {
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isNight
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isNight
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildCurrentWeatherFrontCard({required Key key}) {
    return _buildGlassCard(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _displayTemp == null ? '—' : '$_displayTemp°',
                style: TextStyle(
                  color: _isNight
                      ? Colors.white
                      : const Color(0xFF0A2540),
                  fontSize: 76,
                  fontWeight: FontWeight.w200,
                  height: 0.95,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayCondition,
                      style: TextStyle(
                        color: widget.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_displayHumidity != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Влажность $_displayHumidity%',
                        style: TextStyle(
                          color: _isNight ? Colors.white70 : Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_displayFeels != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Ощущается как $_displayFeels°',
                style: TextStyle(
                  color: _isNight
                      ? Colors.white54
                      : Colors.black45,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                Icons.flip_camera_android_rounded,
                size: 14,
                color: _isNight ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(width: 4),
              Text(
                'Нажми для прогноза на неделю',
                style: TextStyle(
                  fontSize: 11,
                  color: _isNight ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBackCard({required Key key}) {
    return _buildGlassCard(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Прогноз на неделю',
                style: TextStyle(
                  color: widget.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(
                Icons.flip_camera_android_rounded,
                size: 14,
                color: _isNight ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
          const SizedBox(height: 14),
          WeeklyForecastChart(
            isNightMode: _isNight,
            accent: widget.accent,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Нажми, чтобы вернуться',
              style: TextStyle(
                fontSize: 11,
                color: _isNight ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _isNight
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: _isNight
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(0, 'Условия'),
          ),
          Expanded(
            child: _buildTabButton(1, 'Инфо'),
          ),
          Expanded(
            child: _buildTabButton(2, 'Паводок'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.accent.withOpacity(_isNight ? 0.22 : 0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (_isNight ? Colors.white60 : Colors.black87),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAnomalyWarnings() {
    final List<Widget> warnings = [];
    if (_displayPressure != null && (_displayPressure! < 748 || _displayPressure! > 768)) {
      warnings.add(_buildWarningCard(
        Icons.compress_rounded,
        'Атмосферное давление',
        'Атмосферное давление составляет ${_displayPressure!.round()} мм рт. ст. (норма 748-768). Рекомендуется соблюдать спокойный режим при повышенной чувствительности к перепадам давления.',
      ));
    }
    if (_displaySolarFlare != null && (_displaySolarFlare!.startsWith('M') || _displaySolarFlare!.startsWith('X') || _displaySolarFlare!.startsWith('C'))) {
      warnings.add(_buildWarningCard(
        Icons.wb_sunny_rounded,
        'Повышенная солнечная активность',
        'Зафиксирована солнечная вспышка класса $_displaySolarFlare. Постарайтесь избегать чрезмерных нагрузок, пить достаточно чистой воды и планировать день размеренно.',
      ));
    }
    if (_displaySchumannFreq != null && (_displaySchumannFreq! < 7.7 || _displaySchumannFreq! > 8.0)) {
      warnings.add(_buildWarningCard(
        Icons.waves_rounded,
        'Колебания частоты Шумана',
        'Базовая частота резонанса Шумана сместилась до $_displaySchumannFreq Гц (норма 7.83 Гц). Возможны кратковременные изменения естественного электромагнитного фона планеты.',
      ));
    }
    if (_displaySchumannAmp != null && _displaySchumannAmp! > 15.0) {
      warnings.add(_buildWarningCard(
        Icons.flash_on_rounded,
        'Всплеск амплитуды Шумана',
        'Зарегистрировано кратковременное повышение амплитуды Шумана до $_displaySchumannAmp pT (норма <=15.0). Рекомендуется уделить внимание отдыху и спокойной деятельности.',
      ));
    }
    if (_displayWindSpeed != null && _displayWindSpeed! > 10.0) {
      warnings.add(_buildWarningCard(
        Icons.air_rounded,
        'Штормовой ветер',
        'Скорость ветра достигает ${_displayWindSpeed!.toStringAsFixed(0)} м/с (порывы до ${_displayWindGusts?.toStringAsFixed(0) ?? '—'} м/с). Не находитесь вблизи рекламных щитов, старых деревьев и легких конструкций.',
      ));
    }
    return warnings;
  }

  Widget _buildWarningCard(IconData icon, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withOpacity(_isNight ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF97316).withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFF97316), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF97316),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _isNight ? Colors.white.withOpacity(0.87) : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isEmergencyAlert(dynamic item) {
    if (item == null) return false;
    final category = (item['category']?.toString() ?? '').toLowerCase();
    final text = (item['text']?.toString() ?? '').toLowerCase();
    return category.contains('чп') ||
        text.contains('чп') ||
        text.contains('пожар') ||
        text.contains('взрыв') ||
        category.contains('авари') ||
        category.contains('дтп') ||
        text.contains('авари') ||
        text.contains('дтп') ||
        category.contains('преступ') ||
        text.contains('преступ');
  }

  List<Widget> _buildChannelWarnings() {
    final List<Widget> cards = [];
    final items = widget.alerts.items;
    
    // Filter to only include ЧП (emergencies), accidents (аварии), and crimes (преступления)
    final filtered = items.where(_isEmergencyAlert).toList();
    
    for (final item in filtered) {
      final category = item['category']?.toString() ?? 'Прочее';
      final text = item['text']?.toString() ?? '';
      
      IconData icon = Icons.info_outline_rounded;
      Color color = widget.accent;
      
      final lowerCat = category.toLowerCase();
      final lowerText = text.toLowerCase();
      
      if (lowerCat.contains('чп') || lowerText.contains('чп') || lowerText.contains('пожар') || lowerText.contains('взрыв')) {
        icon = Icons.error_outline_rounded;
        color = const Color(0xFFEF4444);
      } else if (lowerCat.contains('авари') || lowerCat.contains('дтп') || lowerText.contains('авари') || lowerText.contains('дтп')) {
        icon = Icons.car_crash_rounded;
        color = const Color(0xFFEAB308);
      } else if (lowerCat.contains('кримин') || lowerCat.contains('преступ') || lowerText.contains('драка') || lowerText.contains('краж')) {
        icon = Icons.local_police_rounded;
        color = const Color(0xFF8B5CF6);
      }
      
      cards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(_isNight ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        if (item['time'] != null)
                          Text(
                            item['time'].toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: _isNight ? Colors.white38 : Colors.black38,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: _isNight ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (cards.isEmpty) {
      cards.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 48,
                  color: _isNight ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 12),
                Text(
                  'Активных городских предупреждений нет',
                  style: TextStyle(
                    fontSize: 13,
                    color: _isNight ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AuraLivingBackground(
        scene: AuraLivingEngine.resolve(
          practice: AuraPractice.home,
          mood: 0,
          streak: 1,
          meditationMinutes: 0,
          practicesCompleted: 0,
          isPremium: true,
          hour: DateTime.now().hour,
        ),
        showSignatureObject: false,
        showConstellationVeil: false,
        interactive: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_controller, _slowController]),
                builder: (context, _) => CustomPaint(
                  painter: WeatherAmbientPainter(
                    kind: _selectedKind,
                    progress: _controller.value,
                    slowProgress: _slowController.value,
                    isNight: _isNight,
                    accent: widget.accent,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: widget.onClose,
                        icon: Icon(
                          Icons.close_rounded,
                          color: _isNight
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                    ),
                    Text(
                      'Нижневартовск',
                      style: TextStyle(
                        color: _isNight
                            ? Colors.white60
                            : Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTabSelector(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _activeTab == 0
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TiltWidget(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _showWeeklyForecastOnBack = !_showWeeklyForecastOnBack;
                                        });
                                      },
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 600),
                                        transitionBuilder: (Widget child, Animation<double> animation) {
                                          final rotateAnim = Tween(begin: math.pi, end: 0.0).animate(animation);
                                          return AnimatedBuilder(
                                            animation: rotateAnim,
                                            child: child,
                                            builder: (context, child) {
                                              final angle = rotateAnim.value;
                                              // Hide the card when it's past 90° (showing the wrong side)
                                              if (angle.abs() > math.pi / 2) {
                                                return Opacity(opacity: 0.0, child: child);
                                              }
                                              return Transform(
                                                transform: Matrix4.identity()
                                                  ..setEntry(3, 2, 0.0012)
                                                  ..rotateY(angle),
                                                alignment: Alignment.center,
                                                child: child,
                                              );
                                            },
                                          );
                                        },
                                        layoutBuilder: (widget, list) => Stack(children: [widget!, ...list]),
                                        child: _showWeeklyForecastOnBack
                                            ? _buildWeeklyBackCard(key: const ValueKey('back'))
                                            : _buildCurrentWeatherFrontCard(key: const ValueKey('front')),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),
                                  
                                  TiltWidget(
                                    child: _buildGlassCard(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Качество воздуха',
                                            style: TextStyle(
                                              color: _isNight
                                                  ? Colors.white70
                                                  : Colors.black54,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _displayAqiLevel.toUpperCase(),
                                            style: TextStyle(
                                              color: _aqColor(_displayAqiValue),
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (_displayAqiSummary.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Text(
                                                _displayAqiSummary,
                                                style: TextStyle(
                                                  color: _isNight
                                                      ? Colors.white60
                                                      : Colors.black54,
                                                  fontSize: 12,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  TiltWidget(
                                    child: _buildGlassCard(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Параметры атмосферы и космоса',
                                            style: TextStyle(
                                              color: _isNight
                                                  ? Colors.white70
                                                  : Colors.black54,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _spaceParam(
                                                Icons.compress_rounded,
                                                'Давление',
                                                _displayPressure != null ? '${_displayPressure!.round()} мм рт. ст.' : '—',
                                              ),
                                              _spaceParam(
                                                Icons.wb_sunny_rounded,
                                                'Вспышки',
                                                _displaySolarFlare != null ? 'Класс $_displaySolarFlare' : '—',
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 24, color: Colors.white10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _spaceParam(
                                                Icons.waves_rounded,
                                                'Резонанс Шумана',
                                                _displaySchumannFreq != null
                                                    ? '$_displaySchumannFreq Гц'
                                                    : '—',
                                              ),
                                              _spaceParam(
                                                Icons.flash_on_rounded,
                                                'Амплитуда',
                                                _displaySchumannAmp != null
                                                    ? '$_displaySchumannAmp pT'
                                                    : '—',
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 24, color: Colors.white10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _spaceParam(
                                                Icons.air_rounded,
                                                'Ветер',
                                                _displayWindSpeed != null
                                                    ? '${_displayWindSpeed!.toStringAsFixed(0)} м/с'
                                                    : '—',
                                              ),
                                              _spaceParam(
                                                Icons.storm_rounded,
                                                'Порывы',
                                                _displayWindGusts != null
                                                    ? '${_displayWindGusts!.toStringAsFixed(0)} м/с'
                                                    : '—',
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 24, color: Colors.white10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _spaceParam(
                                                Icons.vibration_rounded,
                                                'Сейсмика',
                                                '0 баллов',
                                              ),
                                              _spaceParam(
                                                Icons.visibility_rounded,
                                                'Видимость',
                                                '> 10 км',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : _activeTab == 1
                                ? HologramEffect(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (_hasAnomaly) ...[
                                          Text(
                                            'Геокосмические предупреждения',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _isNight ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TiltWidget(
                                            child: Column(
                                              children: _buildAnomalyWarnings(),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        Text(
                                          'Информационные каналы',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _isNight ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ..._buildChannelWarnings(),
                                      ],
                                    ),
                                  )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FloodLevelChart(
                                      isNightMode: _isNight,
                                      accent: widget.accent,
                                    ),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Color _aqColor(num? aqi) {
    if (aqi == null) return widget.accent;
    if (aqi <= 40) return const Color(0xFF34D399);
    if (aqi <= 60) return const Color(0xFFFBBF24);
    if (aqi <= 80) return const Color(0xFFFB923C);
    return const Color(0xFFEF4444);
  }


}
