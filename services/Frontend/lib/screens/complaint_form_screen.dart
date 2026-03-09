import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

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

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _aiProcessing = false;
  
  File? _selectedImage;
  bool _imageProcessing = false;
  bool _isGpsLocation = false;

  @override
  void initState() {
    super.initState();
    // Default to a fallback if everything fails
    if (widget.initialCenter != null) {
      _latitude = widget.initialCenter!.latitude;
      _longitude = widget.initialCenter!.longitude;
    }
    
    // Immediately ask and await real GPS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchGPSLocation();
    });
  }

  Future<void> _fetchGPSLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
            _isGpsLocation = true;
        });
        _fetchAddressFromCoordinates();
      }
    } catch (e) {
      debugPrint('GPS error: $e');
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

  Future<void> _listen() async {
    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужно разрешение на микрофон')),
        );
        return;
      }
      
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
            _processVoiceWithAI(_descriptionController.text);
          }
        },
        onError: (val) => debugPrint('onError: $val'),
      );
      
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _descriptionController.text = val.recognizedWords;
          }),
          localeId: 'ru_RU',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _processVoiceWithAI(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _aiProcessing = true);
    try {
      final r = await http.post(
        Uri.parse('http://192.168.0.190:8001/ai/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 10));
      
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() {
          if (data['summary'] != null && _titleController.text.isEmpty) {
            _titleController.text = data['summary'];
          }
          if (data['category'] != null && _categories.contains(data['category'])) {
            _category = data['category'];
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI классифицировал текст как "${_category}"')),
          );
        }
      }
    } catch (e) {
      debugPrint('AI process voice error: $e');
    }
    if (mounted) setState(() => _aiProcessing = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 70);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        _processImageWithAI(await pickedFile.readAsBytes());
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  Future<void> _processImageWithAI(List<int> bytes) async {
    setState(() => _imageProcessing = true);
    try {
      final base64Image = base64Encode(bytes);
      final r = await http.post(
        Uri.parse('http://192.168.0.190:8001/ai/analyze_image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
           'image': base64Image,
           'text': _descriptionController.text.trim()
        }),
      ).timeout(const Duration(seconds: 25));
      
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() {
          if (data['summary'] != null && data['summary'].toString().isNotEmpty) {
             if (_descriptionController.text.isEmpty) {
                _descriptionController.text = data['summary'];
             } else {
                _descriptionController.text += '\n' + data['summary'];
             }
          }
          if (data['category'] != null && _categories.contains(data['category'])) {
            _category = data['category'];
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI описал фото и выбрал категорию "${_category}"')),
          );
        }
      }
    } catch (e) {
      debugPrint('AI process image error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось авто-проанализировать фото')),
        );
      }
    }
    if (mounted) setState(() => _imageProcessing = false);
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
        'lat': _latitude,
        'lng': _longitude,
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'category': _category,
        'status': 'open',
      };
      
      const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc';
      
      final r = await http
          .post(
            Uri.parse('https://xpainxohbdoruakcijyq.supabase.co/rest/v1/reports'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': supabaseKey,
              'Authorization': 'Bearer $supabaseKey',
              'Prefer': 'return=minimal'
            },
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
            const SizedBox(height: 12.0),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Описание проблемы *',
                hintText: 'Опишите подробнее, что произошло',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _card,
                alignLabelWithHint: true,
                suffixIcon: IconButton(
                  color: _isListening ? Colors.redAccent : _primary,
                  icon: _aiProcessing
                      ? const SizedBox(width: 16.0, height: 16.0, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_isListening ? Icons.mic : Icons.mic_none),
                  tooltip: 'Диктовать голосом',
                  onPressed: _aiProcessing ? null : _listen,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Введите описание';
                return null;
              },
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _imageProcessing ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, color: Colors.white70),
                    label: const Text('Сделать фото', style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _primary.withAlpha(100)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _imageProcessing ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, color: Colors.white70),
                    label: const Text('Галерея', style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _primary.withAlpha(100)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_imageProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('AI анализирует фото...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  )
                ),
              ),
            if (_selectedImage != null && !_imageProcessing)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Stack(
                  children: [
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primary.withAlpha(50)),
                        image: DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        icon: const Icon(Icons.close, size: 18),
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        onPressed: () => setState(() => _selectedImage = null),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12.0),
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
            const SizedBox(height: 16.0),
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
                const SizedBox(width: 8.0),
                if (_latitude != null && _longitude != null)
                  IconButton.filled(
                    onPressed: _loadingAddress ? null : _fetchAddressFromCoordinates,
                    icon: _loadingAddress
                        ? const SizedBox(
                            width: 22.0,
                            height: 22.0,
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
                  _isGpsLocation 
                    ? 'Точные GPS координаты: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                    : 'Координаты: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)} (взяты с карты)',
                  style: TextStyle(
                    color: _isGpsLocation ? Colors.greenAccent : Colors.white54, 
                    fontSize: 12,
                    fontWeight: _isGpsLocation ? FontWeight.bold : FontWeight.normal
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
            if (_submitError != null) ...[
              const SizedBox(height: 12.0),
              Text(_submitError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 24.0,),
            FilledButton.icon(
              onPressed: _sending ? null : () {
                HapticFeedback.mediumImpact();
                _submit();
              },
              icon: _sending
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
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
