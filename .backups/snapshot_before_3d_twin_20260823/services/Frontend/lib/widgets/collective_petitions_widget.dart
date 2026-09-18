import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../map/map_config.dart';
import '../services/petition_service.dart';
import 'app_ui.dart';

class CollectivePetitionsWidget extends StatefulWidget {
  final String? addressFilter;

  const CollectivePetitionsWidget({super.key, this.addressFilter});

  @override
  State<CollectivePetitionsWidget> createState() => _CollectivePetitionsWidgetState();
}

class _CollectivePetitionsWidgetState extends State<CollectivePetitionsWidget> {
  final TextEditingController _nameController = TextEditingController(text: 'Житель Нижневартовска');
  final TextEditingController _flatController = TextEditingController(text: 'кв. 42');

  @override
  void initState() {
    super.initState();
    PetitionService.instance.fetchPetitions(address: widget.addressFilter);
  }

  void _showSignDialog(BuildContext context, CollectivePetitionItem petition) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFEAB308), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.draw_rounded, color: Color(0xFFEAB308), size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ЦИФРОВАЯ ПОДПИСЬ ПОД ИСКОМ',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Подписывая данный коллективный иск, вы присоединяетесь к официальному обращению в ${petition.targetAuthority}.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'ФИО Подписанта',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _flatController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Номер квартиры / Дом',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ОТМЕНА', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEAB308),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                HapticFeedback.heavyImpact();
                final name = _nameController.text.trim();
                final flat = _flatController.text.trim();
                if (name.isNotEmpty) {
                  final ok = await PetitionService.instance.signPetition(
                    petition.id,
                    userName: name,
                    flatNumber: flat,
                  );
                  if (ok && mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Ваша цифровая подпись успешно добавлена к коллективному иску!'),
                        backgroundColor: Color(0xFF22C55E),
                      ),
                    );
                  }
                }
              },
              child: const Text('ПОДПИСАТЬ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PetitionService.instance,
      builder: (context, _) {
        final items = PetitionService.instance.petitions;
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEAB308).withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEAB308).withOpacity(0.2),
                blurRadius: 16,
                spreadRadius: 1,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAB308).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gavel_rounded, color: Color(0xFFEAB308), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ИИ-КОНСТРУКТОР КОЛЛЕКТИВНЫХ ИСКОВ',
                          style: TextStyle(
                            color: Color(0xFFEAB308),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Петиции в Прокуратуру & ГЖИ ХМАО',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...items.map((item) {
                final progress = (item.signaturesCount / item.requiredSignatures).clamp(0.0, 1.0);
                final pdfUrl = '${MapConfig.backendApiBaseUrl}/api/v1/petitions/${item.id}/pdf';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAB308).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEAB308).withOpacity(0.4)),
                            ),
                            child: Text(
                              '${item.signaturesCount}/${item.requiredSignatures} подписей',
                              style: const TextStyle(color: Color(0xFFEAB308), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white12,
                          color: item.isReadyForSubmission ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTouchBounce(
                              onTap: () => _showSignDialog(context, item),
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEAB308),
                                  side: const BorderSide(color: Color(0xFFEAB308)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: null, // Touch is handled by AppTouchBounce
                                icon: const Icon(Icons.edit_note_rounded, size: 18),
                                label: const Text('ПОДПИСАТЬ ИСК', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppTouchBounce(
                            onTap: () {
                              launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);
                            },
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0EA5E9),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: null,
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                              label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
