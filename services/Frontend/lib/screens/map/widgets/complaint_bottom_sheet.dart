import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../map/map_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import '../../../theme/pulse_colors.dart';
import '../../../../services/sound_service.dart';
import 'map_glass_panel.dart';
import '../../../../theme/theme_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../../services/analytics_service.dart';
import '../../../utils/situation_helper.dart';
import '../../../../widgets/aura_living_background.dart';
import '../../../../core/living/aura_living_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/uk_fallback_data.dart';
import '../../../../services/gost_claim_generator_service.dart';
import '../../../../services/passkey_service.dart';

/// Shows the complaint details bottom sheet.
/// Returns the updated complaint map (for likes sync).

void _generateOfficialComplaint(BuildContext context, Map<String, dynamic> complaint, Color accentColor) async {
  final title = complaint['title'] ?? 'Жалоба';
  final category = complaint['category']?.toString() ?? 'Прочее';
  final desc = _extractDescription(complaint['description'] as String? ?? '');
  final address = complaint['address'] ?? 'Нижневартовск';
  final lat = complaint['latitude'] ?? complaint['lat'] ?? 0.0;
  final lng = complaint['longitude'] ?? complaint['lng'] ?? 0.0;
  final id = complaint['id'] ?? 0;
  final date = DateTime.now();
  final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  
  // Call backend legal claim if user is VIP, otherwise fall back to local FZ-59 template
  String appealText = '';
  bool isLlmClaim = false;
  
  try {
    final prefs = await SharedPreferences.getInstance();
    final isVip = prefs.getBool('is_premium_vip') ?? prefs.getBool('is_vip') ?? false;
    if (isVip) {
      final token = prefs.getString('auth_token') ?? '';
      // Fetch online LLM claim from FastAPI
      final res = await ApiClient().post('/api/reports/$id/generate-legal-claim', data: {}, token: token);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        appealText = decoded['claim_markdown'] ?? '';
        isLlmClaim = true;
      }
    }
  } catch (_) {}

  if (appealText.isEmpty) {
    // Rephrase user input to official style
    String formalViolationText;
    final lowerCat = category.toLowerCase();
    if (lowerCat.contains('дорог') || lowerCat.contains('яма') || lowerCat.contains('асфальт') || lowerCat.contains('тротуар')) {
      formalViolationText = 'на проезжей части / тротуаре по указанному адресу зафиксированы дефекты покрытия (выбоины, проседания, трещины), превышающие предельно допустимые нормы, что является прямым нарушением п. 5.2.4 ГОСТ Р 50597-2017 и ст. 12 Федерального закона № 196-ФЗ "О безопасности дорожного движения".';
    } else if (lowerCat.contains('свет') || lowerCat.contains('освещен') || lowerCat.contains('фонар')) {
      formalViolationText = 'отсутствует или работает некорректно стационарное уличное / дворовое освещение, что нарушает нормативные требования ГОСТ Р 55706-2013 и СП 52.13330.2016, снижая уровень общественной и дорожной безопасности.';
    } else if (lowerCat.contains('мусор') || lowerCat.contains('свалка') || lowerCat.contains('эколог') || lowerCat.contains('тко')) {
      formalViolationText = 'обнаружено несанкционированное накопление ТКО / КГО и захламление территории, нарушающее нормативные требования раздела II СанПиН 2.1.3684-21 и ст. 13.4 Федерального закона № 89-ФЗ "Об отходах производства и потребления".';
    } else if (lowerCat.contains('ук') || lowerCat.contains('жкх') || lowerCat.contains('дом') || lowerCat.contains('подъезд') || lowerCat.contains('крыш')) {
      formalViolationText = 'зафиксировано ненадлежащее содержание общедомового имущества управляющей организацией, что нарушает ч. 1 и ч. 2.3 ст. 161 Жилищного кодекса РФ, Постановление Правительства РФ № 354 и Постановление Правительства РФ № 290.';
    } else if (lowerCat.contains('животн') || lowerCat.contains('собак')) {
      formalViolationText = 'наблюдается безнадзорное пребывание животных без владельцев, требующее проведения отлова и учета в соответствии со ст. 18 Федерального закона от 27.12.2018 № 498-ФЗ "Об ответственном обращении с животными".';
    } else if (lowerCat.contains('детск') || lowerCat.contains('площадк') || lowerCat.contains('спорт')) {
      formalViolationText = 'выявлены повреждения и опасные элементы оборудования игровой / спортивной площадки, не соответствующие требованиям безопасности ГОСТ Р 52169-2012.';
    } else {
      formalViolationText = 'выявлены нарушения Правил благоустройства территории города Нижневартовска, требующие проведения проверки и принятия мер административного реагирования.';
    }

    final webMapUrl = "${MapConfig.backendApiBaseUrl.replaceFirst('/api', '')}/map?marker=$lat,$lng";
    final googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

    // Fetch comments
    List<String> commentStrings = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final res = await http.get(
        Uri.parse('${MapConfig.backendApiBaseUrl}/reports/$id/comments'),
        headers: {
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(utf8.decode(res.bodyBytes));
        for (final item in decoded) {
          if (item is Map && item.containsKey('content')) {
            commentStrings.add('${item['author_name'] ?? 'Житель'}: ${item['content']}');
          }
        }
      }
    } catch (_) {}

    final commentsBlock = commentStrings.isEmpty
        ? ''
        : '\n\nДополнительные свидетельства и замечания жителей по данному факту:\n' +
            commentStrings.map((c) => '• $c').join('\n');

    appealText = '''Главе Администрации города Нижневартовска
от гражданина РФ (ФИО заполняется отправителем)

ЗАЯВЛЕНИЕ
(в соответствии с Федеральным законом № 59-ФЗ "О порядке рассмотрения обращений граждан РФ")

Настоящим сообщаю о выявленном нарушении на территории города Нижневартовска.
Суть инцидента: $title
Категория нарушения: $category

В ходе общественного мониторинга установлено следующее: $formalViolationText
Справочные материалы и детали проблемы: $desc

Географические ориентиры:
- Адрес объекта: $address
- Точные географические координаты: $lat, $lng
- Позиция на карте City Pulse: $webMapUrl
- Ссылка на Google Maps: $googleMapsUrl$commentsBlock

На основании Федерального закона от 02.05.2006 № 59-ФЗ "О порядке рассмотрения обращений граждан Российской Федерации" прошу:
1. Зарегистрировать данное обращение в течение 3 дней со дня поступления.
2. Провести проверку по изложенным фактам и принять меры по устранению нарушения.
3. Направить официальный ответ о принятых мерах на мой адрес в установленный законом 30-дневный срок.

Дата: $dateStr
Подпись: _______________''';
  }

  showDialog(
    context: context,
    builder: (ctx) {
      final controller = TextEditingController(text: appealText);
      return AlertDialog(
        backgroundColor: const Color(0xFF131A26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: accentColor.withOpacity(0.4), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.gavel_rounded, color: accentColor),
            const SizedBox(width: 8),
            Text(
              isLlmClaim ? 'Претензия ИИ (Юрист)' : 'Официальное Обращение ФЗ-59',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 380),
          child: TextField(
            controller: controller,
            maxLines: null,
            minLines: 12,
            keyboardType: TextInputType.multiline,
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontFamily: 'monospace', height: 1.35),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor),
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: controller.text));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Текст обращения скопирован в буфер обмена')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text('Копировать', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: accentColor),
          ),
          TextButton.icon(
            onPressed: () {
              Share.share(controller.text);
            },
            icon: const Icon(Icons.share_rounded, size: 14),
            label: const Text('Поделиться', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: accentColor),
          ),
          TextButton.icon(
            onPressed: () async {
              try {
                final textToPrint = controller.text;
                final escapedText = htmlEscape.convert(textToPrint).replaceAll('\n', '<br>');
                await Printing.layoutPdf(
                  onLayout: (PdfPageFormat format) async => await Printing.convertHtml(
                    format: format,
                    html: '<html><body style="font-family: sans-serif; font-size: 13px; line-height: 1.5; padding: 25px; white-space: pre-wrap;">$escapedText</body></html>',
                  ),
                  name: 'Обращение_ФЗ_59_${complaint['id'] ?? 'pulse_nv'}.pdf',
                );
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Ошибка создания PDF: $e')),
                );
              }
            },
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
            label: const Text('В PDF', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: accentColor),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Закрыть', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ],
      );
    },
  );
}

