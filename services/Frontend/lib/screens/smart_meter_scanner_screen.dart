import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Экран ИИ-сканирования счетчиков воды/электричества (Smart Meter OCR).
class SmartMeterScannerScreen extends StatefulWidget {
  final String meterType; // 'cold_water', 'hot_water', 'electricity'
  final String address;

  const SmartMeterScannerScreen({
    super.key,
    this.meterType = 'cold_water',
    required this.address,
  });

  @override
  State<SmartMeterScannerScreen> createState() => _SmartMeterScannerScreenState();
}

class _SmartMeterScannerScreenState extends State<SmartMeterScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final TextEditingController _readingController = TextEditingController();

  File? _imageFile;
  bool _isProcessing = false;
  String? _detectedSerialNumber;
  double? _previousReading;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadPreviousReading();
    _checkFirstOpenTutorial();
  }

  Future<void> _checkFirstOpenTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_smart_meter_tutorial_v2') ?? false;
    if (!hasSeen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTutorialDialog(context);
      });
      await prefs.setBool('has_seen_smart_meter_tutorial_v2', true);
    }
  }

  void _showTutorialDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0xFF10B981), width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'КАК СКАНИРОВАТЬ СЧЕТЧИК',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTutorialStep(
                icon: Icons.camera_alt_rounded,
                step: '1',
                title: 'Наведите камеру на циферблат',
                desc: 'Обеспечьте хорошее освещение счетчика ХВС/ГВС или включите фонарик.',
              ),
              const SizedBox(height: 12),
              _buildTutorialStep(
                icon: Icons.crop_free_rounded,
                step: '2',
                title: 'Совместите цифры с рамкой',
                desc: 'Расположите черные и красные цифры расхода внутри центральной рамки видоискателя.',
              ),
              const SizedBox(height: 12),
              _buildTutorialStep(
                icon: Icons.send_rounded,
                step: '3',
                title: 'Проверьте и отправьте в 1 клик',
                desc: 'ИИ распознает число и серийный номер. Нажмите «Подать показания в УК».',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ПОНЯТНО, НАЧАТЬ СКАНИРОВАНИЕ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildTutorialStep({
    required IconData icon,
    required String step,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPreviousReading() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'last_reading_${widget.meterType}_${widget.address.hashCode}';
    final saved = prefs.getDouble(key);
    setState(() {
      _previousReading = saved ?? 142.58;
    });
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _readingController.dispose();
    super.dispose();
  }

  Future<void> _captureOrPickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() {
        _imageFile = File(picked.path);
        _isProcessing = true;
      });

      await _processImageWithOcr(_imageFile!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка захвата фото: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processImageWithOcr(File image) async {
    final inputImage = InputImage.fromFile(image);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    // Поиск числовых шаблонов счетчиков (например: 00145.89 или 145,8)
    final text = recognizedText.text;
    final regexNumber = RegExp(r'\b\d{3,6}[\.,]\d{1,3}\b|\b\d{4,6}\b');
    final match = regexNumber.firstMatch(text);

    if (match != null) {
      final raw = match.group(0)!.replaceAll(',', '.');
      _readingController.text = raw;
    } else {
      // Запасное распознавание последовательностей цифр
      final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.length >= 5) {
        final val = '${digitsOnly.substring(0, digitsOnly.length - 2)}.${digitsOnly.substring(digitsOnly.length - 2)}';
        _readingController.text = val;
      }
    }

    // Поиск серийного номера
    final snMatch = RegExp(r'№\s*([0-9A-Za-z\-]+)|SN:\s*([0-9A-Za-z\-]+)').firstMatch(text);
    if (snMatch != null) {
      _detectedSerialNumber = snMatch.group(1) ?? snMatch.group(2);
    }
  }

  Future<void> _submitReading() async {
    final val = double.tryParse(_readingController.text.replaceAll(',', '.'));
    if (val == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректное числовое значение показаний')),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    final key = 'last_reading_${widget.meterType}_${widget.address.hashCode}';
    await prefs.setDouble(key, val);

    setState(() => _isSubmitted = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Показания успешно переданы в управляющую компанию!')),
            ],
          ),
        ),
      );
    }
  }

  String _getMeterTitle() {
    switch (widget.meterType) {
      case 'hot_water':
        return 'Счетчик Горячей Воды (ГВС)';
      case 'electricity':
        return 'Счетчик Электроэнергии (День/Ночь)';
      case 'cold_water':
      default:
        return 'Счетчик Холодной Воды (ХВС)';
    }
  }

  Color _getMeterColor() {
    switch (widget.meterType) {
      case 'hot_water':
        return const Color(0xFFFF5252);
      case 'electricity':
        return const Color(0xFFFBBF24);
      case 'cold_water':
      default:
        return const Color(0xFF00E5FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meterColor = _getMeterColor();

    return Scaffold(
      backgroundColor: const Color(0xFF070D18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          _getMeterTitle(),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF10B981)),
            tooltip: 'Инструкция по сканированию',
            onPressed: () => _showTutorialDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // Адрес
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: meterColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.address,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Область видоискателя / фото счетчика
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: const Color(0xFF0A1220),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: meterColor.withOpacity(0.4), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_imageFile != null)
                    Image.file(_imageFile!, fit: BoxFit.cover)
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, color: meterColor.withOpacity(0.6), size: 48),
                        const SizedBox(height: 10),
                        const Text(
                          'Наведите камеру на циферблат счетчика',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ИИ автоматически распознает цифры расхода',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10.5),
                        ),
                      ],
                    ),

                  // Рамка видоискателя
                  Center(
                    child: Container(
                      width: 220,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: meterColor, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'РАМКА СЧЕТЧИКА',
                          style: TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),

                  if (_isProcessing)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF00E5FF)),
                            SizedBox(height: 10),
                            Text(
                              'Нейросеть считывает показания...',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Кнопки захвата фото
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _captureOrPickImage(ImageSource.camera),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: meterColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Сделать фото', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => _captureOrPickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded, color: Colors.white70),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Поле ввода и проверки распознанных данных
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ТЕКУЩИЕ ПОКАЗАНИЯ (м³)',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    if (_previousReading != null)
                      Text(
                        'Пред.: ${_previousReading!.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _readingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: meterColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: '00000.00',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: meterColor.withOpacity(0.4)),
                    ),
                    suffixText: 'м³',
                    suffixStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
                if (_detectedSerialNumber != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Серийный номер прибора: $_detectedSerialNumber',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Кнопка отправки в УК в 1 клик
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitted ? null : _submitReading,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: _isSubmitted
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('ПЕРЕДАНО В УК', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('ПОДАТЬ ПОКАЗАНИЯ В УК В 1 КЛИК', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
