// lib/screens/lost_and_found/widgets/photo_picker_field.dart
//
// Переиспользуемое поле выбора фото для форм.
// Кнопки «Камера» / «Галерея», превью выбранного фото, удаление.
//
// Использует PhotoService (единый пайплайн сжатия/загрузки).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/photo_service.dart';
import '../../../theme/pulse_colors.dart';
import '../../../theme/pulse_typography.dart';

/// Поле выбора фото. Вызывает [onChanged] с выбранным File или null.
class PhotoPickerField extends StatefulWidget {
  const PhotoPickerField({
    super.key,
    required this.onChanged,
    this.initialFile,
    this.label = 'Фото',
    this.hint = 'Сделайте снимок или выберите из галереи',
    this.subpath = 'lostfound',
    this.uploadOnPick = true,
  });

  /// Колбэк изменения. Получает выбранный File (или null при удалении).
  /// Если [uploadOnPick] = true, дополнительно можно дождаться URL через
  /// PhotoService напрямую в вызывающем коде.
  final ValueChanged<File?> onChanged;

  /// Изначальное фото (для редактирования).
  final File? initialFile;

  final String label;
  final String hint;

  /// Подпапка в storage bucket ('lostfound' для бюро находок).
  final String subpath;

  /// Загружать ли фото в storage сразу при выборе.
  /// Если false — только пикер, загрузку делает вызывающий код.
  final bool uploadOnPick;

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  File? _file;
  bool _loading = false;
  String? _uploadedUrl;

  @override
  void initState() {
    super.initState();
    _file = widget.initialFile;
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _loading = true);
    try {
      final file = await PhotoService.instance.pickImage(source);
      if (file == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      _file = file;
      widget.onChanged(file);

      // Опциональная загрузка сразу при выборе.
      if (widget.uploadOnPick) {
        try {
          final url = await PhotoService.instance.uploadToStorage(
            file,
            subpath: widget.subpath,
          );
          _uploadedUrl = url;
        } catch (e) {
          debugPrint('[PhotoPickerField] upload failed (offline ok): $e');
          _uploadedUrl = PhotoService.toLocalPath(file);
        }
      }
    } catch (e) {
      debugPrint('[PhotoPickerField] pick failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось получить фото: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _remove() {
    setState(() {
      _file = null;
      _uploadedUrl = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: PulseTypography.labelLarge),
        const SizedBox(height: 8),
        if (_file != null)
          _PreviewBlock(
            file: _file!,
            loading: _loading,
            uploaded: _uploadedUrl != null,
            onRemove: _remove,
          )
        else
          _PickerButtons(
            loading: _loading,
            onCamera: () => _pick(ImageSource.camera),
            onGallery: () => _pick(ImageSource.gallery),
            hint: widget.hint,
          ),
      ],
    );
  }

  /// Геттер загруженного URL (для вызывающего кода).
  String? get uploadedUrl => _uploadedUrl;
}

/// Блок превью выбранного фото.
class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({
    required this.file,
    required this.loading,
    required this.uploaded,
    required this.onRemove,
  });

  final File file;
  final bool loading;
  final bool uploaded;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.file(file, fit: BoxFit.cover),
          ),
          // Градиент снизу для читаемости статуса
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                ),
              ),
              child: Row(
                children: [
                  if (loading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      uploaded ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: uploaded ? Colors.greenAccent : Colors.orangeAccent,
                      size: 16,
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      loading ? 'Загрузка…' : (uploaded ? 'Загружено' : 'Локально (нет сети)'),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    onPressed: onRemove,
                    splashRadius: 18,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопки выбора источника фото (когда фото ещё не выбрано).
class _PickerButtons extends StatelessWidget {
  const _PickerButtons({
    required this.loading,
    required this.onCamera,
    required this.onGallery,
    required this.hint,
  });

  final bool loading;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PulseColors.backgroundRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PulseColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 36,
            color: PulseColors.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          Text(hint,
              textAlign: TextAlign.center,
              style: PulseTypography.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading ? null : onCamera,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Камера'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onGallery,
                  icon: const Icon(Icons.photo_rounded, size: 18),
                  label: const Text('Галерея'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