Future<void> showComplaintBottomSheet({
  required BuildContext context,
  required Map<String, dynamic> complaint,
  int signalIndex = 0,
  int signalTotal = 0,
  void Function()? onPrevSignal,
  void Function()? onNextSignal,
  required Color categoryColor,
  required Color statusColor,
  required String statusText,
  required String categoryLabel,
  required IconData categoryIcon,
  required String formattedDate,
  required VoidCallback onZoomBack,
  required VoidCallback onScheduleReminder,
  required bool isEvent,
  required void Function(Map<String, dynamic> updated)? onComplaintUpdated,
}) async {
  final category = (complaint['category'] ?? 'Прочее') as String;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    enableDrag: true,
    isScrollControlled: true,
    builder: (ctx) {
      bool isSpeaking = false;
      final rawDate = complaint['created_at'] ?? complaint['createdAt'] ?? complaint['timestamp'];
      DateTime? dt;
      if (rawDate is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(rawDate);
      } else if (rawDate is String) {
        dt = DateTime.tryParse(rawDate);
      }
      final now = DateTime.now();
      final isToday = dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day;
      return StatefulBuilder(
        builder: (BuildContext contextInner, StateSetter setModalState) {
          final lat = complaint['lat'] ?? complaint['latitude'];
          final lng = complaint['lng'] ?? complaint['longitude'];
          final hasCoords = lat != null && lng != null;

          final isLightTheme = Theme.of(contextInner).brightness == Brightness.light;
          final primaryTextColor = isLightTheme ? PulseColors.lightTextPrimary : PulseColors.textPrimary;
          final secondaryTextColor = isLightTheme ? PulseColors.lightTextSecondary : PulseColors.textSecondary;
          final tertiaryTextColor = isLightTheme ? const Color(0xFF475569) : PulseColors.textTertiary;
          final boxBgColor = isLightTheme ? PulseColors.lightSurface : PulseColors.surfaceSoft;
          final boxBorderColor = isLightTheme ? Colors.white : PulseColors.border;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.65,
            ),
            child: MapGlassPanel(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              padding: EdgeInsets.zero,
              fillColor: isEvent
                  ? Colors.transparent
                  : (isLightTheme
                      ? Colors.white.withAlpha(246)
                      : const Color(0xFF0F172A).withAlpha(242)),
              blurSigma: isEvent ? 0 : 28,
              borderColors: isLightTheme
                  ? const [
                      Color(0xFF00B8D4),
                      Colors.white,
                      Colors.white,
                    ]
                  : const [
                      Color(0xFF00E5FF),
                      Color(0xFF0F172A),
                      Color(0xFF0F172A),
                    ],
              child: Stack(
                children: [
                  // Верхняя кромка в стиле бюро находок
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00E5FF).withOpacity(0.0),
                            const Color(0xFF00E5FF),
                            const Color(0xFF00E5FF).withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                                    // Живой фон под шторкой: у событий — насыщенный, у обычных
                  // сигналов — деликатная вуаль (в светлой теме почти белая).
Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        child: AuraLivingBackground(
                          scene: AuraLivingEngine.resolve(
                            mood: 0,
                            streak: 5,
                            meditationMinutes: 10,
                            practicesCompleted: 5,
                            isPremium: true,
                            hour: DateTime.now().hour,
                          ).copyWith(
                            weather: AuraWeather.water,
                          ),
                          interactive: true,
                          showConstellationVeil: false,
                          child: Container(
                            color: isEvent
                                ? (isLightTheme
                                    ? Colors.white.withOpacity(0.60)
                                    : Colors.black.withOpacity(0.40))
                                : (isLightTheme
                                    ? Colors.white.withOpacity(0.86)
                                    : Colors.black.withOpacity(0.24)),
                          ),
                        ),
                      ),
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ручка
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isLightTheme ? Colors.black26 : Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Перелистывание сигналов скроллом/кнопками
                      if (signalTotal > 1)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _SignalNavButton(
                                icon: Icons.chevron_left_rounded,
                                onTap: onPrevSignal,
                                enabled: onPrevSignal != null,
                              ),
                              Text(
                                '${signalIndex + 1} / $signalTotal',
                                style: TextStyle(
                                  color: tertiaryTextColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              _SignalNavButton(
                                icon: Icons.chevron_right_rounded,
                                onTap: onNextSignal,
                                enabled: onNextSignal != null,
                              ),
                            ],
                          ),
                        ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          // 1. ЗАГОЛОВОК + КАТЕГОРИЯ + ТЕАТРАЛЬНАЯ ОЗВУЧКА
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      categoryColor.withOpacity(0.45),
                                      categoryColor.withOpacity(0.15),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: categoryColor.withOpacity(0.6), width: 1.4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: categoryColor.withOpacity(0.25),
                                      blurRadius: 14,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                                child: Hero(
                                  tag: 'complaint_icon_${complaint['id'] ?? complaint.hashCode}',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Icon(
                                      categoryIcon,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: categoryColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: categoryColor.withOpacity(0.5)),
                                          ),
                                          child: Text(
                                            categoryLabel.toUpperCase(),
                                            style: TextStyle(
                                              color: categoryColor,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isLightTheme ? Colors.black.withOpacity(0.06) : Colors.white10,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            formattedDate,
                                            style: TextStyle(color: tertiaryTextColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      complaint['title'] as String? ?? 'Городской сигнал',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Кнопка театральной озвучки
                              GestureDetector(
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  if (SoundService().isSpeakingTts) {
                                    await SoundService().stopSpeak();
                                  } else {
                                    final descText = _extractDescription(complaint['description'] as String? ?? '');
                                    final textToSpeak = [
                                      complaint['title']?.toString(),
                                      descText.isNotEmpty ? descText : null,
                                    ].whereType<String>().join('. ');
                                    await SoundService().speak(textToSpeak, isEvent: true);
                                  }
                                  setModalState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: SoundService().isSpeakingTts
                                        ? const Color(0xFFEC4899).withOpacity(0.3)
                                        : Colors.white.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: SoundService().isSpeakingTts
                                          ? const Color(0xFFEC4899)
                                          : Colors.white24,
                                    ),
                                  ),
                                  child: Icon(
                                    SoundService().isSpeakingTts
                                        ? Icons.stop_rounded
                                        : Icons.theater_comedy_rounded,
                                    color: SoundService().isSpeakingTts
                                        ? const Color(0xFFEC4899)
                                        : const Color(0xFF00E5FF),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 2. ФОТОГРАФИЯ СИГНАЛА С KIMI K3 / FLUX ОБОГАЩЕНИЕМ
                          if (category != 'Камеры')
                            (() {
                              final realPhotos = SituationHelper.extractImageUrls(complaint);
                              final hasRealPhoto = realPhotos.isNotEmpty;
                              var displayPhotoUrl = hasRealPhoto ? realPhotos.first : '';
                              if (!hasRealPhoto) {
                                // Default high quality Kimi K3 / FLUX preview
                                final cleanTitle = Uri.encodeComponent(complaint['title'] ?? category);
                                displayPhotoUrl = 'https://image.pollinations.ai/prompt/3D%20hyperrealistic%20photo%20Nizhnevartovsk%20city%20urban%20issue%20$cleanTitle?width=800&height=500&nologo=true&model=flux';
                              }

                              final openFullscreen = () {
                                HapticFeedback.mediumImpact();
                                Navigator.of(contextInner, rootNavigator: true).push(
                                  PageRouteBuilder(
                                    opaque: false,
                                    barrierColor: Colors.black.withOpacity(0.95),
                                    pageBuilder: (ctx, anim, _) => Scaffold(
                                      backgroundColor: Colors.black.withOpacity(0.96),
                                      body: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          InteractiveViewer(
                                            minScale: 0.5,
                                            maxScale: 4.5,
                                            child: Center(
                                              child: Image.network(
                                                displayPhotoUrl,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) {
                                                   final cTitle = complaint['title'] ?? complaint['description'] ?? category;
                                                   final prompt = 'photorealistic detailed photo of $cTitle, $category in Nizhnevartovsk city, 8k, sharp details';
                                                   final fallbackAiUrl = 'https://image.pollinations.ai/prompt/${Uri.encodeComponent(prompt)}?width=1280&height=720&model=flux&nologo=true';
                                                   return Image.network(fallbackAiUrl, fit: BoxFit.contain);
                                                 },
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: MediaQuery.of(ctx).padding.top + 12,
                                            right: 16,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.6),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white24),
                                              ),
                                              child: IconButton(
                                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                                                onPressed: () => Navigator.pop(ctx),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: MediaQuery.of(ctx).padding.bottom + 16,
                                            left: 20,
                                            right: 20,
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.7),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: Colors.white24),
                                                ),
                                                child: Text(
                                                  hasRealPhoto ? '📷 Фото жителя (масштабируйте двумя пальцами)' : '✨ ИИ-иллюстрация — не фото события (зум доступен)',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              };

                              return GestureDetector(
                                onTap: openFullscreen,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 18),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      )
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Stack(
                                      children: [
                                        SizedBox(
                                          height: 175,
                                          width: double.infinity,
                                          child: Image.network(
                                            displayPhotoUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Image.asset(
                                              _getMemePath(category),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        // Градиент затемнения снизу
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.65),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Бейдж источника фото (Kimi K3 / Фото жителя)
                                        Positioned(
                                          top: 10,
                                          left: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.7),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: hasRealPhoto ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  hasRealPhoto ? Icons.camera_alt_rounded : Icons.auto_awesome_rounded,
                                                  color: hasRealPhoto ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                                                  size: 13,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  hasRealPhoto ? 'ФОТО ЖИТЕЛЯ' : 'ИИ-ИЛЛЮСТРАЦИЯ · НЕ ФОТО',
                                                  style: TextStyle(
                                                    color: hasRealPhoto ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Кнопка полноэкранного зума
                                        Positioned(
                                          right: 10,
                                          bottom: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.7),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.white30),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
                                                SizedBox(width: 4),
                                                Text('НА ВЕСЬ ЭКРАН 🔍', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            })(),

                          if (category == 'Камеры') ...[
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(Icons.videocam_off_rounded,
                                      color: Colors.white24, size: 48),
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('LIVE',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const Center(
                                    child: Text(
                                      'ЗАГРУЗКА ПОТОКА...',
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                          letterSpacing: 2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 3. СТАТУС-ГРИД С ИКОНКАМИ И ВЕРИФИКАЦИЕЙ
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isLightTheme ? Colors.black.withOpacity(0.04) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: statusColor.withOpacity(0.6)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(color: statusColor.withOpacity(0.8), blurRadius: 6, spreadRadius: 1),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            statusText.toUpperCase(),
                                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Честный бейдж источника сигнала
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E5FF).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.source_rounded, color: Color(0xFF00E5FF), size: 13),
                                          const SizedBox(width: 4),
                                          Text(
                                            _sourceLabel(complaint['source'] as String?),
                                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (complaint['address'] != null) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on_rounded, color: Color(0xFF00E5FF), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          complaint['address'] as String,
                                          style: TextStyle(color: primaryTextColor, fontSize: 12.5, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                (() {
                                  final addrStr = (complaint['address'] as String?) ?? '';
                                  String? resolvedUk = (complaint['uk_name'] ?? complaint['uk']) as String?;
                                  if (resolvedUk == null || resolvedUk.trim().isEmpty) {
                                    if (addrStr.isNotEmpty) {
                                      final ukModel = UkFallbackData.getUkForAddress(addrStr);
                                      if (ukModel != null) {
                                        resolvedUk = ukModel['name']?.toString() ?? ukModel['full_name']?.toString();
                                      }
                                    }
                                  }
                                  if (resolvedUk != null && resolvedUk.isNotEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.45)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.apartment_rounded, color: Color(0xFFA78BFA), size: 16),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'УПРАВЛЯЮЩАЯ КОМПАНИЯ (ОПРЕДЕЛЕНО)',
                                                    style: TextStyle(color: Color(0xFFA78BFA), fontSize: 9, fontWeight: FontWeight.w900),
                                                  ),
                                                  Text(
                                                    resolvedUk,
                                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                })(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 4. ОПИСАНИЕ СИГНАЛА (стиль бюро находок)
                          if (complaint['description'] != null) ...[
                            const Text(
                              'ПОДРОБНОЕ ОПИСАНИЕ:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white54,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withOpacity(0.06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 6, right: 10),
                                    width: 3,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E5FF),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _extractDescription(complaint['description'] as String? ?? ''),
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 13.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // «Память места»: что здесь происходило раньше
                          // (текущие сигналы + архив, включая повторяющиеся темы)
                          _PlaceMemoryBlock(
                            complaint: complaint,
                            isLightTheme: isLightTheme,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            accent: categoryColor,
                          ),
                          const SizedBox(height: 12),

                          // Краткий анализ ИИ (спойлер с RAG-юристом ХМАО)
                          Builder(builder: (ctx) {
                            final rawDesc = complaint['description'] as String? ?? '';
                            final cleanText = _extractDescription(rawDesc);
                            var analysisText = _extractAnalysis(rawDesc);
                            if (analysisText.isEmpty) {
                              final analysis = SituationHelper.analyzeSituation(category, cleanText);
                              analysisText = '• Важность: ' + (analysis['severity'] ?? 'Обычная') + '\n'
                                  '• Масштаб: ' + (analysis['scope'] ?? 'Локальный') + '\n'
                                  '• Влияние: ' + (analysis['impact'] ?? 'Информационный') + '\n\n'
                                  '⚖️ ЮРИДИЧЕСКОЕ ОБОСНОВАНИЕ (RAG ХМАО):\n' + (analysis['legal'] ?? '');
                            }
                            return _ExpandableAnalysisWidget(
                              analysisText: analysisText,
                              categoryColor: categoryColor,
                              isLightTheme: isLightTheme,
                            );
                          }),
                          const SizedBox(height: 12),

                          // Адрес
                          if (complaint['address'] != null) ...[
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, color: categoryColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    complaint['address'] as String,
                                    style: TextStyle(color: primaryTextColor, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Координаты, Статус, УК
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasCoords) ...[
                                Row(
                                  children: [
                                    Icon(Icons.gps_fixed_rounded, color: tertiaryTextColor, size: 14),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Координаты: ${(lat as num).toStringAsFixed(6)}, ${(lng as num).toStringAsFixed(6)}',
                                      style: TextStyle(color: secondaryTextColor, fontSize: 12, fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              const SizedBox.shrink(),
                              if (complaint['uk_name'] != null || complaint['uk'] != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.business_rounded, color: tertiaryTextColor, size: 14),
                                    const SizedBox(width: 8),
                                    Text(
                                      'УК: ${complaint['uk_name'] ?? complaint['uk']}',
                                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Опции (Поделиться, Street View и Обращение по ФЗ-59)
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: categoryColor.withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: categoryColor.withAlpha(60)),
                                  ),
                                  child: TextButton.icon(
                                    icon: Icon(Icons.share_rounded, size: 14, color: categoryColor),
                                    label: Text('Поделиться', style: TextStyle(color: categoryColor, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    onPressed: () => _shareComplaint(context, complaint),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: categoryColor.withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: categoryColor.withAlpha(60)),
                                  ),
                                  child: TextButton.icon(
                                    icon: Icon(Icons.description_rounded, size: 14, color: categoryColor),
                                    label: Text('Обращение', style: TextStyle(color: categoryColor, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    onPressed: () => _generateOfficialComplaint(context, complaint, categoryColor),
                                  ),
                                ),
                              ),
                              if (hasCoords && complaint['address'] != null && (complaint['address'] as String).isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: categoryColor.withAlpha(20),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: categoryColor.withAlpha(60)),
                                    ),
                                    child: TextButton.icon(
                                      icon: Icon(Icons.streetview_rounded, size: 14, color: categoryColor),
                                      label: Text('Street View', style: TextStyle(color: categoryColor, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                      onPressed: () async {
                                        final url = 'google.streetview:cbll=$lat,$lng';
                                        final fallbackUrl = 'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng';
                                        try {
                                          if (await canLaunchUrl(Uri.parse(url))) {
                                            await launchUrl(Uri.parse(url));
                                          } else {
                                            await launchUrl(Uri.parse(fallbackUrl));
                                          }
                                        } catch (_) {
                                          await launchUrl(Uri.parse(fallbackUrl));
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      )
         .animate()
         .slideY(begin: 0.12, end: 0.0, duration: 380.ms, curve: Curves.easeOutCubic)
         .fadeIn(duration: 320.ms);
      },
      );
    },
  ).whenComplete(() {
    // When bottom sheet is dismissed by swipe, also zoom back
    onZoomBack();
  });
}

void _openGosuslugiPortal(BuildContext ctx, Map<String, dynamic> complaint) {
  final id = complaint['id'] ?? '';
  final category = complaint['category'] ?? '';

  String portalUrl = 'https://dom.gosuslugi.ru/';
  if (category == 'Дороги' || category == 'Благоустройство' || category == 'Экология') {
    portalUrl = 'https://pos.gosuslugi.ru/';
  }

  final dialogIsLight = Theme.of(ctx).brightness == Brightness.light;
  showDialog(
    context: ctx,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: dialogIsLight ? Colors.white : const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.gavel_rounded, color: PulseColors.accentGold),
          SizedBox(width: 8),
          Text(
            'Официальная подача',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'ИИ City Pulse подготовил официальное юридическое заявление на основе вашего обращения.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 12),
          Text(
            '1. Сначала скачайте PDF-документ на устройство.\n2. Нажмите "В Госуслуги" и войдите в свой личный кабинет.\n3. Прикрепите скачанный файл к новому обращению.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Отмена', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: PulseColors.primary,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Скачать PDF'),
          onPressed: () async {
            final pdfUrl = '${MapConfig.backendApiBaseUrl}/reports/$id/legal-document';
            await launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);
          },
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: PulseColors.accentGold,
            foregroundColor: Colors.black,
          ),
          icon: const Icon(Icons.launch_rounded, size: 16),
          label: const Text('В Госуслуги'),
          onPressed: () async {
            Navigator.pop(dialogCtx);
            await launchUrl(Uri.parse(portalUrl), mode: LaunchMode.externalApplication);
          },
        ),
      ],
    ),
  );
}

void _shareComplaint(BuildContext ctx, Map<String, dynamic> complaint) {
  final title = complaint['title'] ?? 'Проблема';
  final desc = complaint['description'] ?? '';
  final text = '❗️ $title\n\n$desc\n\nПриложение City Pulse Нижневартовск';
  AnalyticsService.trackEvent('share_success');

  final shareIsLight = Theme.of(ctx).brightness == Brightness.light;
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: BoxDecoration(
        color: shareIsLight
            ? Colors.white.withOpacity(0.97)
            : const Color(0xFF0F172A).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: PulseColors.accentGold.withOpacity(0.3), width: 1.5),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Поделиться сигналом',
            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _shareOption(
                icon: Icons.telegram_rounded,
                label: 'Telegram',
                color: const Color(0xFF229ED9),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final nativeUrl = 'tg://msg?text=${Uri.encodeComponent(text)}';
                  if (await canLaunchUrl(Uri.parse(nativeUrl))) {
                    await launchUrl(Uri.parse(nativeUrl), mode: LaunchMode.externalApplication);
                  } else {
                    final webUrl = 'https://t.me/share/url?text=${Uri.encodeComponent(text)}';
                    if (await canLaunchUrl(Uri.parse(webUrl))) {
                      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
                    } else {
                      await Share.share(text);
                    }
                  }
                },
              ),
              _shareOption(
                icon: Icons.alternate_email_rounded,
                label: 'ВКонтакте',
                color: const Color(0xFF4C75A3),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final nativeUrl = 'vk://share?text=${Uri.encodeComponent(text)}';
                  if (await canLaunchUrl(Uri.parse(nativeUrl))) {
                    await launchUrl(Uri.parse(nativeUrl), mode: LaunchMode.externalApplication);
                  } else {
                    final webUrl = 'https://vk.com/share.php?title=${Uri.encodeComponent(text)}';
                    if (await canLaunchUrl(Uri.parse(webUrl))) {
                      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
                    } else {
                      await Share.share(text);
                    }
                  }
                },
              ),
              _shareOption(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final nativeUrl = 'whatsapp://send?text=${Uri.encodeComponent(text)}';
                  if (await canLaunchUrl(Uri.parse(nativeUrl))) {
                    await launchUrl(Uri.parse(nativeUrl), mode: LaunchMode.externalApplication);
                  } else {
                    final webUrl = 'https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}';
                    if (await canLaunchUrl(Uri.parse(webUrl))) {
                      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
                    } else {
                      await Share.share(text);
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _shareOption({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}

class _MemeWidget extends StatefulWidget {
  final String reportId;
  const _MemeWidget({required this.reportId});

  @override
  State<_MemeWidget> createState() => _MemeWidgetState();
}

class _MemeWidgetState extends State<_MemeWidget> {
  bool _loading = false;
  Map<String, dynamic>? _meme;

  Future<void> _generateMeme() async {
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('${MapConfig.backendApiBaseUrl}/gamification/memes/generate?telegram_id=9999&report_id=${widget.reportId}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        setState(() {
          _meme = jsonDecode(utf8.decode(res.bodyBytes));
        });
      }
    } catch (e) {
      debugPrint('Error generating meme for report: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_meme != null) {
      final text = _meme!['share_text'] ?? _meme!['caption'] ?? '';
      final imageUrl = _meme!['image_url'] ?? '';
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PulseColors.accentGold.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PulseColors.accentGold.withAlpha(40), width: 1.5),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 48),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PulseColors.accentGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.share_rounded, size: 14),
                label: const Text('Поделиться мемом'),
                onPressed: () async {
                  final url = 'https://t.me/share/url?url=${Uri.encodeComponent(imageUrl)}&text=${Uri.encodeComponent(text)}';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: PulseColors.accentGold.withAlpha(20),
          foregroundColor: PulseColors.accentGold,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: PulseColors.accentGold, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        icon: _loading 
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: PulseColors.accentGold))
            : const Icon(Icons.palette_rounded, size: 16),
        label: Text(_loading ? 'ИИ думает...' : '🎨 Создать ИИ-мем по инциденту'),
        onPressed: _loading ? null : _generateMeme,
      ),
    );
  }
}

class _ImageWithMemeFallback extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String description;
  final Color categoryColor;

  const _ImageWithMemeFallback({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.categoryColor,
  });

  @override
  State<_ImageWithMemeFallback> createState() => _ImageWithMemeFallbackState();
}

class _ImageWithMemeFallbackState extends State<_ImageWithMemeFallback> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return ReportMemeWidget(
        title: widget.title,
        description: widget.description,
        categoryColor: widget.categoryColor,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        widget.imageUrl,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(widget.categoryColor),
              ),
            ),
          );
        },
        errorBuilder: (context, err, stack) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hasError = true);
          });
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

/// A custom widget that calls /api/reports/meme to fetch a generated municipal demotivator
/// and draws it on screen when an image fails to load.
class ReportMemeWidget extends StatelessWidget {
  final String title;
  final String description;
  final Color categoryColor;

  const ReportMemeWidget({
    super.key,
    required this.title,
    required this.description,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withOpacity(0.12),
            isLight ? Colors.white : const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: categoryColor.withOpacity(0.25), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: categoryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  description.isNotEmpty ? description : 'Детали инцидента обрабатываются муниципальными службами.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 11,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SupportButtonWidget extends StatefulWidget {
  final Map<String, dynamic> complaint;

  const SupportButtonWidget({super.key, required this.complaint});

  @override
  State<SupportButtonWidget> createState() => _SupportButtonWidgetState();
}

class _SupportButtonWidgetState extends State<SupportButtonWidget> {
  bool _isLoading = false;
  bool _isSupported = false;
  late int _supportersCount;

  @override
  void initState() {
    super.initState();
    _supportersCount = widget.complaint['supporters'] as int? ?? 0;
  }

  Future<void> _supportReport() async {
    if (_isSupported || _isLoading) return;
    final id = widget.complaint['id'];
    if (id == null) return;

    setState(() { _isLoading = true; });
    try {
      final token = await AuthService().getToken();
      if (token == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Для поддержки требуется авторизация')));
        setState(() { _isLoading = false; });
        return;
      }
      final res = await ApiClient().post('/api/reports/$id/actions', data: {'action': 'join'}, token: token);
      final newCount = _supportersCount + 1;
      setState(() {
        _isSupported = true;
        _supportersCount = newCount;
      });

      if (newCount >= 10 && mounted) {
        // Auto-generate collective class-action petition PDF
        try {
          final pdfPath = await GostClaimGeneratorService().generatePetitionPdf(
            title: widget.complaint['title'] ?? 'Коллективное обращение граждан',
            address: widget.complaint['address'] ?? 'г. Нижневартовск',
            category: widget.complaint['category'] ?? 'ЖКХ',
            description: widget.complaint['description'] ?? '',
            supportersCount: newCount,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              backgroundColor: const Color(0xFF10B981),
              content: Text('🎉 Достигнуто 10 голосов! Сформировано коллективное обращение (PDF): ${pdfPath.split('/').last}'),
            ),
          );
        } catch (pdfErr) {
          debugPrint('Collective PDF generation error: $pdfErr');
        }
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString().contains('400') ? 'Вы уже поддержали это решение' : 'Ошибка при голосовании';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText)));
        if (errText.contains('уже')) {
           setState(() { _isSupported = true; });
        }
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: _supportReport,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: _isSupported 
            ? PulseColors.primary.withAlpha(isDark ? 30 : 20)
            : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isSupported 
              ? PulseColors.primary.withAlpha(isDark ? 80 : 50)
              : (isDark ? Colors.white12 : Colors.black12),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              Icon(
                _isSupported ? Icons.thumb_up_alt_rounded : Icons.thumb_up_off_alt_rounded,
                color: _isSupported ? PulseColors.primary : (isDark ? Colors.white54 : Colors.black54),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                _isSupported ? 'Поддержано ($_supportersCount)' : 'Поддержать решение ($_supportersCount)',
                style: TextStyle(
                  color: _isSupported ? PulseColors.primary : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ]
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, duration: 400.ms);
  }
}

class AuthService {
  /// Возвращает токен пользователя из passkey-хранилища, если авторизован.
  Future<String?> getToken() async => PasskeyService().getStoredToken();
}

class ApiClient {
  Future<http.Response> post(String path, {required Map<String, dynamic> data, required String token}) async {
    return BackendApiService.instance.postJson(path, data, headers: {'Authorization': 'Bearer $token'});
  }
}




String _getMemePath(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('дорог') || lower.contains('яма') || lower.contains('асфальт')) {
    return 'assets/3d_icons/dorogi_3d.webp';
  } else if (lower.contains('жкх') || lower.contains('ук') || lower.contains('вод') || lower.contains('отоплен') || lower.contains('дом')) {
    return 'assets/3d_icons/construction_3d.webp';
  } else if (lower.contains('свет') || lower.contains('освещен') || lower.contains('фонар')) {
    return 'assets/3d_icons/lighting_3d.webp';
  } else if (lower.contains('эколог') || lower.contains('мусор') || lower.contains('свалк')) {
    return 'assets/3d_icons/ecology_3d.webp';
  } else if (lower.contains('животн') || lower.contains('собак') || lower.contains('кот') || lower.contains('питом')) {
    return 'assets/3d_icons/animals_3d.webp';
  } else if (lower.contains('снег') || lower.contains('лед') || lower.contains('наледь')) {
    return 'assets/3d_icons/snow_3d.webp';
  } else if (lower.contains('чп') || lower.contains('авари') || lower.contains('пожар')) {
    return 'assets/3d_icons/chp_3d.webp';
  } else {
    return 'assets/3d_icons/transport_3d.webp';
  }
}

String _extractDescription(String fullDesc) {
  final lower = fullDesc.toLowerCase();
  final markers = [
    'краткий анализ ситуации',
    'краткий анализ',
    'анализ ситуации:',
    'анализ (ии):'
  ];
  for (final marker in markers) {
    final idx = lower.indexOf(marker);
    if (idx != -1) {
      return fullDesc.substring(0, idx).trim();
    }
  }
  return fullDesc.trim();
}

String _extractAnalysis(String fullDesc) {
  final lower = fullDesc.toLowerCase();
  final markers = [
    'краткий анализ ситуации',
    'краткий анализ',
    'анализ ситуации:',
    'анализ (ии):'
  ];
  for (final marker in markers) {
    final idx = lower.indexOf(marker);
    if (idx != -1) {
      var analysisText = fullDesc.substring(idx + marker.length).trim();
      if (analysisText.startsWith(':')) {
        analysisText = analysisText.substring(1).trim();
      }
      return analysisText;
    }
  }
  return '';
}

class _ExpandableAnalysisWidget extends StatefulWidget {
  final String analysisText;
  final Color categoryColor;
  final bool isLightTheme;

  const _ExpandableAnalysisWidget({
    required this.analysisText,
    required this.categoryColor,
    required this.isLightTheme,
  });

  @override
  State<_ExpandableAnalysisWidget> createState() => _ExpandableAnalysisWidgetState();
}

class _ExpandableAnalysisWidgetState extends State<_ExpandableAnalysisWidget> {
  bool _isExpanded = false;
  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _checkVipStatus();
  }

  Future<void> _checkVipStatus() async {
    if (mounted) {
      setState(() {
        _isVip = true;
      });
    }
  }

  void _showVipPromo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F1F1F), Color(0xFF121212)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 54),
                const SizedBox(height: 16),
                const Text(
                  'Premium VIP Доступ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Разблокируйте доступ к детальному юридическому анализу ситуаций на базе искусственного интеллекта, прогнозированию рисков и прямой связи с правозащитниками Нижневартовска.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('is_premium_vip', true);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      _checkVipStatus();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Активировать (Демо)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: widget.categoryColor.withAlpha(widget.isLightTheme ? 12 : 22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.categoryColor.withAlpha(widget.isLightTheme ? 30 : 60),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (!_isVip) {
            _showVipPromo(context);
            return;
          }
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_rounded, color: widget.categoryColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'КРАТКИЙ АНАЛИЗ ИИ',
                        style: TextStyle(
                          color: widget.categoryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _isVip
                        ? (_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded)
                        : Icons.lock_outline_rounded,
                    color: widget.categoryColor,
                    size: 20,
                  ),
                ],
              ),
              if (!_isVip) ...[
                const SizedBox(height: 8),
                const Text(
                  'Доступно в Premium-подписке. Нажмите для раскрытия.',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (_isExpanded) ...[
                const SizedBox(height: 10),
                _buildLinkifiedText(widget.analysisText, widget.isLightTheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkifiedText(String text, bool isLightTheme) {
    final urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final matches = urlRegExp.allMatches(text);
    
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isLightTheme ? Colors.black87 : Colors.white,
          fontSize: 13,
          height: 1.45,
        ),
      );
    }

    final List<InlineSpan> spans = [];
    int currentPosition = 0;

    for (final match in matches) {
      if (match.start > currentPosition) {
        spans.add(TextSpan(
          text: text.substring(currentPosition, match.start),
          style: TextStyle(
            color: isLightTheme ? Colors.black87 : Colors.white,
            fontSize: 13,
            height: 1.45,
          ),
        ));
      }
      
      final url = match.group(0)!;
      String displayUrl = url;
      try {
        final uri = Uri.parse(url);
        displayUrl = uri.host.replaceFirst('www.', '');
      } catch (_) {}
      
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: widget.categoryColor.withAlpha(isLightTheme ? 40 : 60),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: widget.categoryColor.withAlpha(isLightTheme ? 100 : 150), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_rounded, size: 12, color: widget.categoryColor),
                  const SizedBox(width: 4),
                  Text(
                    displayUrl,
                    style: TextStyle(
                      color: widget.categoryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      currentPosition = match.end;
    }

    if (currentPosition < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPosition),
        style: TextStyle(
          color: isLightTheme ? Colors.black87 : Colors.white,
          fontSize: 13,
          height: 1.45,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

/// Человекочитаемая метка источника сигнала вместо фиктивного «ИИ 98%».
String _sourceLabel(String? source) {
  final s = (source ?? '').toLowerCase();
  if (s.startsWith('tg:') || s.contains('telegram')) return 'ИЗ TELEGRAM';
  if (s.startsWith('vk:')) return 'ИЗ VK';
  if (s.contains('mobile') || s.contains('app')) return 'ОТ ЖИТЕЛЯ';
  if (s.contains('sensor')) return 'МОНИТОРИНГ';
  return 'ГОРОДСКОЙ СИГНАЛ';
}


/// «Память места» (killer-фича по аудиту Astra): история сигналов вокруг
/// точки — текущие + архив. Показывает повторяющиеся проблемы.
class _PlaceMemoryBlock extends StatefulWidget {
  final Map<String, dynamic> complaint;
  final bool isLightTheme;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color accent;

  const _PlaceMemoryBlock({
    required this.complaint,
    required this.isLightTheme,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.accent,
  });

  @override
  State<_PlaceMemoryBlock> createState() => _PlaceMemoryBlockState();
}

class _PlaceMemoryBlockState extends State<_PlaceMemoryBlock> {
  List<Map<String, dynamic>> _items = [];
  List<String> _recurring = [];
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lat = widget.complaint['lat'] ?? widget.complaint['latitude'];
      final lng = widget.complaint['lng'] ?? widget.complaint['longitude'];
      if (lat == null || lng == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final resp = await http
          .get(Uri.parse(
              '${MapConfig.backendApiBaseUrl}/reports/place-history?lat=$lat&lng=$lng&radius_m=250&limit=12'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(
                m.map((k, v) => MapEntry(k.toString(), v))))
            .toList();
        final selfId = widget.complaint['id']?.toString();
        items.removeWhere((i) => i['id']?.toString() == selfId);
        if (mounted) {
          setState(() {
            _items = items;
            _recurring = (data['recurring_categories'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 20,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }
    if (_items.isEmpty) return const SizedBox.shrink();

    final border = widget.isLightTheme
        ? Colors.black.withOpacity(0.10)
        : Colors.white.withOpacity(0.12);
    final fill = widget.isLightTheme
        ? Colors.white
        : Colors.white.withOpacity(0.04);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 16, color: widget.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Память места: ${_items.length} '
                      '${_items.length == 1 ? 'сигнал' : 'сигналов'} рядом',
                      style: TextStyle(
                        color: widget.primaryTextColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_recurring.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ПОВТОРЯЕТСЯ',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: widget.secondaryTextColor,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_recurring.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Повторяющиеся темы: ${_recurring.join(', ')}',
                        style: TextStyle(
                          color: widget.secondaryTextColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ..._items.take(6).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5, right: 8),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: widget.accent.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                "${item['title'] ?? 'Сигнал'}"
                                "${item['created_at'] != null ? ' · ${item['created_at'].toString().split('T').first}' : ''}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: widget.secondaryTextColor,
                                  fontSize: 11.5,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


/// Компактная кнопка перелистывания сигналов в шторке.
class _SignalNavButton extends StatelessWidget {
  const _SignalNavButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF00E5FF).withOpacity(0.14)
              : Colors.grey.withOpacity(0.10),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: enabled
                ? const Color(0xFF00E5FF).withOpacity(0.5)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? const Color(0xFF00E5FF) : Colors.grey,
        ),
      ),
    );
  }
}
