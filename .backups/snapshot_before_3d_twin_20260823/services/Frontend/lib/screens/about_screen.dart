import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_branding.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/dynamic_animated_background.dart';
import '../widgets/aura_living_background.dart';
import '../core/living/aura_living_engine.dart';
import 'developer_menu_screen.dart';
import 'mesh_screen.dart';
import 'map_screen.dart';
import '../widgets/premium/index.dart';
import '../services/app_state_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({
    super.key,
    this.initialTab = 0,
    this.isOnboarding = false,
  });

  final int initialTab;
  final bool isOnboarding;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _consentAccepted = false;
  static const Duration _adminTapWindow = Duration(seconds: 4);
  static const int _adminTapTarget = 10;

  Timer? _adminTapResetTimer;
  int _adminTapCount = 0;

  static const List<_FeatureInfo> _features = <_FeatureInfo>[
    _FeatureInfo(
      title: 'Интерактивная карта',
      icon: Icons.map_rounded,
      description:
          'Двухрежимная карта (день/ночь) с сигналами жителей, мероприятиями, АЗС с ценами на бензин, камерами и адресными метками. Поддержка города Нижневартовск.',
    ),
    _FeatureInfo(
      title: 'AI-дайджест',
      icon: Icons.auto_awesome_rounded,
      description:
          'Автоматическая сводка городских событий за сегодня на базе ИИ. Мониторинг Telegram-каналов и VK-пабликов с классификацией по категориям.',
    ),
    _FeatureInfo(
      title: 'Городские камеры',
      icon: Icons.videocam_rounded,
      description:
          '130+ камер видеонаблюдения на карте с HLS-стримингом через прокси-сервер. AI-анализ кадров камер с описанием обстановки.',
    ),
    _FeatureInfo(
      title: 'Жалобы и обращения',
      icon: Icons.report_problem_rounded,
      description:
          'Анонимная подача обращений с фото, GPS-координатами и AI-классификацией. Автоматическое определение адреса и управляющей компании.',
    ),
    _FeatureInfo(
      title: 'Управляющие компании',
      icon: Icons.business_rounded,
      description:
          'Каталог из 42+ УК: рейтинг на основе жалоб, контакты и список обслуживаемых домов с визуализацией на карте.',
    ),
    _FeatureInfo(
      title: 'Погода и экология',
      icon: Icons.cloud_rounded,
      description:
          'Детальная метеосводка: температура, давление, ветер, влажность, видимость, фаза луны. Индекс качества воздуха (AQI) и сейсмическая активность.',
    ),
    _FeatureInfo(
      title: 'Голосовой ассистент',
      icon: Icons.record_voice_over_rounded,
      description:
          'Озвучивание городских событий и уведомлений. Голосовой ввод обращений. Push-уведомления с бегущей строкой.',
    ),
    _FeatureInfo(
      title: 'Mesh-сеть',
      icon: Icons.hub_rounded,
      description:
          'Локальная очередь обращений и подготовка к автономной работе без интернета через технологию Bluetooth Mesh.',
    ),
  ];

  @override
  void dispose() {
    _adminTapResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleAdminTap() async {
    _adminTapResetTimer?.cancel();
    _adminTapCount += 1;

    if (_adminTapCount >= _adminTapTarget) {
      _adminTapCount = 0;
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DeveloperMenuScreen(),
        ),
      );
      return;
    }

    _adminTapResetTimer = Timer(_adminTapWindow, () {
      _adminTapCount = 0;
    });
  }

  Widget _buildOnboardingView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          // Logo & Branding
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PulseColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PulseColors.primary.withOpacity(0.7), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: PulseColors.primary.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: PulseColors.primarySoft,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'CITY PULSE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      color: PulseColors.primary.withOpacity(0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Интеллектуальная платформа двух городов',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Nizhnevartovsk & Novosibirsk Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: PulseColors.accentGold.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PulseColors.accentGold.withAlpha(90), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: PulseColors.accentGold.withAlpha(10),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_city_rounded, color: PulseColors.accentGold, size: 13),
                const SizedBox(width: 6),
                Text(
                  'Нижневартовск',
                  style: TextStyle(
                    color: PulseColors.accentGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Features List scrollable area
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _features.length,
              itemBuilder: (context, index) {
                final feat = _features[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? const Color(0xFF0F172A).withOpacity(0.4) 
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: PulseColors.primary.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: PulseColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(feat.icon, color: PulseColors.primarySoft, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    feat.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    feat.description,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      height: 1.4,
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
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isOnboarding) {
      return PulseOnboardingSwipe(
        onComplete: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('first_launch_accepted', true);
          await prefs.setBool('seen_onboarding', true);
          await AppStateService.instance.saveLastRoute('/map');
          if (!context.mounted) return;
          try {
            context.go('/map');
          } catch (_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          }
        },
      );
    }

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Stack(
        children: [
          const Positioned.fill(
            child: AuraLivingBackground(
              scene: AuraLivingScene(
                weather: AuraWeather.technoCivic,
                practice: AuraPractice.premium,
                palette: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF09101D)],
              ),
              interactive: false,
              showConstellationVeil: false,
              child: SizedBox.expand(),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: AppScreenBackground(
              accent: PulseColors.primarySoft,
              child: SafeArea(
                child: widget.isOnboarding 
                    ? _buildOnboardingView(context)
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                BackButton(color: scheme.primary),
                                Expanded(
                                  child: Text(
                                    'О проекте & Документы',
                                    style: AppTextStyles.section,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: PulseColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: scheme.surface.withAlpha(120),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              labelColor: scheme.primary,
                              unselectedLabelColor: scheme.onSurface.withAlpha(120),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              indicator: BoxDecoration(
                                color: scheme.primary.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              tabs: const [
                                Tab(text: 'О проекте'),
                                Tab(text: 'Условия'),
                                Tab(text: 'Конфиденциальность'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildAboutTab(),
                                _buildTermsTab(),
                                _buildPrivacyTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            bottomNavigationBar: widget.isOnboarding
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? const Color(0xFF0F172A).withOpacity(0.85) 
                              : Colors.white.withOpacity(0.85),
                          border: Border(
                            top: BorderSide(
                              color: PulseColors.primary.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _consentAccepted,
                                    activeColor: PulseColors.primary,
                                    checkColor: Colors.black,
                                    onChanged: (val) {
                                      setState(() {
                                        _consentAccepted = val ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _consentAccepted = !_consentAccepted;
                                        });
                                      },
                                      child: Text(
                                        'Я даю согласие на обработку персональных данных и соглашаюсь с условиями использования',
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : Colors.black87,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _consentAccepted 
                                            ? PulseColors.primary 
                                            : PulseColors.primary.withOpacity(0.12),
                                        foregroundColor: _consentAccepted ? Colors.black : Colors.white24,
                                        elevation: _consentAccepted ? 8 : 0,
                                        shadowColor: PulseColors.primary.withOpacity(0.4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      onPressed: !_consentAccepted
                                          ? null
                                          : () async {
                                              final prefs = await SharedPreferences.getInstance();
                                              await prefs.setBool('first_launch_accepted', true);
                                              await prefs.setBool('seen_onboarding', true);
                                              await AppStateService.instance.saveLastRoute('/map');
                                              if (!context.mounted) return;
                                              try {
                                                context.go('/map');
                                              } catch (_) {
                                                Navigator.of(context).pushReplacement(
                                                  MaterialPageRoute(builder: (_) => const MapScreen()),
                                                );
                                              }
                                            },
                                      child: const Text(
                                        'Принять и продолжить',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          ), // Scaffold
        ],
      ), // Stack
    );
  }

  Widget _buildAboutTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.md),
        _buildSummary(),
        const SizedBox(height: AppSpacing.lg),
        _buildFeaturesSection(),
        const SizedBox(height: AppSpacing.lg),
        _buildQuickActions(),
        const SizedBox(height: AppSpacing.lg),
        _buildVersionTile(),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildSummary() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Что делает проект', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Проект представляет собой автономную систему мониторинга города. Приложение фиксирует сигналы и мероприятия на карте, использует AI для анализа обстановки с видеокамер, локально распознает образы на фото, автоматически определяет вашу управляющую компанию по геопозиции и поддерживает работу в условиях отсутствия связи через Mesh-сеть.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Функции проекта', style: AppTextStyles.section),
        const SizedBox(height: AppSpacing.sm),
        for (final feat in _features) ...[
          _GlassPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: PulseColors.primary.withOpacity(0.14),
                    borderRadius: AppRadii.sm,
                  ),
                  child: Icon(feat.icon, color: PulseColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feat.title, style: AppTextStyles.cardTitle),
                      const SizedBox(height: AppSpacing.xs),
                      Text(feat.description, style: AppTextStyles.body),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildQuickActions() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Быстрые действия', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppSecondaryButton(
                  label: 'Mesh-сеть',
                  icon: Icons.hub_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MeshScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionTile() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_handleAdminTap()),
      child: AppPanel(
        backgroundColor: PulseColors.surfaceSoft.withOpacity(0.28),
        child: Column(
          children: [
            Text('CITY PULSE / ПУЛЬС ГОРОДА', style: AppTextStyles.cardTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Версия 2.2 · карта · камеры · mesh · premium · admin runtime',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.md),
        _section(
          '1. Предмет соглашения и статус сервиса',
          'Настоящее Пользовательское соглашение (далее — Соглашение) является публичной офертой и регулирует порядок использования цифровой платформы «Пульс города / City Pulse» (далее — Приложение). '
          'Приложение является независимой цифровой системой оперативного общественного мониторинга городской среды г. Нижневартовска. '
          'Установка, запуск или использование любых функций Приложения означает безоговорочное принятие Пользователем условий настоящего Соглашения.',
        ),
        _section(
          '2. Подача сигналов и обращений (59-ФЗ, ЖК РФ)',
          'Пользователи имеют право направлять сигналы о проблемах благоустройства, ЖКХ, дорожного полотна и безопасности. '
          'Формируемые через Приложение официальные обращения подлежат рассмотрению в соответствии с Федеральным законом от 02.05.2006 № 59-ФЗ «О порядке рассмотрения обращений граждан Российской Федерации». '
          'Пользователь обязуется не публиковать заведомо ложные сведения, клевету, материалы экстремистского характера и ненормативную лексику.',
        ),
        _section(
          '3. Сквозное шифрование и защита передачи данных',
          'Все клиент-серверные запросы защищены протоколами сквозного шифрования TLS 1.3 / HTTPS с криптографическим контролем целостности пакетов. '
          'Передаваемые медиафайлы, геолокационные координаты и тексты заявок защищены от несанкционированного перехвата третьими лицами.',
        ),
        _section(
          '4. Анонимный режим и приватность',
          'Приложение поддерживает полноценный анонимный режим фиксации городских инцидентов. '
          'В анонимном режиме идентификатор устройства (UUID), сетевой IP-адрес и системные токены не связываются с публикуемым обращением и безвозвратно удаляются из логов маршрутизации.',
        ),
        _section(
          '5. Публичные видеопотоки городских камер (ст. 152.1 ГК РФ)',
          'Трансляция видеопотоков городских камер видеонаблюдения осуществляется в строгом соответствии со ст. 152.1 Гражданского кодекса РФ (съемка в местах, открытых для свободного посещения, в целях обеспечения общественной безопасности и мониторинга дорожной обстановки). '
          'Приложение не производит биометрическую идентификацию физических лиц или слежку за частной жизнью граждан.',
        ),
        _section(
          '6. Домовой чат и взаимопомощь соседей',
          'Сервис соседской взаимопомощи и домового чата предназначен исключительно для добросовестной координации жителей выбранного дома (помощь с питомцами, бытовой инструмент, совместные поездки, уведомления об авариях УК). '
          'Передаваемые в домовом чате контактные данные для связи (Telegram, VK, телефон) публикуются пользователем добровольно.',
        ),
        _section(
          '7. Разграничение ответственности',
          'Администрация платформы предпринимает все разумные меры для обеспечения круглосуточной бесперебойной работы сервиса и верификации данных. '
          'Приложение не несет ответственности за временные перебои в работе сторонних провайдеров связи, коммунальных аварийных служб или действия управляющих организаций.',
        ),
      ],
    );
  }

  Widget _buildPrivacyTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.md),
        _section(
          '1. Оператор персональных данных и правовые основания',
          'Настоящая Политика составлена в соответствии с требованиями Федерального закона от 27.07.2006 № 152-ФЗ «О персональных данных». '
          'Правовыми основаниями обработки данных являются: согласие субъекта персональных данных, Жилищный кодекс РФ, Федеральный закон № 59-ФЗ, а также обеспечение уставной деятельности платформы городского мониторинга.',
        ),
        _section(
          '2. Состав и категории обрабатываемых данных',
          'Оператор обрабатывает следующие категории данных (исключительно при их предоставлении субъектом):\n'
          '• Данные точной геолокации устройства (с явного разрешения ОС);\n'
          '• Фото- и видеоматериалы городских сигналов, прикрепляемые пользователем;\n'
          '• Номер контактного телефона или никнейм мессенджера (при добровольном отклике в домовом чате или авторизации через Telegram/VK);\n'
          '• Технические обезличенные данные: версия ОС, идентификатор push-уведомлений.',
        ),
        _section(
          '3. Цели и принципы обработки данных',
          'Обработка данных осуществляется на основе принципов законности, соразмерности и минимизации:\n'
          '• Локализация городских проблем и направление заявок в компетентные службы ЖКХ и ЕДДС 112;\n'
          '• Оперативное push-информирование жителей об аварийных отключениях водоснабжения/тепла и паводковой обстановке;\n'
          '• Обеспечение работы защищенного домового чата соседей.',
        ),
        _section(
          '4. Хранение данных на территории Российской Федерации',
          'В соответствии со ст. 18 Федерального закона № 152-ФЗ все базы данных, содержащие персональную информацию пользователей, размещены на защищенных серверных мощностях на территории Российской Федерации. '
          'Трансграничная передача персональных данных не осуществляется.',
        ),
        _section(
          '5. Сроки обработки, отзыв согласия и удаление данных',
          'Хранение данных осуществляется не дольше, чем этого требуют цели обработки. '
          'Пользователь вправе в любой момент отозвать согласие на обработку персональных данных и потребовать полного удаления своего профиля и истории обращений через настройки Приложения либо по обращению к оператору.',
        ),
        _section(
          '6. Меры по обеспечению безопасности данных (ст. 19 152-ФЗ)',
          'Безопасность данных обеспечивается комплексом организационных и технических мер: применением шифрования каналов TLS 1.3, хэшированием паролей и токенов авторизации (bcrypt/JWT SHA-256), разграничением прав доступа и непрерывным аудитом безопасности.',
        ),
      ],
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            Text(body, style: AppTextStyles.body.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _FeatureInfo {
  const _FeatureInfo({
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title;
  final IconData icon;
  final String description;
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF0F172A).withOpacity(0.4) 
                : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark 
                  ? const Color(0xFF38BDF8).withOpacity(0.2) 
                  : const Color(0xFF00AAC4).withOpacity(0.15), 
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark 
                    ? const Color(0xFF38BDF8).withOpacity(0.05) 
                    : Colors.black.withOpacity(0.03),
                blurRadius: 15,
                spreadRadius: 1,
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
