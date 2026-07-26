import '../services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_router.dart';
import '../screens/map/widgets/map_glass_panel.dart';
import '../services/notification_catalog.dart';
import '../theme/pulse_colors.dart';
import '../utils/situation_helper.dart';
import 'image_lightbox.dart';
import 'safe_image_widget.dart';
import '../services/pdf_complaint_service.dart';

/// Р”РµС‚Р°Р»СЊРЅС‹Р№ РїСЂРѕСЃРјРѕС‚СЂ СЃРёРіРЅР°Р»Р° СЃ РєСЂР°С‚РєРёРј РР-Р°РЅР°Р»РёР·РѕРј Рё РїСЂРѕР»РёСЃС‚С‹РІР°РЅРёРµРј.
Future<void> showSwipeableReportDetail({
  required BuildContext context,
  required List<dynamic> reports,
  required int initialIndex,
}) async {
  if (reports.isEmpty) return;
  final safeIndex = initialIndex.clamp(0, reports.length - 1);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    enableDrag: true,
    isScrollControlled: true,
    builder: (ctx) {
      return _SwipeableReportDetailSheet(
        reports: reports,
        initialIndex: safeIndex,
      );
    },
  );
}

class _SwipeableReportDetailSheet extends StatefulWidget {
  const _SwipeableReportDetailSheet({
    required this.reports,
    required this.initialIndex,
  });

  final List<dynamic> reports;
  final int initialIndex;

  @override
  State<_SwipeableReportDetailSheet> createState() =>
      _SwipeableReportDetailSheetState();
}

