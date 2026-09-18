import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../theme/pulse_colors.dart';
import '../../../../theme/pulse_categories.dart';
import '../../../../widgets/app_ui.dart';
import '../../../../widgets/voice_waveform.dart';

class ComplaintFormFields extends StatelessWidget {
  const ComplaintFormFields({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.addressController,
    required this.category,
    required this.categories,
    required this.defaultCategory,
    required this.isListening,
    required this.aiProcessing,
    required this.loadingAddress,
    required this.latitude,
    required this.longitude,
    required this.isGpsLocation,
    required this.onCategoryChanged,
    required this.onAddressRefresh,
    required this.onGpsRefresh,
    required this.onVoiceToggle,
    required this.onShowOnMap,
    required this.crossPostToSocials,
    required this.onCrossPostChanged,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController addressController;
  final String category;
  final List<String> categories;
  final String defaultCategory;
  final bool isListening;
  final bool aiProcessing;
  final bool loadingAddress;
  final double? latitude;
  final double? longitude;
  final bool isGpsLocation;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onAddressRefresh;
  final VoidCallback onGpsRefresh;
  final VoidCallback onVoiceToggle;
  final VoidCallback onShowOnMap;
  final bool crossPostToSocials;
  final ValueChanged<bool> onCrossPostChanged;

  IconData _getCategoryIcon(String cat) {
    return PulseCategories.iconFor(cat);
  }

  Color _getCategoryColor(String cat) {
    return PulseCategories.colorFor(cat);
  }

  InputDecoration _buildInputDecoration(BuildContext context, {required String label, required String hint, Widget? suffixIcon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
      hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 13),
      filled: true,
      fillColor: PulseColors.surfaceGlass,
      alignLabelWithHint: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: isDark ? const Color(0xFF00E5FF) : Colors.blue, width: 1.5),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: titleController,
          decoration: _buildInputDecoration(context,
            label: 'Заголовок',
            hint: 'Можно не заполнять, AI подставит сам',
          ),
          style: AppTextStyles.body,
          maxLength: 200,
        ),
        const SizedBox(height: 16.0),
        TextFormField(
          controller: descriptionController,
          decoration: _buildInputDecoration(context,
            label: 'Что случилось',
            hint: 'Например: Тут яма, автобус не пришел, во дворе темно',
            suffixIcon: IconButton(
              color: isListening ? Colors.redAccent : Colors.white70,
              icon: aiProcessing
                  ? const SizedBox(
                      width: 16.0,
                      height: 16.0,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : (isListening
                      ? const VoiceWaveform(color: Colors.redAccent)
                      : const Icon(Icons.mic_none)),
              tooltip: 'Диктовать голосом',
              onPressed: aiProcessing ? null : onVoiceToggle,
            ),
          ),
          style: AppTextStyles.body,
          maxLines: 4,
        ),
        const SizedBox(height: 20.0),
        
        // Premium Horizontal Category Selector (Lenta)
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Text(
            'Выберите категорию',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87,
            ),
          ),
        ),
        SizedBox(
          height: 94,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, idx) {
              final cat = categories[idx];
              final isSel = cat == category;
              final color = _getCategoryColor(cat);
              final icon = _getCategoryIcon(cat);
              return GestureDetector(
                onTap: () => onCategoryChanged(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 94,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isSel
                        ? color.withOpacity(0.18)
                        : PulseColors.surfaceGlass,
                    border: Border.all(
                      color: isSel ? color : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08)),
                      width: isSel ? 2.0 : 1.0,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.35),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: isSel ? color : (isDark ? Colors.white60 : Colors.black45), size: 28),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          cat,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20.0),
        
        _buildAddressRow(context),
        if (latitude != null && longitude != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              isGpsLocation
                  ? 'Точные GPS координаты: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
                  : 'Координаты: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)} (взяты с карты)',
              style: TextStyle(
                color: isGpsLocation ? (isDark ? Colors.greenAccent : Colors.green[700]) : (isDark ? Colors.white54 : Colors.black54),
                fontSize: 12,
                fontWeight: isGpsLocation ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Определяем GPS или откройте форму с карты, чтобы указать место.',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
            ),
          ),
        const SizedBox(height: 20.0),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
            ),
          ),
          child: SwitchListTile.adaptive(
            secondary: Icon(
              Icons.send_rounded,
              color: crossPostToSocials ? PulseColors.primary : (isDark ? Colors.white54 : Colors.black54),
            ),
            title: Text(
              'Дублировать в соцсети',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'Автоматическая публикация обращения в городские группы VK и Telegram-каналы Нижневартовска',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            value: crossPostToSocials,
            activeColor: PulseColors.primary,
            onChanged: onCrossPostChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: addressController,
            decoration: _buildInputDecoration(context,
              label: 'Адрес',
              hint: 'Улица, дом или «Взять с карты»',
            ),
            style: AppTextStyles.body,
          ),
        ),
        const SizedBox(width: 8.0),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF7C4DFF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: loadingAddress ? null : onGpsRefresh,
          icon: loadingAddress
              ? const SizedBox(
                  width: 22.0,
                  height: 22.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                )
              : const Icon(Icons.gps_fixed),
          tooltip: 'Определить местоположение по GPS',
        ),
        if (latitude != null && longitude != null) ...[
          const SizedBox(width: 8.0),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onShowOnMap,
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Показать на карте',
          ),
        ],
      ],
    );
  }
}
