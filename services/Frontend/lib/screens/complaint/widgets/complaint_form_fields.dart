import 'package:flutter/material.dart';

import '../../../theme/pulse_colors.dart';
import '../../../widgets/app_ui.dart';

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
    required this.onVoiceToggle,
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
  final VoidCallback onVoiceToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Заголовок',
            hintText: 'Можно не заполнять, AI подставит сам',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: PulseColors.surface,
          ),
          style: AppTextStyles.body,
          maxLength: 200,
        ),
        const SizedBox(height: 12.0),
        TextFormField(
          controller: descriptionController,
          decoration: InputDecoration(
            labelText: 'Что случилось',
            hintText: 'Например: Тут яма, автобус не пришел, во дворе темно',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: PulseColors.surface,
            alignLabelWithHint: true,
            suffixIcon: IconButton(
              color: isListening ? Colors.redAccent : Colors.white70,
              icon: aiProcessing
                  ? const SizedBox(
                      width: 16.0,
                      height: 16.0,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isListening ? Icons.mic : Icons.mic_none),
              tooltip: 'Диктовать голосом',
              onPressed: aiProcessing ? null : onVoiceToggle,
            ),
          ),
          style: AppTextStyles.body,
          maxLines: 4,
        ),
        const SizedBox(height: 16.0),
        DropdownButtonFormField<String>(
          value: category,
          decoration: const InputDecoration(
            labelText: 'Категория',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: PulseColors.surface,
          ),
          dropdownColor: PulseColors.surface,
          style: AppTextStyles.body,
          items: categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: onCategoryChanged,
        ),
        const SizedBox(height: 16.0),
        _buildAddressRow(),
        if (latitude != null && longitude != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              isGpsLocation
                  ? 'Точные GPS координаты: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
                  : 'Координаты: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)} (взяты с карты)',
              style: TextStyle(
                color: isGpsLocation ? Colors.greenAccent : Colors.white54,
                fontSize: 12,
                fontWeight: isGpsLocation ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Откройте форму с карты, чтобы подставить координаты и адрес.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildAddressRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: 'Адрес',
              hintText: 'Улица, дом или «Взять с карты»',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: PulseColors.surface,
            ),
            style: AppTextStyles.body,
          ),
        ),
        const SizedBox(width: 8.0),
        if (latitude != null && longitude != null)
          IconButton.filled(
            onPressed: loadingAddress ? null : onAddressRefresh,
            icon: loadingAddress
                ? const SizedBox(
                    width: 22.0,
                    height: 22.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : const Icon(Icons.my_location),
            tooltip: 'Определить адрес по координатам карты',
          ),
      ],
    );
  }
}
