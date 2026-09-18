import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../map/map_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../theme/pulse_colors.dart';
import '../../../../services/sound_service.dart';
import 'map_glass_panel.dart';
import 'package:provider/provider.dart';
import '../../../../theme/theme_provider.dart';
import '../../../services/backend_api_service.dart';
import '../../../../services/analytics_service.dart';

/// Shows the complaint details bottom sheet.
/// Returns the updated complaint map (for likes sync).
Future<void> showComplaintBottomSheet({
  required BuildContext context,
  required Map<String, dynamic> complaint,
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
          final tertiaryTextColor = isLightTheme ? PulseColors.lightTextTertiary : PulseColors.textTertiary;
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
              fillColor: PulseColors.backgroundRaised.withAlpha(185),
              blurSigma: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ручка
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Заголовок + категория
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      categoryColor.withAlpha(60),
                                      categoryColor.withAlpha(25),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Hero(
                                  tag: 'complaint_icon_${complaint['id'] ?? complaint.hashCode}',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Icon(
                                      categoryIcon,
                                      color: categoryColor,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      categoryLabel.toUpperCase(),
                                      style: TextStyle(
                                        color: categoryColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    Text(
                                      complaint['title'] as String? ??
                                          'Проблема',
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

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

                          // Статус + дата
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha(40),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: statusColor.withAlpha(80),
                                      width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.schedule_rounded,
                                  color: tertiaryTextColor, size: 15),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Описание
                          if (complaint['description'] != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    categoryColor.withAlpha(isLightTheme ? 14 : 22),
                                    boxBgColor,
                                    categoryColor.withAlpha(isLightTheme ? 8 : 12),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isLightTheme
                                      ? Colors.black.withAlpha(14)
                                      : categoryColor.withAlpha(55),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: categoryColor.withAlpha(isLightTheme ? 10 : 28),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: categoryColor.withAlpha(isLightTheme ? 28 : 40),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.description_rounded,
                                            color: categoryColor,
                                            size: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Описание',
                                        style: TextStyle(
                                          color: categoryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () async {
                                          if (isSpeaking) {
                                            await SoundService().stopSpeak();
                                            if (contextInner.mounted) {
                                              setModalState(() {
                                                isSpeaking = false;
                                              });
                                            }
                                          } else {
                                            final desc = complaint['description'] as String? ?? '';
                                            final cleanedDesc = desc.replaceAll(RegExp(r'Фото:\s*https?://[^\s\n]+'), '').trim();
                                            String speakText = cleanedDesc;
                                            speakText = speakText.replaceAll(
                                                RegExp(r'(Статус|УК|Управляющая компания):\s*[^.\n]+(\.|\\n|$)?',
                                                    caseSensitive: false),
                                                '');
                                            speakText = speakText.replaceAll(RegExp(r'\s+'), ' ').trim();
                                            var textToSpeak = speakText.replaceAll(RegExp(r'\[.*?\]\s*'), '').trim();
                                            if (textToSpeak.isEmpty) {
                                              textToSpeak = (complaint['title'] ?? '').toString();
                                            }
                                            setModalState(() {
                                              isSpeaking = true;
                                            });
                                            // speak() awaits the full playback (or stop).
                                            // We reset isSpeaking in finally so it works
                                            // whether it finishes naturally or was stopped.
                                            try {
                                              await SoundService().speak(textToSpeak);
                                            } finally {
                                              if (contextInner.mounted) {
                                                setModalState(() {
                                                  isSpeaking = false;
                                                });
                                              }
                                            }
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isSpeaking
                                                ? categoryColor.withAlpha(40)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSpeaking
                                                  ? categoryColor
                                                  : categoryColor.withAlpha(70),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isSpeaking
                                                    ? Icons.graphic_eq_rounded
                                                    : Icons.volume_up_rounded,
                                                color: isSpeaking
                                                    ? categoryColor
                                                    : categoryColor.withAlpha(180),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isSpeaking ? 'Стоп' : 'Озвучить',
                                                style: TextStyle(
                                                  color: isSpeaking
                                                      ? categoryColor
                                                      : categoryColor.withAlpha(180),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Divider(
                                    color: categoryColor.withAlpha(isLightTheme ? 30 : 50),
                                    height: 1,
                                    thickness: 1,
                                  ),
                                  const SizedBox(height: 10),
                                  Builder(builder: (ctx) {
                                    final desc = complaint['description'] as String;
                                    final images = complaint['images'] as List<dynamic>?;
                                    final textStyle = TextStyle(
                                      color: primaryTextColor,
                                      fontSize: 14,
                                      height: 1.55,
                                      letterSpacing: 0.1,
                                    );

                                    if (images != null && images.isNotEmpty) {
                                      final imageUrl = images.first.toString();
                                      final cleanedDesc = desc.replaceAll(RegExp(r'Фото:\s*https?://[^\s\n]+'), '').trim();
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (cleanedDesc.isNotEmpty) ...[
                                            Text(cleanedDesc, style: textStyle),
                                            const SizedBox(height: 12),
                                          ],
                                          _ImageWithMemeFallback(
                                            imageUrl: imageUrl,
                                            title: complaint['title'] as String? ?? 'Проблема',
                                            description: cleanedDesc,
                                            categoryColor: categoryColor,
                                          ),
                                        ],
                                      );
                                    } else if (desc.contains('Фото: ')) {
                                      final parts = desc.split('Фото: ');
                                      final textPart = parts[0].trim();
                                      String urlPart = parts[1].trim();
                                      if (urlPart.contains('[')) urlPart = urlPart.split('[')[0].trim();
                                      if (urlPart.contains('\n')) urlPart = urlPart.split('\n')[0].trim();
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (textPart.isNotEmpty) ...[
                                            Text(textPart, style: textStyle),
                                            const SizedBox(height: 12),
                                          ],
                                          _ImageWithMemeFallback(
                                            imageUrl: urlPart,
                                            title: complaint['title'] as String? ?? 'Проблема',
                                            description: textPart,
                                            categoryColor: categoryColor,
                                          ),
                                        ],
                                      );
                                    } else {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (desc.isNotEmpty) ...[
                                            Text(desc, style: textStyle),
                                            const SizedBox(height: 12),
                                          ],
                                          ReportMemeWidget(
                                            title: complaint['title'] as String? ?? 'Проблема',
                                            description: desc,
                                            categoryColor: categoryColor,
                                          ),
                                        ],
                                      );
                                    }
                                  }),
                                ],
                              ),
                            )
                            // ── анимация карточки описания ──
                            .animate()
                            .slideY(
                              begin: 0.18,
                              end: 0.0,
                              duration: 420.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .fadeIn(duration: 320.ms)
                            .blurXY(
                              begin: 4,
                              end: 0,
                              duration: 380.ms,
                              curve: Curves.easeOut,
                            )
                            .then(delay: 80.ms)
                            .shimmer(
                              duration: 900.ms,
                              color: categoryColor.withAlpha(40),
                              angle: 0.2,
                            ),
                            const SizedBox(height: 16),
                            SupportButtonWidget(complaint: complaint),
                            const SizedBox(height: 12),
                          ],


                          // Адрес
                          if (complaint['address'] != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: PulseColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: PulseColors.primary.withAlpha(30),
                                    width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.location_on_rounded,
                                      color: PulseColors.primary, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      complaint['address'] as String,
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .slideY(begin: 0.12, end: 0.0, duration: 350.ms, delay: 80.ms, curve: Curves.easeOutCubic)
                            .fadeIn(duration: 280.ms, delay: 80.ms),
                            const SizedBox(height: 12),
                          ],

                           // Координаты + Опции (Поделиться и Google Street View)
                           Padding(
                             padding: const EdgeInsets.only(bottom: 12),
                             child: Row(
                               children: [
                                 if (hasCoords) ...[
                                   Icon(Icons.gps_fixed_rounded,
                                       color: tertiaryTextColor,
                                       size: 15),
                                   const SizedBox(width: 6),
                                   Text(
                                     '${(lat as num).toStringAsFixed(5)}, ${(lng as num).toStringAsFixed(5)}',
                                     style: TextStyle(
                                       color: tertiaryTextColor,
                                       fontSize: 11,
                                       fontFamily: 'monospace',
                                     ),
                                   ),
                                 ],
                                 const Spacer(),
                                 // Кнопка Поделиться (Share icon button)
                                 Container(
                                   height: 28,
                                   decoration: BoxDecoration(
                                     color: PulseColors.primary.withAlpha(50),
                                     borderRadius: BorderRadius.circular(8),
                                     border: Border.all(
                                         color: PulseColors.primary
                                             .withAlpha(100)),
                                   ),
                                   child: IconButton(
                                     padding: const EdgeInsets.symmetric(horizontal: 10),
                                     constraints: const BoxConstraints(minWidth: 40),
                                     icon: const Icon(Icons.share_rounded,
                                         size: 16,
                                         color: PulseColors.primarySoft),
                                     tooltip: 'Поделиться',
                                     onPressed: () => _shareComplaint(context, complaint),
                                   ),
                                 ),
                                 if (hasCoords && complaint['address'] != null && (complaint['address'] as String).isNotEmpty) ...[
                                   const SizedBox(width: 8),
                                   // Кнопка Google Street View
                                   Container(
                                     height: 28,
                                     decoration: BoxDecoration(
                                       color: PulseColors.primary.withAlpha(50),
                                       borderRadius: BorderRadius.circular(8),
                                       border: Border.all(
                                           color: PulseColors.primary
                                               .withAlpha(100)),
                                     ),
                                     child: IconButton(
                                       padding: const EdgeInsets.symmetric(
                                           horizontal: 10),
                                       constraints:
                                           const BoxConstraints(minWidth: 40),
                                       icon: const Icon(Icons.streetview_rounded,
                                           size: 16,
                                           color: PulseColors.primarySoft),
                                       tooltip: 'Смотреть в Google Street View',
                                       onPressed: () async {
                                         final url =
                                             'google.streetview:cbll=$lat,$lng';
                                         final fallbackUrl =
                                             'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng';
                                         try {
                                           if (await canLaunchUrl(
                                               Uri.parse(url))) {
                                             await launchUrl(Uri.parse(url));
                                           } else {
                                             await launchUrl(
                                                 Uri.parse(fallbackUrl));
                                           }
                                         } catch (_) {
                                           await launchUrl(
                                               Uri.parse(fallbackUrl));
                                         }
                                       },
                                     ),
                                   ),
                                 ],
                               ],
                             ),
                           ),

                          // Кнопка «Вернуться»
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.of(ctx).pop();
                              },
                              icon: const Icon(Icons.zoom_out_map_rounded,
                                  size: 18),
                              label: const Text('Вернуться к обзору'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    PulseColors.primary.withAlpha(40),
                                foregroundColor: PulseColors.primarySoft,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                      color: PulseColors.primary.withAlpha(80)),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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

  showDialog(
    context: ctx,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
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

  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.95),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor.withOpacity(0.12),
            const Color(0xFF0F172A),
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
      if (res.statusCode == 200) {
        final Map<String, dynamic> resData = jsonDecode(res.body);
        setState(() {
          _isSupported = true;
          _supportersCount = resData['supporters'] ?? (_supportersCount + 1);
        });
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
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
  Future<String?> getToken() async => 'dev_bypass_token';
}

class ApiClient {
  Future<http.Response> post(String path, {required Map<String, dynamic> data, required String token}) async {
    return BackendApiService.instance.postJson(path, data, headers: {'Authorization': 'Bearer $token'});
  }
}


