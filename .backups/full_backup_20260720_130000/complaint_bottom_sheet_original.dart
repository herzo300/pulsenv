import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/pulse_colors.dart';
import 'map_glass_panel.dart';

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
  final category = (complaint['category'] ?? '╨Я╤А╨╛╤З╨╡╨╡') as String;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (BuildContext contextInner, StateSetter setModalState) {
          final lat = complaint['lat'] ?? complaint['latitude'];
          final lng = complaint['lng'] ?? complaint['longitude'];
          final hasCoords = lat != null && lng != null;

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
                  // ╨а╤Г╤З╨║╨░
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
                          // ╨Ч╨░╨│╨╛╨╗╨╛╨▓╨╛╨║ + ╨║╨░╤В╨╡╨│╨╛╤А╨╕╤П
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
                                child: Icon(
                                  categoryIcon,
                                  color: categoryColor,
                                  size: 22,
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
                                          '╨Я╤А╨╛╨▒╨╗╨╡╨╝╨░',
                                      style: const TextStyle(
                                        color: Colors.white,
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

                          if (category == '╨Ъ╨░╨╝╨╡╤А╤Л') ...[
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
                                      '╨Ч╨Р╨У╨а╨г╨Ч╨Ъ╨Р ╨Я╨Ю╨в╨Ю╨Ъ╨Р...',
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

                          // ╨б╤В╨░╤В╤Г╤Б + ╨┤╨░╤В╨░
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
                                  color: Colors.white.withAlpha(120), size: 15),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(150),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ╨Ю╨┐╨╕╤Б╨░╨╜╨╕╨╡
                          if (complaint['description'] != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withAlpha(15),
                                    width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.description_outlined,
                                          color: Colors.white.withAlpha(140),
                                          size: 15),
                                      const SizedBox(width: 6),
                                      Text(
                                        '╨Ю╨┐╨╕╤Б╨░╨╜╨╕╨╡',
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(140),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Builder(builder: (ctx) {
                                    final desc =
                                        complaint['description'] as String;
                                    if (desc.contains('╨д╨╛╤В╨╛: http')) {
                                      final parts = desc.split('╨д╨╛╤В╨╛: ');
                                      final textPart = parts[0].trim();
                                      final urlPart = parts[1].trim();
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            textPart,
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withAlpha(220),
                                              fontSize: 14,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                              urlPart,
                                              width: double.infinity,
                                              height: 180,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, err,
                                                      stack) =>
                                                  const Text(
                                                      '╨Ю╤И╨╕╨▒╨║╨░ ╨╖╨░╨│╤А╤Г╨╖╨║╨╕ ╤Д╨╛╤В╨╛',
                                                      style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 12)),
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      return Text(
                                        desc,
                                        style: TextStyle(
                                          color: Colors.white.withAlpha(220),
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      );
                                    }
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ╨Р╨┤╤А╨╡╤Б
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
                                        color: Colors.white.withAlpha(210),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ╨Ъ╨╛╨╛╤А╨┤╨╕╨╜╨░╤В╤Л + Google Street View
                          if (hasCoords)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.gps_fixed_rounded,
                                      color: Colors.white.withAlpha(100),
                                      size: 15),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${(lat as num).toStringAsFixed(5)}, ${(lng as num).toStringAsFixed(5)}',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(100),
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const Spacer(),
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
                                      tooltip: '╨б╨╝╨╛╤В╤А╨╡╤В╤М ╨▓ Google Street View',
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
                              ),
                            ),

                          // ╨а╨╡╨░╨║╤Ж╨╕╨╕ ╨╕ ╨Э╨░╨┐╨╛╨╝╨╕╨╜╨░╨╜╨╕╤П
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (category == '╨Ь╨╡╤А╨╛╨┐╤А╨╕╤П╤В╨╕╨╡')
                                PopupMenuButton<Duration>(
                                  color: PulseColors.surface,
                                  onSelected: (Duration offset) {
                                    onScheduleReminder();
                                  },
                                  itemBuilder: (contextInner) => const [
                                    PopupMenuItem(
                                        value: Duration(minutes: 30),
                                        child: Text('╨Ч╨░ 30 ╨╝╨╕╨╜╤Г╤В',
                                            style: TextStyle(
                                                color: Colors.white))),
                                    PopupMenuItem(
                                        value: Duration(hours: 2),
                                        child: Text('╨Ч╨░ 2 ╤З╨░╤Б╨░',
                                            style: TextStyle(
                                                color: Colors.white))),
                                    PopupMenuItem(
                                        value: Duration(days: 1),
                                        child: Text('╨Ч╨░ ╨┤╨╡╨╜╤М',
                                            style: TextStyle(
                                                color: Colors.white))),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.notifications_active_rounded,
                                            color: categoryColor, size: 18),
                                        const SizedBox(width: 8),
                                        Text('╨Э╨░╨┐╨╛╨╝╨╜╨╕╤В╤М',
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withAlpha(200))),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ╨Ъ╨╜╨╛╨┐╨║╨░ ┬л╨Т╨╡╤А╨╜╤Г╤В╤М╤Б╤П┬╗
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                onZoomBack();
                              },
                              icon: const Icon(Icons.zoom_out_map_rounded,
                                  size: 18),
                              label: const Text('╨Т╨╡╤А╨╜╤Г╤В╤М╤Б╤П ╨║ ╨╛╨▒╨╖╨╛╤А╤Г'),
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
          );
        },
      );
    },
  ).whenComplete(() {
    // When bottom sheet is dismissed by swipe, also zoom back
    onZoomBack();
  });
}
