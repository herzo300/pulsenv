// lib/screens/lost_and_found/widgets/add_finding_sheet.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../map/map_config.dart';

import '../../../services/photo_service.dart';
import '../../../services/geocoding_service.dart';
import '../../../services/device_location_service.dart';
import '../../../widgets/voice_waveform.dart';
import '../../../theme/pulse_colors.dart';
import '../../../theme/pulse_typography.dart';
import '../../../utils/pulse_haptics.dart';
import 'photo_picker_field.dart';
import '../../map/widgets/map_glass_panel.dart';
import '../../../widgets/aura_living_background.dart';
import '../../../core/living/aura_living_engine.dart';

/// Категории находок.
enum FindingCategory {
  foundAnimal('Найдено животное', Icons.pets_rounded),
  foundItem('Найдена вещь', Icons.inventory_2_rounded),
  lostAnimal('Потеряно животное', Icons.search_rounded),
  lostItem('Потеряна вещь', Icons.search_rounded);

  final String label;
  final IconData icon;
  const FindingCategory(this.label, this.icon);
}

/// Контроллер формы добавления находки.
class AddFindingSheet extends StatefulWidget {
  const AddFindingSheet({super.key, this.initialCity});

  /// Город по умолчанию (для адреса).
  final String? initialCity;

  /// Показать форму как modal bottom sheet. Возвращает true если сохранено.
  static Future<bool?> show(BuildContext context, {String? initialCity}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: AddFindingSheet(initialCity: initialCity),
      ),
    );
  }

  @override
  State<AddFindingSheet> createState() => _AddFindingSheetState();
}

class _AddFindingSheetState extends State<AddFindingSheet> {
  FindingCategory _category = FindingCategory.foundAnimal;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  File? _photoFile;
  String? _photoUrl;
  bool _saving = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _resolvingAddress = false;

