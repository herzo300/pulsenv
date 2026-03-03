import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Форма подачи жалобы с определением адреса.
/// Координаты можно взять с карты; адрес — ввод вручную или через обратное геокодирование (Nominatim).
class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({
    super.key,
    this.initialCenter,
  });

  /// Центр карты на момент открытия формы — подставляется в координаты и можно получить адрес.
  final LatLng? initialCenter;

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  static const Color _bg = Color(0xFF0F0F23);
  static const Color _card = Color(0xFF1A1A2E);
  static const Color _primary = Color(0xFF2196F3);

  static const List<String> _categories = [
    'Дороги',
    'ЖКХ',
    'Освещение',
    'Транспорт',
    'Экология',
    'Безопасность',
    'Снег/Наледь',
    'Медицина',
    'Образование',
    'Парковки',
    'Прочее',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  String _category = 'Прочее';
  double? _latitude;
  double? _longitude;
  bool _loadingAddress = false;
  bool _sending = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    if (widget.initialCenter != null) {
      _latitude = widget.initialCenter!.latitude;
      _longitude = widget.initialCenter!.longitude;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Обратное геокодирование (Nominatim OSM). User-Agent обязателен.
  Future<void> _fetchAddressFromCoordinates() async {
    if (_latitude == null || _longitude == null) return;
    setState(() => _loadingAddress = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=$_latitude&lon=$_longitude&format=json',
      );
      final r = await http.get(
        url,
        headers: {'User-Agent': 'com.soobshio.app'},
      ).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          _addressController.text = displayName;
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось определить адрес: $e')),
        );
      }
    }
    if (mounted) setState(() => _loadingAddress = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      setState(() => _submitError = 'Укажите место на карте (откройте форму с карты) или введите адрес.');
      return;
    }
    setState(() {
      _sending = true;
      _submitError = null;
    });
    final desc = _descriptionController.text.trim();
    final title = _titleController.text.trim().isEmpty
        ? (desc.length > 200 ? desc.substring(0, 200) : desc)
        : _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _sending = false;
        _submitError = 'Введите описание проблемы.';
      });
      return;
    }
    try {
      final body = {
        'title': title.length > 200 ? title.substring(0, 200) : title,
        'description': _descriptionController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'category': _category,
        'status': 'open',
      };
      final r = await http
          .post(
            Uri.parse('http://127.0.0.1:8000/complaints'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Жалоба отправлена. Спасибо!')),
        );
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _submitError = 'Ошибка ${r.statusCode}. Проверьте, что API запущен.');
    } catch (e) {
      setState(() => _submitError = 'Нет связи с сервером. Запустите API (py main.py).');
      debugPrint('Submit complaint: $e');
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Сообщить о проблеме',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Краткое название',
                hintText: 'Например: Яма на дороге',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: _card,
              ),
              style: const TextStyle(color: Colors.white),
              maxLength: 200,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание проблемы *',
                hintText: 'Опишите подробнее, что произошло',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: _card,
                alignLabelWithHint: true,
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Введите описание';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Категория',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: _card,
              ),
              dropdownColor: _card,
              style: const TextStyle(color: Colors.white),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? 'Прочее'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Адрес',
                      hintText: 'Улица, дом или «Взять с карты»',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: _card,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                if (_latitude != null && _longitude != null)
                  IconButton.filled(
                    onPressed: _loadingAddress ? null : _fetchAddressFromCoordinates,
                    icon: _loadingAddress
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                          )
                        : const Icon(Icons.my_location),
                    tooltip: 'Определить адрес по координатам карты',
                  ),
              ],
            ),
            if (_latitude != null && _longitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Координаты: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)} (взяты с карты)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
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
            if (_submitError != null) ...[
              const SizedBox(height: 12),
              Text(_submitError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Отправка...' : 'Отправить жалобу'),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