class _SwipeableReportDetailSheetState extends State<_SwipeableReportDetailSheet> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: MapGlassPanel(
            borderRadius: BorderRadius.circular(24),
            padding: EdgeInsets.zero,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xEA0B0F19)
                : const Color(0xF5FAFDFE),
            blurSigma: 26,
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PulseColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        Text(
                          'Сигнал ${_currentIndex + 1} из ${widget.reports.length}',
                          style: TextStyle(
                            color: PulseColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: PulseColors.textSecondary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  if (widget.reports.length == 1)
                    Flexible(
                      child: _ReportDetailPage(report: widget.reports.first),
                    )
                  else ...[
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: widget.reports.length,
                        onPageChanged: (index) => setState(() => _currentIndex = index),
                        itemBuilder: (context, index) {
                          return _ReportDetailPage(report: widget.reports[index]);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.reports.length.clamp(0, 8), (i) {
                          final active = i == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? PulseColors.primary
                                  : PulseColors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportDetailPage extends StatelessWidget {
  const _ReportDetailPage({required this.report});

  final dynamic report;

  @override
  Widget build(BuildContext context) {
    final category = (report['category'] ?? 'РџСЂРѕС‡РµРµ') as String;
    final descriptor = NotificationCatalog.describe(category);
    final itemColor = descriptor.color;
    final title = report['title']?.toString() ?? 'Р‘РµР· Р·Р°РіРѕР»РѕРІРєР°';
    final address = report['address']?.toString() ?? 'Р‘РµР· Р°РґСЂРµСЃР°';
    final descText = (report['description'] ?? report['summary'] ?? '').toString();
    final cleanDesc = SituationHelper.cleanDescription(descText, title);
    final imageUrls = SituationHelper.extractImageUrls(report);

    final lat = report['lat']?.toString() ?? report['latitude']?.toString();
    final lng = report['lng']?.toString() ?? report['longitude']?.toString();
    final reportId = report['id']?.toString() ?? '';
    final hasCoords = lat != null && lng != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: itemColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(descriptor.icon, color: itemColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: itemColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        color: PulseColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.location_on_rounded, color: itemColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(color: PulseColors.textSecondary, fontSize: 13),
                ),
              ),
              StatefulBuilder(
                builder: (ctx, setTrackState) {
                  return FutureBuilder<List<String>>(
                    future: PdfComplaintService.instance.getSubscribedHouses(),
                    builder: (c, snap) {
                      final isTracked = snap.data?.contains(address.trim().toLowerCase()) ?? false;
                      return IconButton(
                        icon: Icon(
                          isTracked ? Icons.notifications_active_rounded : Icons.add_location_alt_rounded,
                          color: isTracked ? Colors.amberAccent : itemColor,
                          size: 22,
                        ),
                        tooltip: isTracked ? 'Отслеживание включено' : 'Включить пуш-уведомления по дому',
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final updated = await PdfComplaintService.instance.toggleHouseSubscription(address);
                          setTrackState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  updated
                                      ? '🔔 Включено индивидуальное отслеживание сигналов дома: $address'
                                      : '🔕 Отслеживание дома отключено: $address',
                                ),
                                backgroundColor: updated ? PulseColors.primary : Colors.blueGrey,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionBox(
            icon: Icons.description_outlined,
            title: 'Описание ситуации',
            child: _buildDescriptionWidget(cleanDesc, context, itemColor),
            accent: itemColor,
            trailing: StatefulBuilder(
              builder: (ctx, setBoxState) {
                final isSpeaking = SoundService().isSpeakingTts;
                return IconButton(
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                    color: itemColor,
                    size: 18,
                  ),
                  onPressed: () async {
                    if (isSpeaking) {
                      await SoundService().stopSpeak();
                    } else {
                      final textToSpeak = [
                        title,
                        cleanDesc.isNotEmpty ? cleanDesc : null,
                      ].whereType<String>().join('. ');
                      await SoundService().speak(textToSpeak, category: category);
                    }
                    setBoxState(() {});
                  },
                );
              }
            ),
          ),
          const SizedBox(height: 14),
          // Banner for house signals subscription
          FutureBuilder<List<String>>(
            future: PdfComplaintService.instance.getSubscribedHouses(),
            builder: (ctx, snapshot) {
              final isSubbed = snapshot.data?.contains(address.trim().toLowerCase()) ?? false;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSubbed ? PulseColors.primary.withOpacity(0.18) : const Color(0xFF1E293B).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSubbed ? PulseColors.primary : Colors.white12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSubbed ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      color: isSubbed ? PulseColors.primary : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSubbed ? 'Уведомления по дому активны' : 'Получать уведомления о сигналах дома',
                            style: TextStyle(
                              color: isSubbed ? PulseColors.primary : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            address,
                            style: const TextStyle(color: Colors.white60, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSubbed ? PulseColors.primary.withOpacity(0.3) : itemColor.withOpacity(0.2),
                        foregroundColor: isSubbed ? Colors.white : itemColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final res = await PdfComplaintService.instance.toggleHouseSubscription(address);
                        (ctx as Element).markNeedsBuild();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res ? 'Вы подписались на сигналы дома: $address' : 'Подписка отменена'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Text(
                        isSubbed ? 'Подписан' : 'Включить',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _LegalAnalysisWidget(
            category: category,
            description: descText,
            accentColor: itemColor,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Google Street View
              if (hasCoords)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: itemColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: itemColor.withOpacity(0.20)),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.streetview_rounded, color: itemColor),
                        tooltip: 'Google Street View',
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
                ),
              // PDF Обращение в ЖКХ / Администрацию
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: itemColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: itemColor.withOpacity(0.20)),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.picture_as_pdf_rounded, color: itemColor),
                      tooltip: 'Скачать PDF обращение в ЖКХ',
                      onPressed: () async {
                        final titleText = report['title']?.toString() ?? 'Обращение';
                        final repId = report['id'] ?? 101;
                        await PdfComplaintService.instance.generateAndPrintOfficialPdf(
                          context: context,
                          reportId: repId,
                          title: titleText,
                          category: category,
                          address: address,
                          description: descText,
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Подписка на сигналы дома
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: StatefulBuilder(
                    builder: (ctx, setBtnState) {
                      return FutureBuilder<List<String>>(
                        future: PdfComplaintService.instance.getSubscribedHouses(),
                        builder: (context, snapshot) {
                          final isSubbed = snapshot.data?.contains(address.trim().toLowerCase()) ?? false;
                          return Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSubbed ? PulseColors.primary.withOpacity(0.25) : itemColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isSubbed ? PulseColors.primary : itemColor.withOpacity(0.20)),
                            ),
                            child: IconButton(
                              icon: Icon(
                                isSubbed ? Icons.home_work_rounded : Icons.add_location_alt_rounded,
                                color: isSubbed ? PulseColors.primary : itemColor,
                              ),
                              tooltip: isSubbed ? 'Вы подписаны на сигналы этого дома' : 'Подписаться на сигналы дома',
                              onPressed: () async {
                                final res = await PdfComplaintService.instance.toggleHouseSubscription(address);
                                setBtnState(() {});
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res ? 'Вы подписались на сигналы дома: $address' : 'Подписка снята'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              // Поделиться
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: itemColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: itemColor.withOpacity(0.20)),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.share_rounded, color: itemColor),
                      tooltip: 'Поделиться',
                      onPressed: () {
                        final titleText = report['title']?.toString() ?? 'Проблема';
                        final text = '❗️ $titleText\n\n$descText\n\nПриложение City Pulse Нижневартовск';
                        Share.share(text);
                      },
                    ),
                  ),
                ),
              ),
              // Назад / Вернуться к обзору
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: itemColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: itemColor.withOpacity(0.20)),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: itemColor),
                      tooltip: 'Вернуться к обзору',
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionWidget(String text, BuildContext context, Color themeColor) {
    if (text.isEmpty) {
      return Text(
        'Описание отсутствует.',
        style: TextStyle(color: PulseColors.textPrimary, fontSize: 13.5),
      );
    }

    final urlRegex = RegExp(r'(https?://[^\s]+)');
    final matches = urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(color: PulseColors.textPrimary, fontSize: 13.5, height: 1.45),
      );
    }

    final List<Widget> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(Text(
          text.substring(lastMatchEnd, match.start),
          style: TextStyle(color: PulseColors.textPrimary, fontSize: 13.5, height: 1.45),
        ));
      }

      final urlStr = match.group(0)!;
      spans.add(
        InkWell(
          onTap: () async {
            try {
              final uri = Uri.parse(urlStr);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } catch (_) {}
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new_rounded, size: 14, color: themeColor),
                const SizedBox(width: 4),
                Text(
                  urlStr.length > 30 ? '${urlStr.substring(0, 27)}...' : urlStr,
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(Text(
        text.substring(lastMatchEnd),
        style: TextStyle(color: PulseColors.textPrimary, fontSize: 13.5, height: 1.45),
      ));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: spans,
    );
  }

  Widget _sectionBox({
    required IconData icon,
    required String title,
    required Widget child,
    Color? accent,
    Widget? trailing,
  }) {
    final color = accent ?? PulseColors.textSecondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent != null
            ? color.withOpacity(0.04)
            : PulseColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent != null
              ? color.withOpacity(0.15)
              : PulseColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: PulseColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _analysisRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: PulseColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12, color: PulseColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildReportPhotoWidget({
    required BuildContext context,
    required List<String> imageUrls,
    required String category,
    required Color color,
    required double? lat,
    required double? lng,
  }) {
    final validUrls = imageUrls.where((url) => url.startsWith('http')).toList();

    if (validUrls.isNotEmpty) {
      return Column(
        children: validUrls.asMap().entries.map((entry) {
          final index = entry.key;
          final url = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SafeImageWidget(
              imageUrl: url,
              height: 180,
              borderRadius: BorderRadius.circular(16),
              heroTag: url,
              onTap: () => ImageLightbox.show(context, validUrls, initialIndex: index),
              fallbackWidget: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined, color: Colors.white38, size: 36),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFallbackCard(String category, Color color, double? lat, double? lng) {
    final descriptor = NotificationCatalog.describe(category);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.25),
              color.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Opacity(
                opacity: 0.12,
                child: Icon(descriptor.icon, size: 140, color: color),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'РЎРР“РќРђР›: ${category.toUpperCase()}',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Р¤РѕС‚РѕРјР°С‚РµСЂРёР°Р»С‹ Р·Р°С‰РёС‰РµРЅС‹ Р°РІС‚РѕСЂСЃРєРёРј РїСЂР°РІРѕРј. Р—Р°РїРёСЃСЊ РїСЂРѕРІРµСЂРµРЅР° РіРѕСЂРѕРґСЃРєРѕР№ СЃРёСЃС‚РµРјРѕР№.',
                          style: TextStyle(
                            color: PulseColors.textPrimary.withOpacity(0.7),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                        if (lat != null && lng != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'РљРѕРѕСЂРґРёРЅР°С‚С‹: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                            style: TextStyle(
                              color: PulseColors.textSecondary,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (lat != null && lng != null) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 80,
                        height: 80,
                        color: PulseColors.surfaceSoft,
                        child: SafeImageWidget(
                          imageUrl: 'https://static-maps.yandex.ru/1.x/?ll=$lng,$lat&z=14&l=map&size=160,160&scale=2.0',
                          width: 80,
                          height: 80,
                          borderRadius: BorderRadius.circular(12),
                          fallbackWidget: Icon(Icons.map_rounded, color: color, size: 28),
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
}

class _LegalInfo {
  final String shortSummary;
  final String details;
  final Map<String, String> links;

  const _LegalInfo({
    required this.shortSummary,
    required this.details,
    required this.links,
  });
}

class _LegalAnalysisWidget extends StatefulWidget {
  final String category;
  final String description;
  final Color accentColor;

  const _LegalAnalysisWidget({
    required this.category,
    required this.description,
    required this.accentColor,
  });

  @override
  State<_LegalAnalysisWidget> createState() => _LegalAnalysisWidgetState();
}

class _LegalAnalysisWidgetState extends State<_LegalAnalysisWidget> {
  bool _isExpanded = false;
  bool? _isVip;

  @override
  void initState() {
    super.initState();
    _checkVipStatus();
  }

  Future<void> _checkVipStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final vip = prefs.getBool('is_premium_vip') ?? prefs.getBool('is_vip') ?? false;
    if (mounted) {
      setState(() {
        _isVip = vip;
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

  _LegalInfo _getLegalAnalysis(String cat, String description) {
    final c = cat.toLowerCase();
    final d = description.toLowerCase();

    if (c.contains('жкх') || c.contains('водоснаб') || c.contains('отопл') || c.contains('труб') || d.contains('прорыв') || d.contains('отопл')) {
      return const _LegalInfo(
        shortSummary: 'Сроки устранения аварий водоснабжения/тепла регулируются Постановлением Правительства РФ № 354.',
        details: 'Согласно Постановлению Правительства РФ № 354 от 06.05.2011, допустимая продолжительность перерыва отопления составляет не более 24 часов суммарно в течение месяца; не более 16 часов единовременно (при температуре воздуха в жилых помещениях от +12 до +18 °C).\n\nВ случае аварии на теплотрассе ремонтные службы обязаны устранить прорыв в срок от 4 до 24 часов в зависимости от диаметра трубы.\n\nЗа каждый час превышения допустимого перерыва размер платы за коммунальную услугу снижается на 0,15%.',
        links: {
          'Постановление Правительства РФ № 354': 'https://www.consultant.ru/document/cons_doc_LAW_114247/',
          'Жилищный Кодекс РФ (ст. 157)': 'https://www.consultant.ru/document/cons_doc_LAW_51057/1eb392f4df67822a106198642a8b9f16d735cc99/'
        },
      );
    } else if (c.contains('дорог') || c.contains('асф') || d.contains('яма') || d.contains('колея')) {
      return const _LegalInfo(
        shortSummary: 'Выбоины и ямы на дорогах должны быть устранены в срок от 1 до 12 дней (ГОСТ Р 50597-2017).',
        details: 'Согласно ГОСТ Р 50597-2017 "Дороги автомобильные и улицы", предельные размеры отдельных просадок, выбоин и т.п. не должны превышать по длине 15 см, ширине — 60 см и глубине — 5 см.\n\nСрок устранения повреждений составляет от 1 до 12 суток в зависимости от категории дороги.\n\nЗа несоблюдение требований по обеспечению безопасности дорожного движения предусмотрена административная ответственность по ст. 12.34 КоАП РФ.',
        links: {
          'ГОСТ Р 50597-2017': 'https://docs.cntd.ru/document/1200146747',
          'КоАП РФ Статья 12.34': 'https://www.consultant.ru/document/cons_doc_LAW_34661/29d2bbf4083d69c73bc701f60046b41ab1d955fa/'
        },
      );
    } else if (c.contains('освещ') || c.contains('фонар') || d.contains('темно')) {
      return const _LegalInfo(
        shortSummary: 'Неисправности наружного освещения улиц должны устраняться в течение 5-10 суток.',
        details: 'Доля действующих светильников на улицах города должна составлять не менее 95% (ГОСТ Р 50597-2017).\n\nСветильники в пешеходных тоннелях должны работать круглосуточно. Отказы в работе осветительных установок на дорогах должны устраняться в течение 5 суток, на пешеходных переходах — в течение 1 суток.\n\nНормативы уровня освещенности регулируются СП 52.13330.2016.',
        links: {
          'ГОСТ Р 50597-2017 (Освещение)': 'https://docs.cntd.ru/document/1200146747',
          'СП 52.13330.2016 (Освещение)': 'https://docs.cntd.ru/document/1200141680'
        },
      );
    } else if (c.contains('мусор') || c.contains('свал') || d.contains('контейнер')) {
      return const _LegalInfo(
        shortSummary: 'Сроки вывоза ТКО регулируются СанПиН 2.1.3684-21. При температуре выше +5 °C вывоз должен быть ежедневным.',
        details: 'Сроки сбора и вывоза ТКО установлены СанПиН 2.1.3684-21. В теплый период (при температуре выше +5 °C) вывоз отходов должен производиться ежедневно.\n\nВ холодное время года (ниже +5 °C) допускается вывоз не реже одного раза в 3 суток.\n\nЗавалы крупногабаритного мусора на контейнерных площадках должны устраняться не реже 1 раза в неделю.',
        links: {
          'СанПиН 2.1.3684-21': 'https://docs.cntd.ru/document/573659529',
          'Федеральный закон № 89-ФЗ "Об отходах"': 'https://www.consultant.ru/document/cons_doc_LAW_19109/'
        },
      );
    } else if (c.contains('двор') || c.contains('площад') || d.contains('горка')) {
      return const _LegalInfo(
        shortSummary: 'Требования к содержанию придомовой территории регулируются Постановлением Госстроя РФ № 170.',
        details: 'Согласно Правилам и нормам технической эксплуатации жилищного фонда (Постановление Госстроя РФ от 27.09.2003 № 170), уборка дворов должна производиться ежедневно управляющей организацией.\n\nДетские и спортивные площадки должны регулярно проверяться на предмет безопасности. Повреждения оборудования площадок, угрожающие здоровью детей, должны немедленно огораживаться, а дефекты устраняться в срок от 1 до 5 суток.\n\nОтветственность за состояние площадок несет УК или ТСЖ.',
        links: {
          'Постановление Госстроя РФ № 170': 'https://docs.cntd.ru/document/901879105',
          'ГОСТ Р 52169-2012 (Безопасность оборудования площадок)': 'https://docs.cntd.ru/document/1200095815'
        },
      );
    } else if (c.contains('животн') || d.contains('собак') || d.contains('кош')) {
      return const _LegalInfo(
        shortSummary: 'Права владельцев животных и правила отлова безнадзорных животных регулируются ФЗ № 498.',
        details: 'Согласно Федеральному закону от 27.12.2018 № 498-ФЗ "Об ответственном обращении с животными", отлов безнадзорных животных должен производиться методом ОСВВ (отлов-стерилизация-вакцинация-возврат).\n\nЖестокое обращение с животными влечет уголовную ответственность по ст. 245 УК РФ.\n\nВладельцы обязаны соблюдать правила выгула (поводок, намордник для опасных пород, уборка за животным).',
        links: {
          'ФЗ № 498 "Об обращении с животными"': 'https://www.consultant.ru/document/cons_doc_LAW_314646/',
          'УК РФ Статья 245': 'https://www.consultant.ru/document/cons_doc_LAW_10699/5a914ec8e2b8606c483a9a1d48ffbf5a74e5088c/'
        },
      );
    } else if (c.contains('опасн') || d.contains('люк') || d.contains('стройк')) {
      return const _LegalInfo(
        shortSummary: 'В случае выявления открытых люков, котлованов или неогражденных опасных зон ответственные лица несут ответственность.',
        details: 'В случае выявления открытых люков, котлованов или неогражденных опасных зон ответственные лица несут уголовную ответственность по ст. 216 УК РФ (в случае травм) или административную по ст. 9.11 КоАП РФ.\n\nОрганы власти обязаны незамедлительно принять меры по вызову дежурных служб.',
        links: {
          'УК РФ Статья 216': 'https://www.consultant.ru/document/cons_doc_LAW_10699/71e9882f0ee90ff66046e7f8e3df3e4811a2f1c8/',
          'КоАП РФ Статья 9.11': 'https://www.consultant.ru/document/cons_doc_LAW_34661/29849206d203cf7bbf72ea00fa1b7fcf752c1e45/'
        },
      );
    }

    return const _LegalInfo(
      shortSummary: 'Обращения граждан в органы власти регулируются Федеральным законом № 59-ФЗ (срок ответа — до 30 дней).',
      details: 'Согласно Федеральному закону от 02.05.2006 № 59-ФЗ "О порядке рассмотрения обращений граждан Российской Федерации", все обращения подлежат обязательной регистрации в течение 3 дней.\n\nСрок рассмотрения обращений составляет 30 дней со дня регистрации. В исключительных случаях срок может быть продлен еще на 30 дней.\n\nЗа нарушение порядка рассмотрения обращений должностные лица несут ответственность по ст. 5.59 КоАП РФ (штраф от 5000 до 10000 рублей).',
      links: {
        'Федеральный закон № 59-ФЗ': 'https://www.consultant.ru/document/cons_doc_LAW_60083/',
        'КоАП РФ Статья 5.59': 'https://www.consultant.ru/document/cons_doc_LAW_34661/fa8249f4b3017a5616b23d91cf972f0868f000b2/'
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isVip == null) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
          ),
        ),
      );
    }

    final isVip = _isVip!;
    final info = _getLegalAnalysis(widget.category, widget.description);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(isDark ? 0.07 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.35), width: 1.2),
      ),
      child: InkWell(
        onTap: () {
          if (isVip) {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          } else {
            _showVipPromo(context);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gavel_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '⚖️ АНАЛИЗ СИТУАЦИИ (ИИ)',
                          style: TextStyle(
                            color: isDark ? Colors.amber : const Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      isVip
                          ? (_isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded)
                          : Icons.lock_outline_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!isVip) ...[
                  Text(
                    'Доступно в Premium-подписке. Нажмите для раскрытия.',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  if (_isExpanded) ...[
                    Text(
                      info.shortSummary,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.details,
                      style: TextStyle(
                        color: textColor.withOpacity(0.9),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    if (info.links.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 8),
                      Text(
                        'Полезные ресурсы:',
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...info.links.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: InkWell(
                            onTap: () async {
                              try {
                                final uri = Uri.parse(entry.value);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              } catch (_) {}
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.link_rounded, color: Colors.amber, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ] else ...[
                    Text(
                      'Краткий анализ ситуации (нажмите для раскрытия)',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}