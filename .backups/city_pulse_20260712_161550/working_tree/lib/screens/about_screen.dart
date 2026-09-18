import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_branding.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/dynamic_animated_background.dart';
import 'dart:ui';
import 'developer_menu_screen.dart';
import 'mesh_screen.dart';

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
          'Двухрежимная карта (день/ночь) с сигналами жителей, мероприятиями, АЗС с ценами на бензин, камерами и адресными метками. Поддержка двух городов: Нижневартовск и Новосибирск.',
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Stack(
        children: [
          const DynamicAnimatedBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: AppScreenBackground(
          accent: PulseColors.primarySoft,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      if (!widget.isOnboarding)
                        BackButton(color: scheme.primary)
                      else
                        const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'О проекте & Документы',
                          style: AppTextStyles.section,
                        ),
                      ),
                      if (!widget.isOnboarding)
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
            ? Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(0.9),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
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
                            activeColor: scheme.primary,
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
                                  color: PulseColors.textPrimary,
                                  fontSize: 12,
                                  height: 1.3,
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
                            child: FilledButton(
                              onPressed: !_consentAccepted
                                  ? null
                                  : () async {
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setBool('first_launch_accepted', true);
                                      if (!context.mounted) return;
                                      context.goNamed('map');
                                    },
                              child: const Text('Принять и продолжить'),
                            ),
                          ),
                        ],
                      ),
                    ],
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

  Widget _buildTermsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.md),
        _section(
          '1. Общие положения',
          'Настоящее Пользовательское соглашение (далее — Соглашение) регулирует отношения между '
          'правообладателем мобильного приложения «${AppBranding.appName}» (далее — Правообладатель) '
          'и лицом, использующим приложение (далее — Пользователь). '
          'Установка и/или начало использования приложения означает полное и безоговорочное '
          'присоединение Пользователя к настоящему Соглашению в соответствии со ст. 428 ГК РФ.',
        ),
        _section(
          '2. Предмет Соглашения',
          'Правообладатель предоставляет Пользователю неисключительное, безвозмездное, '
          'отзывное право использования приложения на территории всех стран мира '
          'способами, предусмотренными настоящим Соглашением.\n\n'
          'Приложение предназначено для: информирования жителей о городских событиях '
          'и происшествиях; подачи обращений с возможностью прикрепления фото и GPS-координат; '
          'просмотра видеопотоков публичных камер городского наблюдения; '
          'получения метеорологической информации и сведений о качестве воздуха; '
          'ознакомления с деятельностью управляющих компаний.',
        ),
        _section(
          '3. Обращения пользователей и модерация',
          'Все обращения (сигналы), подаваемые через приложение, публикуются анонимно. '
          'Запрещается размещение материалов, содержащих:\n'
          '• нецензурную лексику и оскорбления;\n'
          '• призывы к насилию, экстремизму или разжиганию розни;\n'
          '• персональные данные третьих лиц без их согласия;\n'
          '• заведомо ложные сведения.\n\n'
          'Нарушение указанных правил влечёт блокировку устройства Пользователя '
          'без предварительного предупреждения. '
          'Все обращения и прикреплённые файлы автоматически удаляются с сервера через 30 '
          '(тридцать) календарных дней с момента публикации.',
        ),
        _section(
          '4. Видеопотоки камер наблюдения',
          'Доступ к видеопотокам городских камер предоставляется исключительно '
          'в информационных целях для оценки дорожной обстановки и общей ситуации в городе. '
          'Запись, распространение и коммерческое использование видеопотоков запрещены.',
        ),
        _section(
          '5. Контент из открытых источников',
          'События из Telegram-каналов и VK-пабликов агрегируются автоматически '
          'с применением алгоритмов ИИ-модерации. Правообладатель не гарантирует '
          'точность, полноту и актуальность такого контента. '
          'Адреса, время и детали мероприятий рекомендуется уточнять у организаторов.',
        ),
        _section(
          '6. Ограничение ответственности',
          'Приложение предоставляется на условиях «как есть» (as is). '
          'Правообладатель не несёт ответственности за:\n'
          '• решения, принятые Пользователем исключительно на основании данных приложения;\n'
          '• перебои в работе, вызванные действиями третьих лиц или обстоятельствами непреодолимой силы;\n'
          '• содержание материалов, размещённых Пользователями;\n'
          '• любые убытки (прямые и косвенные), возникшие в результате использования или невозможности использования приложения.\n\n'
          'При чрезвычайных ситуациях необходимо руководствоваться '
          'официальными источниками МЧС России и органов местного самоуправления.',
        ),
        _section(
          '7. Интеллектуальная собственность',
          'Исключительные права на дизайн, программный код, наименование '
          'и товарный знак «Пульс города» / «City Pulse» принадлежат Правообладателю '
          'и охраняются законодательством РФ об интеллектуальной собственности '
          '(часть четвёртая ГК РФ).\n\n'
          'Картографические данные — © участники OpenStreetMap (ODbL).\n'
          'Метеоданные — Open-Meteo (CC BY 4.0).',
        ),
        _section(
          '8. Изменение условий',
          'Правообладатель вправе в одностороннем порядке изменять настоящее Соглашение. '
          'Актуальная редакция всегда доступна в разделе «О проекте» приложения. '
          'Продолжение использования приложения после внесения изменений означает '
          'согласие с новой редакцией Соглашения.',
        ),
        _section(
          '9. Применимое право и разрешение споров',
          'Настоящее Соглашение регулируется законодательством Российской Федерации. '
          'Все споры подлежат разрешению в соответствии с действующим законодательством РФ '
          'по месту нахождения Правообладателя.',
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildPrivacyTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        const SizedBox(height: AppSpacing.md),
        _section(
          '1. Оператор персональных данных',
          'Оператором персональных данных является Правообладатель приложения '
          '«${AppBranding.appName}» (далее — Оператор). '
          'Обработка персональных данных осуществляется в соответствии с '
          'Федеральным законом от 27.07.2006 № 152-ФЗ «О персональных данных» '
          'и иными нормативными правовыми актами Российской Федерации.',
        ),
        _section(
          '2. Состав обрабатываемых данных',
          '• Данные геолокации — исключительно с явного согласия Пользователя (разрешение ОС), для отображения позиции на карте и привязки обращений к адресу.\n'
          '• Текстовые и графические материалы обращений — предоставляются Пользователем добровольно.\n'
          '• Технические идентификаторы: версия приложения, push-токен устройства (Firebase Cloud Messaging) — для доставки уведомлений.\n'
          '• Локальные настройки (звук, вибрация, категории уведомлений) — хранятся исключительно на устройстве Пользователя и не передаются на сервер.\n\n'
          'Приложение НЕ собирает: фамилию, имя, отчество; номер телефона; '
          'адрес электронной почты; паспортные или иные документальные данные.',
        ),
        _section(
          '3. Цели обработки',
          '• Отображение обращений на карте города (при добровольной публикации Пользователем).\n'
          '• Доставка push-уведомлений о городских событиях и происшествиях.\n'
          '• Формирование обезличенной статистики для улучшения качества сервиса.\n\n'
          'Оператор не осуществляет продажу, передачу в аренду или иное коммерческое '
          'использование персональных данных Пользователей в пользу третьих лиц.',
        ),
        _section(
          '4. Хранение и удаление данных',
          'Серверная инфраструктура приложения размещена на территории Российской Федерации. '
          'Все обращения (сигналы) и прикреплённые медиафайлы автоматически и безвозвратно '
          'удаляются с сервера по истечении 30 (тридцати) календарных дней с момента публикации. '
          'Локальные черновики и кэшированные данные хранятся на устройстве Пользователя '
          'и могут быть удалены через настройки приложения или ОС.',
        ),
        _section(
          '5. Передача данных третьим лицам',
          'Для функционирования приложения используются следующие сторонние сервисы:\n'
          '• Хостинг-провайдер (Timeweb Cloud, РФ) — серверное размещение.\n'
          '• OpenStreetMap — картографические данные (публичный API, данные не передаются).\n'
          '• Open-Meteo — метеорологические данные (публичный API).\n'
          '• Firebase Cloud Messaging (Google) — доставка push-уведомлений.\n\n'
          'Трансграничная передача данных минимизирована и осуществляется '
          'исключительно для технически необходимых операций (доставка push-уведомлений).',
        ),
        _section(
          '6. Права Пользователя',
          'В соответствии с законодательством РФ Пользователь вправе:\n'
          '• запросить информацию об обработке своих персональных данных;\n'
          '• потребовать уточнения, блокирования или уничтожения данных;\n'
          '• отозвать согласие на обработку персональных данных;\n'
          '• отключить геолокацию и push-уведомления в настройках устройства.\n\n'
          'Для реализации указанных прав направьте обращение по контактам, '
          'указанным ниже.',
        ),
        _section(
          '7. Контактная информация',
          'По вопросам обработки персональных данных:\n'
          'E-mail: support@pulsgoroda.ru\n'
          'Telegram: @pulsgoroda_support',
        ),
        const SizedBox(height: 12),
        Text(
          'Дата вступления в силу: 01.07.2025. '
          'Настоящая Политика конфиденциальности разработана в соответствии '
          'с требованиями ФЗ-152 «О персональных данных».',
          style: AppTextStyles.bodyMuted.copyWith(fontSize: 11, height: 1.45),
        ),
        const SizedBox(height: AppSpacing.xxl),
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

  Widget _buildSummary() {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('О приложении', style: AppTextStyles.section),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '«Пульс города» — мобильная платформа городского мониторинга '
            'с элементами искусственного интеллекта. Приложение объединяет '
            'интерактивную карту с сигналами жителей, мониторинг 130+ камер '
            'видеонаблюдения, AI-дайджест городских событий из Telegram-каналов '
            'и VK-пабликов, систему подачи анонимных обращений с фото и GPS, '
            'каталог управляющих компаний с рейтингом, детальную метеосводку '
            'и экологический мониторинг.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Поддерживаются два города: Нижневартовск (ХМАО-Югра) и Новосибирск. '
            'Данные обновляются в реальном времени через собственный бэкенд '
            'с AI-классификацией событий и автоматической геопривязкой.',
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
        Text('Функции', style: AppTextStyles.section),
        const SizedBox(height: AppSpacing.sm),
        _FeaturesCarousel(features: _features),
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
            Text('ПУЛЬС ГОРОДА', style: AppTextStyles.cardTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Версия 2.3 · карта · погода · дайджест · mesh',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.info});

  final _FeatureInfo info;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
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
            child: Icon(info.icon, color: PulseColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.title, style: AppTextStyles.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(info.description, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesCarousel extends StatefulWidget {
  final List<_FeatureInfo> features;
  const _FeaturesCarousel({required this.features});

  @override
  State<_FeaturesCarousel> createState() => _FeaturesCarouselState();
}

class _FeaturesCarouselState extends State<_FeaturesCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.features.length,
            itemBuilder: (context, index) {
              final feature = widget.features[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _FeatureCard(info: feature),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.features.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _currentPage == index
                    ? PulseColors.primary
                    : scheme.onSurface.withOpacity(0.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
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