  Future<void> _listen() async {
    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нужно разрешение на микрофон')));
        return;
      }
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) => debugPrint('STT error: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
            onResult: (val) => setState(() {
                  _descCtrl.text = val.recognizedWords;
                }),
            localeId: 'ru_RU');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _resolveGPSAddress() async {
    setState(() => _resolvingAddress = true);
    PulseHaptics.tap();
    try {
      final loc = await DeviceLocationService.instance.resolve();
      if (loc.isSuccess && loc.position != null) {
        final addr = await GeocodingService.instance.shortAddress(
          loc.position!.latitude,
          loc.position!.longitude,
        );
        if (addr.isNotEmpty) {
          setState(() {
            _addressCtrl.text = addr;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Адрес определен: $addr')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Не удалось определить адрес по координатам')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось получить координаты GPS')),
          );
        }
      }
    } catch (e) {
      debugPrint('Address resolution failed: $e');
    } finally {
      if (mounted) {
        setState(() => _resolvingAddress = false);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните заголовок и описание')),
      );
      return;
    }
    setState(() => _saving = true);
    PulseHaptics.confirm();

    String? imageUrl = _photoUrl;
    if (_photoFile != null && imageUrl == null) {
      try {
        imageUrl = await PhotoService.instance.uploadToStorage(
          _photoFile!,
          subpath: 'lostfound',
        );
      } catch (e) {
        debugPrint('[AddFinding] Storage upload exception: $e');
        imageUrl = PhotoService.toLocalPath(_photoFile!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Фото будет загружено позже при улучшении связи')),
          );
        }
      }
    }

    final targetAddress = _addressCtrl.text.trim().isEmpty
        ? (widget.initialCity ?? 'Нижневартовск')
        : _addressCtrl.text.trim();

    double lat = 60.9385;
    double lng = 76.5594;
    try {
      final loc = await GeocodingService.instance.forwardGeocode(targetAddress);
      if (loc != null) {
        lat = loc.lat;
        lng = loc.lng;
      }
    } catch (_) {}

    final saved = await _saveLocally(
      category: _category.label,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      address: targetAddress,
      imageUrl: imageUrl,
      lat: lat,
      lng: lng,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      PulseHaptics.success();
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить. Попробуйте снова.')),
      );
    }
  }

  Future<bool> _saveLocally({
    required String category,
    required String title,
    required String description,
    required String address,
    String? imageUrl,
    double lat = 60.9385,
    double lng = 76.5594,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('my_lost_and_found_items') ?? '[]';
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;

      final int seed = ((DateTime.now().microsecondsSinceEpoch + title.hashCode).abs()) % 10 + 240;
      final String finalImg = (imageUrl != null && imageUrl.isNotEmpty)
          ? imageUrl
          : 'https://image.pollinations.ai/prompt/${Uri.encodeComponent('lost and found $category $title, city street, photo realistic')}?width=600&height=400&seed=$seed&nologo=true';

      final newItem = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch,
        'title': title,
        'description': description,
        'category': category,
        'address': address,
        'lat': lat,
        'lng': lng,
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
        'image': finalImg,
        'images': [finalImg],
      };

      list.insert(0, newItem);
      await prefs.setString('my_lost_and_found_items', jsonEncode(list));

      final myReported = prefs.getStringList('my_reported_ids') ?? [];
      myReported.add(newItem['id'].toString());
      await prefs.setStringList('my_reported_ids', myReported);

      // Sync to Backend API (/api/reports) so Map Screen markers are updated immediately
      try {
        final backendUrl = Uri.parse('${MapConfig.backendApiBaseUrl}/reports');
        await http.post(
          backendUrl,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'title': title,
            'description': '$description\n\nФото: $finalImg',
            'category': category,
            'address': address,
            'lat': lat,
            'lng': lng,
            'status': 'open',
            'images': [finalImg],
          }),
        ).timeout(const Duration(seconds: 5));
      } catch (backendErr) {
        debugPrint('[AddFinding] backend API sync error: $backendErr');
      }

      return true;
    } catch (e) {
      debugPrint('[AddFinding] save failed: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final isAnimal = _category == FindingCategory.lostAnimal || _category == FindingCategory.foundAnimal;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      // Единый стиль бюро находок (как у карточек деталей): тёмный 0F172A,
      // cyan-кантик сверху, радиус 28 — форма выглядит частью бюро.
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF00E5FF), width: 1.5)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Stack(
          children: [
            // Background
            Positioned.fill(
              child: isAnimal
                  ? AuraLivingBackground(
                      scene: AuraLivingEngine.resolve(
                        mood: 5,
                        streak: 3,
                        meditationMinutes: 5,
                        practicesCompleted: 2,
                        isPremium: true,
                        hour: DateTime.now().hour,
                      ),
                      interactive: true,
                      showConstellationVeil: false,
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF0F172A),
                    ),
            ),
            
            // Content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Grab handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isLightTheme ? Colors.black26 : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    
                    // Header title
                    Row(
                      children: [
                        Icon(
                          isAnimal ? Icons.pets_rounded : Icons.inventory_2_rounded,
                          color: PulseColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAnimal ? 'Поиск пропавших питомцев' : 'Сообщить о находке/потере',
                          style: PulseTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isLightTheme ? Colors.black : Colors.white,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1, end: 0.0),
                    
                    const SizedBox(height: 16),
                    
                    // Detective pet animated card (only for animals)
                    if (isAnimal)
                      GestureDetector(
                        onTap: () {
                          PulseHaptics.confirm();
                        },
                        child: Container(
                          height: 110,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  'assets/3d_icons/animals_3d.webp',
                                  fit: BoxFit.cover,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.black.withOpacity(0.65),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Потерялся друг?',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Заполните форму, и искусственный интеллект\nпоможет найти его по камерам города!',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 10.5,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
                      ),
                    
                    // Category selector inside glass card
                    MapGlassPanel(
                      borderRadius: BorderRadius.circular(18),
                      padding: const EdgeInsets.all(12),
                      fillColor: isLightTheme ? Colors.white.withOpacity(0.65) : Colors.black.withOpacity(0.24),
                      blurSigma: 12,
                      borderColors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.01),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Выберите категорию:',
                            style: PulseTypography.labelMedium.copyWith(
                              color: isLightTheme ? Colors.black87 : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: FindingCategory.values.map((c) {
                              final selected = _category == c;
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(c.icon, size: 15,
                                        color: selected ? Colors.white : (isLightTheme ? Colors.black87 : Colors.white)),
                                    const SizedBox(width: 6),
                                    Text(c.label),
                                  ],
                                ),
                                selected: selected,
                                onSelected: (_) {
                                  PulseHaptics.tap();
                                  setState(() => _category = c);
                                },
                                selectedColor: PulseColors.primary,
                                labelStyle: TextStyle(
                                  color: selected ? Colors.white : (isLightTheme ? Colors.black87 : Colors.white),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                                backgroundColor: isLightTheme ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.06),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: selected
                                        ? PulseColors.primary
                                        : Colors.transparent,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0.0),
                    
                    const SizedBox(height: 12),
                    
                    // Main input fields in a unified glass list
                    MapGlassPanel(
                      borderRadius: BorderRadius.circular(18),
                      padding: const EdgeInsets.all(16),
                      fillColor: isLightTheme ? Colors.white.withOpacity(0.65) : Colors.black.withOpacity(0.24),
                      blurSigma: 12,
                      borderColors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.01),
                      ],
                      child: Column(
                        children: [
                          // Title input with icon prefix
                          TextField(
                            controller: _titleCtrl,
                            style: TextStyle(color: isLightTheme ? Colors.black : Colors.white),
                            decoration: _inputDec(
                              'Краткое название',
                              'Например, «Пропала хаски Герда»',
                              prefixIcon: Icon(Icons.title_rounded, color: PulseColors.primary, size: 18),
                              isLightTheme: isLightTheme,
                            ),
                            maxLength: 80,
                          ),
                          const SizedBox(height: 12),
                          
                          // Description input with mic suffix
                          TextField(
                            controller: _descCtrl,
                            style: TextStyle(color: isLightTheme ? Colors.black : Colors.white),
                            decoration: _inputDec(
                              'Описание / Приметы',
                              'Окрас, кличка, ошейник, особые приметы, контакты…',
                              prefixIcon: Icon(Icons.description_rounded, color: PulseColors.primary, size: 18),
                              isLightTheme: isLightTheme,
                            ).copyWith(
                              suffixIcon: IconButton(
                                color: _isListening ? Colors.redAccent : (isLightTheme ? Colors.black54 : Colors.white54),
                                icon: _isListening 
                                    ? VoiceWaveform(color: Colors.redAccent) 
                                    : const Icon(Icons.mic_none_rounded),
                                onPressed: _listen,
                                tooltip: 'Диктовать голосом',
                              ),
                            ),
                            maxLines: 3,
                            maxLength: 500,
                          ),
                          const SizedBox(height: 12),
                          
                          // Address with locator button
                          TextField(
                            controller: _addressCtrl,
                            style: TextStyle(color: isLightTheme ? Colors.black : Colors.white),
                            decoration: _inputDec(
                              'Адрес / Где потеряли',
                              'Например, микрорайон 14, сквер Строителей',
                              prefixIcon: Icon(Icons.location_on_rounded, color: PulseColors.primary, size: 18),
                              isLightTheme: isLightTheme,
                            ).copyWith(
                              suffixIcon: _resolvingAddress
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : IconButton(
                                      icon: Icon(Icons.my_location_rounded, color: PulseColors.primary),
                                      onPressed: _resolveGPSAddress,
                                      tooltip: 'Определить по GPS',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0.0),
                    
                    const SizedBox(height: 12),
                    
                    // Photo input inside card
                    MapGlassPanel(
                      borderRadius: BorderRadius.circular(18),
                      padding: const EdgeInsets.all(12),
                      fillColor: isLightTheme ? Colors.white.withOpacity(0.65) : Colors.black.withOpacity(0.24),
                      blurSigma: 12,
                      borderColors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.01),
                      ],
                      child: PhotoPickerField(
                        label: 'Фотография питомца',
                        hint: 'Сфотографируйте или выберите из галереи',
                        subpath: 'lostfound',
                        onChanged: (file, url) {
                          setState(() {
                            _photoFile = file;
                            if (url != null) _photoUrl = url;
                            if (file == null) _photoUrl = null;
                          });
                        },
                      ),
                    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0.0),
                    
                    const SizedBox(height: 20),
                    
                    // Submit button
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: PulseColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: PulseColors.primary.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(isAnimal ? Icons.search_rounded : Icons.publish_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  isAnimal ? 'Запустить поиск друга' : 'Опубликовать объявление',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: -0.1),
                                ),
                              ],
                            ),
                    ).animate().fadeIn(delay: 450.ms).scale(duration: 250.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, String hint, {Widget? prefixIcon, required bool isLightTheme}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        labelStyle: TextStyle(
          color: isLightTheme ? Colors.black54 : Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: isLightTheme ? Colors.black38 : Colors.white30,
          fontSize: 11.5,
        ),
        filled: true,
        fillColor: isLightTheme ? Colors.black.withOpacity(0.04) : Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: PulseColors.primary, width: 1.5),
        ),
      );
}
