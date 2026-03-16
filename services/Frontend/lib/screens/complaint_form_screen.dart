
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../map/map_config.dart';
import '../services/backend_api_service.dart';
import '../services/object_detection_service.dart';
import '../services/draft_box_service.dart';
import '../widgets/ai_scan_preview.dart';
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
  static const String _defaultCategory =
      'Прочее';
  static const Set<String> _stopWords = {
    'со',
    'от',
    'во',
    'на',
    'по',
    'за',
    'из',
    'под',
    'над',
    'для',
    'это',
    'тут',
    'там',
    'или',
    'как',
    'что',
    'где',
    'меня',
    'такая',
    'такой',
    'проблема',
    'город',
    'нужно',
    'очень',
    'просто',
  };

  static const List<String> _categories = [
    'ЖКХ',
    'Дороги',
    'Благоустройство',
    'Транспорт',
    'Экология',
    'Животные',
    'Торговля',
    'Безопасность',
    'Снег/Наледь',
    'Освещение',
    'Медицина',
    'Образование',
    'Связь',
    'Строительство',
    'Парковки',
    'Социальная сфера',
    'Трудовое право',
    'ЧС и аварии',
    'Газоснабжение',
    'Водоснабжение и канализация',
    'Отопление',
    'Бытовой мусор',
    'Лифты и подъезды',
    'Парки и скверы',
    'Спортивные площадки',
    'Детские площадки',
    _defaultCategory,
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final BackendApiService _backendApi = BackendApiService.instance;

  final Distance _distance = const Distance();

  String _category = _defaultCategory;
  double? _latitude;
  double? _longitude;
  bool _loadingAddress = false;
  bool _sending = false;
  String? _submitError;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _aiProcessing = false;

  File? _selectedImage;
  Uint8List? _detectedPreviewBytes;
  List<DetectedSearchObject> _detectedObjects = const [];
  bool _objectDetectionReady = false;
  String? _searchPrompt;
  bool _imageProcessing = false;
  bool _upscalingImage = false;
  bool _isGpsLocation = false;
  bool _checkingSimilar = false;
  String? _smartSummary;
  int? _smartSeverity;
  Map<String, dynamic>? _similarReport;
  Timer? _similarSearchDebounce;
  bool _suspendDraftWatchers = false;
  String? _lastSimilarSignature;
  AiScanProgress _scanProgress = const AiScanProgress.idle();

  String get _searchCategory =>
      _categories.length > 1 ? _categories[_categories.length - 2] : _defaultCategory;

  bool get _isSearchCategory => _category == _searchCategory;

  @override
  void initState() {
    super.initState();
    _initializeObjectDetection();
    _titleController.addListener(_handleDraftChanged);
    _descriptionController.addListener(_handleDraftChanged);
    _addressController.addListener(_handleDraftChanged);
    // Default to a fallback if everything fails
    if (widget.initialCenter != null) {
      _latitude = widget.initialCenter!.latitude;
      _longitude = widget.initialCenter!.longitude;
    }

    // Immediately ask and await real GPS
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_latitude != null && _longitude != null) {
        await _fetchAddressFromCoordinates();
        if (_descriptionController.text.trim().isNotEmpty ||
            _selectedImage != null) {
          await _findSimilarReports(force: true);
        }
      }
      await _fetchGPSLocation();
    });
  }

  Future<void> _initializeObjectDetection() async {
    try {
      await ObjectDetectionService.instance.ensureInitialized();
      if (!mounted) return;
      setState(() => _objectDetectionReady = true);
    } catch (error) {
      debugPrint('Object detection init error: $error');
    }
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
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _isGpsLocation = true;
        });
        await _fetchAddressFromCoordinates();
      }
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  @override
  void dispose() {
    _similarSearchDebounce?.cancel();
    _titleController.removeListener(_handleDraftChanged);
    _descriptionController.removeListener(_handleDraftChanged);
    _addressController.removeListener(_handleDraftChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _updateScanProgress({
    required AiScanStage stage,
    required double value,
    String? title,
    String? subtitle,
    bool active = true,
  }) {
    if (!mounted) return;
    setState(() {
      _scanProgress = AiScanProgress(
        stage: stage,
        value: value,
        active: active,
        title: title,
        subtitle: subtitle,
      );
    });
  }

  Future<void> _settleScanProgress({
    required String title,
    required String subtitle,
  }) async {
    if (!mounted) return;
    setState(() {
      _scanProgress = AiScanProgress(
        stage: AiScanStage.complete,
        value: 1,
        active: true,
        title: title,
        subtitle: subtitle,
      );
    });
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() => _scanProgress = const AiScanProgress.idle());
  }

  /// Обратное геокодирование (Nominatim OSM). User-Agent обязателен.
  void _handleDraftChanged() {
    if (_suspendDraftWatchers || _aiProcessing || _sending) {
      return;
    }
    _scheduleSimilarReportsCheck();
  }

  String _buildSimilarSignature() {
    final lat = _latitude?.toStringAsFixed(5) ?? '';
    final lng = _longitude?.toStringAsFixed(5) ?? '';
    final title = _titleController.text.trim().toLowerCase();
    final description = _descriptionController.text.trim().toLowerCase();
    final address = _addressController.text.trim().toLowerCase();
    return '$lat|$lng|$_category|$title|$description|$address';
  }

  void _scheduleSimilarReportsCheck({
    Duration delay = const Duration(milliseconds: 650),
    bool force = false,
  }) {
    _similarSearchDebounce?.cancel();

    final hasDraftSignal = _titleController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _addressController.text.trim().isNotEmpty ||
        _smartSummary?.trim().isNotEmpty == true;

    if (_latitude == null || _longitude == null || !hasDraftSignal) {
      _lastSimilarSignature = null;
      if (mounted) {
        setState(() => _similarReport = null);
      } else {
        _similarReport = null;
      }
      return;
    }

    final signature = _buildSimilarSignature();
    if (!force && signature == _lastSimilarSignature) {
      return;
    }

    _similarSearchDebounce = Timer(delay, () {
      if (!mounted) return;
      _findSimilarReports(signatureOverride: signature, force: force);
    });
  }

  String _guessImageExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.heic')) return 'heic';
    return 'jpg';
  }

  String _guessImageMimeType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<String?> _uploadSelectedImageToStorage() async {
    final image = _selectedImage;
    if (image == null) return null;

    final extension = _guessImageExtension(image.path);
    final objectPath =
        'reports/${DateTime.now().toUtc().millisecondsSinceEpoch}_${math.Random().nextInt(1 << 32)}.$extension';
    final response = await http
        .post(
          Uri.parse(
            MapConfig.storageUploadUrl(
                MapConfig.reportsMediaBucket, objectPath),
          ),
          headers: {
            'Content-Type': _guessImageMimeType(extension),
            'apikey': MapConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${MapConfig.supabaseAnonKey}',
            'x-upsert': 'false',
          },
          body: await image.readAsBytes(),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Storage upload failed: HTTP ${response.statusCode} ${response.body}',
      );
    }

    return MapConfig.storagePublicUrl(MapConfig.reportsMediaBucket, objectPath);
  }

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
          _suspendDraftWatchers = true;
          _addressController.text = displayName;
          _suspendDraftWatchers = false;
          _scheduleSimilarReportsCheck(
              delay: const Duration(milliseconds: 250));
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Не удалось определить адрес: $e')),
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
          const SnackBar(
              content: Text(
                  'Нужно разрешение на микрофон')),
        );
        return;
      }

      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
            _runSmartPrefill();
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

  Future<http.Response> _postBackendJson(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    return _backendApi.postJson(path, body, timeout: timeout);
  }

  Future<void> _runSmartPrefill() async {
    if (_aiProcessing) return;

    final text = _descriptionController.text.trim();
    final hasImage = _selectedImage != null;
    if (text.isEmpty && _selectedImage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Добавьте фото или пару слов о проблеме')),
        );
      }
      return;
    }

    setState(() {
      _aiProcessing = true;
      _imageProcessing = hasImage;
    });
    if (hasImage) {
      _updateScanProgress(
        stage: AiScanStage.scanning,
        value: 0.12,
        title: 'Сканирование кадра',
        subtitle:
            'Готовим изображение и выделяем визуальные признаки.',
      );
    }

    try {
      String? encodedImage;
      if (_selectedImage != null) {
        _updateScanProgress(
          stage: AiScanStage.scanning,
          value: 0.32,
          title: 'Сканирование кадра',
          subtitle:
              'Нормализуем фото, подсвечиваем контуры и GPS-контекст.',
        );
        encodedImage = base64Encode(await _selectedImage!.readAsBytes());
      }

      if (hasImage) {
        _updateScanProgress(
          stage: AiScanStage.classification,
          value: 0.56,
          title: 'Классификация AI',
          subtitle:
              'Определяем категорию, адрес и краткое описание проблемы.',
        );
      }

      final response = await _postBackendJson(
        '/ai/sanitize_report',
        {
          'text': text,
          'image': encodedImage,
          'lat': _latitude,
          'lng': _longitude,
          'address': _addressController.text.trim(),
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final summary = (data['summary'] as String?)?.trim();
      final description = (data['description'] as String?)?.trim();
      final address = (data['address'] as String?)?.trim();
      final category = (data['category'] as String?)?.trim();
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      final severity = data['severity'];

      if (hasImage) {
        _updateScanProgress(
          stage: AiScanStage.classification,
          value: 0.74,
          title: 'Классификация AI',
          subtitle:
              'AI собрал черновик обращения и геопривязку.',
        );
      }

      if (!mounted) return;
      _suspendDraftWatchers = true;
      setState(() {
        if (summary != null && summary.isNotEmpty) {
          _smartSummary = summary;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = summary;
          }
        }
        if (description != null && description.isNotEmpty) {
          final currentDescription = _descriptionController.text.trim();
          if (currentDescription.isEmpty || currentDescription.length <= 12) {
            _descriptionController.text = description;
          }
        }
        if (category != null && _categories.contains(category)) {
          _category = category;
        }
        if (address != null && address.isNotEmpty) {
          _addressController.text = address;
        }
        if (lat != null && lng != null) {
          _latitude = lat;
          _longitude = lng;
        }
        if (severity is num) {
          _smartSeverity = severity.toInt();
        }
      });
      _suspendDraftWatchers = false;

      await _findSimilarReports(force: true, trackScanProgress: hasImage);

      if (hasImage) {
        final similarFound = _similarReport != null;
        await _settleScanProgress(
          title: similarFound
              ? 'Похожий сигнал найден'
              : 'Проверка завершена',
          subtitle: similarFound
              ? 'Рядом уже есть похожее обращение, можно поддержать его в один тап.'
              : 'Дубликаты рядом не найдены. Можно отправлять новое обращение.',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'AI заполнил черновик: $_category')),
        );
      }
    } catch (error) {
      debugPrint('Smart prefill error: $error');
      if (hasImage) {
        await _settleScanProgress(
          title: 'Сканирование прервано',
          subtitle:
              'AI не завершил анализ. Попробуйте другое фото или повторите позже.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Не удалось автоматически заполнить обращение')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _aiProcessing = false;
        _imageProcessing = false;
      });
    }
  }

  void _clearDetectionState() {
    _detectedPreviewBytes = null;
    _detectedObjects = const [];
    _searchPrompt = null;
  }

  String _buildSearchPrompt(List<DetectedSearchObject> objects) {
    final labels = objects
        .take(3)
        .map((item) => item.displayLabel)
        .where((label) => label.trim().isNotEmpty)
        .join(', ');
    if (labels.isEmpty) {
      return '\u041d\u0430 \u0444\u043e\u0442\u043e \u043d\u0435\u0442 \u044f\u0441\u043d\u044b\u0445 \u043e\u0431\u044a\u0435\u043a\u0442\u043e\u0432.';
    }
    return '\u041f\u043e\u0445\u043e\u0436\u0435 \u043d\u0430: $labels';
  }

  void _applyObjectDetection(ObjectDetectionResult result) {
    final topObjects = result.objects.take(4).toList(growable: false);
    _detectedPreviewBytes = result.previewBytes;
    _detectedObjects = topObjects;
    _searchPrompt = topObjects.isEmpty ? null : _buildSearchPrompt(topObjects);
  }

  void _applySearchPrefillFromDetectedObjects() {
    if (!_isSearchCategory || _detectedObjects.isEmpty) {
      return;
    }

    final labels = _detectedObjects
        .take(3)
        .map((item) => item.displayLabel)
        .where((label) => label.trim().isNotEmpty)
        .join(', ');
    if (labels.isEmpty) {
      return;
    }

    final searchTitle = '\u041f\u043e\u0438\u0441\u043a: $labels';
    final searchHint =
        '\u041b\u043e\u043a\u0430\u043b\u044c\u043d\u043e \u0440\u0430\u0441\u043f\u043e\u0437\u043d\u0430\u043d\u043e \u043d\u0430 \u0444\u043e\u0442\u043e: $labels.';

    _suspendDraftWatchers = true;
    if (_titleController.text.trim().isEmpty) {
      _titleController.text = searchTitle;
    }
    final currentDescription = _descriptionController.text.trim();
    if (!currentDescription.contains(searchHint)) {
      _descriptionController.text = currentDescription.isEmpty
          ? searchHint
          : '$currentDescription\n\n$searchHint';
    }
    _suspendDraftWatchers = false;
  }

  Future<void> _analyzeSelectedImage(List<int> bytes) async {
    if (!_objectDetectionReady) {
      await _runSmartPrefill();
      return;
    }

    setState(() {
      _imageProcessing = true;
      _scanProgress = const AiScanProgress(
        stage: AiScanStage.scanning,
        value: 0.08,
        active: true,
        title: '\u041b\u043e\u043a\u0430\u043b\u044c\u043d\u044b\u0439 vision-\u0430\u043d\u0430\u043b\u0438\u0437',
        subtitle:
            '\u041c\u043e\u0434\u0435\u043b\u044c \u0438\u0449\u0435\u0442 \u043e\u0431\u044a\u0435\u043a\u0442\u044b \u043d\u0430 \u0441\u043d\u0438\u043c\u043a\u0435 \u0434\u043b\u044f \u0431\u044b\u0441\u0442\u0440\u043e\u0433\u043e \u043f\u043e\u0438\u0441\u043a\u0430.',
      );
    });

    try {
      final detectionResult =
          await ObjectDetectionService.instance.detectObjects(bytes);
      if (!mounted) return;
      setState(() {
        _applyObjectDetection(detectionResult);
        if (_isSearchCategory) {
          _applySearchPrefillFromDetectedObjects();
        }
      });
    } catch (error) {
      debugPrint('Object detection error: $error');
    }

    try {
      if (_selectedImage != null) {
        final inputImage = InputImage.fromFile(_selectedImage!);
        final textRecognizer = TextRecognizer();
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        
        if (recognizedText.text.trim().isNotEmpty) {
            _suspendDraftWatchers = true;
            final prevText = _descriptionController.text.trim();
            final extractedInfo = 'Распознанный текст на фото: \n${recognizedText.text.trim()}';
            if (!prevText.contains('Распознанный текст на фото')) {
              _descriptionController.text = prevText.isEmpty ? extractedInfo : '$prevText\n\n$extractedInfo';
            }
            _suspendDraftWatchers = false;
        }
        textRecognizer.close();
      }
    } catch (e) {
      debugPrint('Text recognition error: $e');
    }

    await _runSmartPrefill();
  }

  Future<void> _enhanceSelectedImage() async {
    final image = _selectedImage;
    if (image == null || _upscalingImage) {
      return;
    }

    try {
      final bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        _upscalingImage = true;
        _imageProcessing = true;
        _scanProgress = const AiScanProgress(
          stage: AiScanStage.scanning,
          value: 0.18,
          active: true,
          title: 'Real-ESRGAN x4',
          subtitle:
              '\u0423\u043b\u0443\u0447\u0448\u0430\u0435\u043c \u0441\u043d\u0438\u043c\u043e\u043a \u043d\u0430 backend \u043f\u0435\u0440\u0435\u0434 AI-\u0430\u043d\u0430\u043b\u0438\u0437\u043e\u043c.',
        );
      });

      final response = await _postBackendJson(
        '/ai/upscale_image',
        {
          'image': base64Encode(bytes),
          'max_input_side': 512,
        },
        timeout: const Duration(minutes: 4),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final encoded = payload['image'] as String?;
      if (encoded == null || encoded.isEmpty) {
        throw Exception('Empty upscale payload');
      }

      final enhancedBytes = base64Decode(encoded);
      final file = File(
        '${Directory.systemTemp.path}/soobshio_upscaled_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(enhancedBytes, flush: true);

      if (!mounted) return;
      setState(() {
        _selectedImage = file;
        _clearDetectionState();
      });

      await _analyzeSelectedImage(enhancedBytes);

      if (!mounted) return;
      final outputWidth = payload['output_width'];
      final outputHeight = payload['output_height'];
      final cached = payload['cached'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cached
                ? 'Real-ESRGAN x4: \u0432\u0437\u044f\u043b\u0438 \u0433\u043e\u0442\u043e\u0432\u044b\u0439 upscale ${outputWidth}x$outputHeight'
                : 'Real-ESRGAN x4: \u0444\u043e\u0442\u043e \u0443\u043b\u0443\u0447\u0448\u0435\u043d\u043e \u0434\u043e ${outputWidth}x$outputHeight',
          ),
        ),
      );
    } catch (error) {
      debugPrint('Upscale error: $error');
      if (mounted) {
        setState(() {
          _imageProcessing = false;
          _scanProgress = const AiScanProgress.idle();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Real-ESRGAN x4 \u043d\u0435 \u0441\u0440\u0430\u0431\u043e\u0442\u0430\u043b: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _upscalingImage = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
          source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 70);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = File(pickedFile.path);
          _clearDetectionState();
          _scanProgress = const AiScanProgress(
            stage: AiScanStage.scanning,
            value: 0.04,
            active: true,
            title: 'Кадр принят',
            subtitle:
                'Запускаем AI-сканирование и собираем первичные признаки.',
          );
        });
        await _analyzeSelectedImage(bytes);
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  Set<String> _tokenize(String value) {
    final matches =
        RegExp('[A-Za-z0-9]+|[\u0410-\u044F\u0401\u0451]+').allMatches(
      value.toLowerCase(),
    );
    return matches
        .map((match) => match.group(0) ?? '')
        .where((token) => token.length > 2 && !_stopWords.contains(token))
        .toSet();
  }

  double _tokenOverlap(Set<String> left, Set<String> right) {
    if (left.isEmpty || right.isEmpty) return 0;
    final intersection = left.intersection(right).length;
    final union = left.union(right).length;
    if (union == 0) return 0;
    return intersection / union;
  }

  Map<String, dynamic>? _pickBestSimilar(List<Map<String, dynamic>> reports) {
    if (_latitude == null || _longitude == null) return null;

    final draftTokens = _tokenize(
      [
        _titleController.text,
        _descriptionController.text,
        _smartSummary,
      ].whereType<String>().join(' '),
    );
    final draftAddress = _addressController.text.trim().toLowerCase();

    double bestScore = 0;
    Map<String, dynamic>? bestReport;

    for (final report in reports) {
      final lat = (report['lat'] as num?)?.toDouble();
      final lng = (report['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final distanceMeters = _distance.as(
        LengthUnit.Meter,
        LatLng(_latitude!, _longitude!),
        LatLng(lat, lng),
      );
      if (distanceMeters > 180) continue;

      final reportCategory = (report['category'] as String?)?.trim() ?? '';
      final sameCategory =
          _category != _defaultCategory && reportCategory == _category;
      final reportText =
          '${report['title'] ?? ''} ${report['description'] ?? ''}';
      final overlap = _tokenOverlap(draftTokens, _tokenize(reportText));
      final reportAddress = (report['address'] as String?)?.toLowerCase() ?? '';
      final sameAddress = draftAddress.isNotEmpty &&
          reportAddress.contains(draftAddress.split(',').first);
      final distanceScore = (1 - (distanceMeters / 180)).clamp(0.0, 1.0);
      final score = (sameCategory ? 0.45 : 0) +
          (sameAddress ? 0.20 : 0) +
          overlap * 0.25 +
          distanceScore * 0.30;

      if (score > bestScore &&
          (sameCategory || sameAddress || overlap >= 0.12)) {
        bestScore = score;
        bestReport = {
          ...report,
          'distance_meters': distanceMeters.round(),
          'similarity_score': score,
        };
      }
    }

    if (bestScore < 0.42) return null;
    return bestReport;
  }

  Future<void> _findSimilarReports({
    String? signatureOverride,
    bool force = false,
    bool trackScanProgress = false,
  }) async {
    if (_latitude == null || _longitude == null) {
      _lastSimilarSignature = null;
      if (mounted) setState(() => _similarReport = null);
      if (trackScanProgress) {
        _updateScanProgress(
          stage: AiScanStage.duplicateSearch,
          value: 0.92,
          title: 'Поиск дублей пропущен',
          subtitle:
              'Нужна геопривязка, чтобы проверить похожие обращения рядом.',
        );
      }
      return;
    }

    final signature = signatureOverride ?? _buildSimilarSignature();
    if (!force && signature == _lastSimilarSignature) {
      return;
    }

    setState(() => _checkingSimilar = true);
    if (trackScanProgress) {
      _updateScanProgress(
        stage: AiScanStage.duplicateSearch,
        value: 0.84,
        title: 'Поиск дублей',
        subtitle:
            'Сверяем обращение с ближайшими сигналами на карте.',
      );
    }
    try {
      final latMin = (_latitude! - 0.002).toStringAsFixed(6);
      final latMax = (_latitude! + 0.002).toStringAsFixed(6);
      final lngMin = (_longitude! - 0.0025).toStringAsFixed(6);
      final lngMax = (_longitude! + 0.0025).toStringAsFixed(6);
      final url = '${MapConfig.reportsRestUrl}'
          '?select=id,title,description,address,category,status,lat,lng,likes_count,supporters,created_at'
          '&status=eq.open'
          '&lat=gte.$latMin'
          '&lat=lte.$latMax'
          '&lng=gte.$lngMin'
          '&lng=lte.$lngMax'
          '&order=created_at.desc'
          '&limit=40';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'apikey': MapConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${MapConfig.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body) as List<dynamic>;
        final reports = raw.cast<Map<String, dynamic>>();
        final matchedReport = _pickBestSimilar(reports);
        if (mounted) {
          setState(() => _similarReport = matchedReport);
        }
        if (trackScanProgress) {
          _updateScanProgress(
            stage: AiScanStage.duplicateSearch,
            value: 0.96,
            title: 'Поиск дублей',
            subtitle: matchedReport != null
                ? 'Найден похожий городской сигнал рядом с вашей точкой.'
                : 'Похожие обращения рядом не обнаружены.',
          );
        }
        _lastSimilarSignature = signature;
      }
    } catch (error) {
      debugPrint('Similar search error: $error');
    }

    if (mounted) setState(() => _checkingSimilar = false);
  }

  Future<void> _supportSameIssue() async {
    final report = _similarReport;
    if (report == null) return;

    final id = report['id'];
    if (id == null) return;

    try {
      final likes = ((report['likes_count'] as num?) ?? 0).toInt() + 1;
      final supporters = ((report['supporters'] as num?) ?? 0).toInt() + 1;
      final response = await http
          .patch(
            Uri.parse('${MapConfig.reportsRestUrl}?id=eq.$id'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': MapConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${MapConfig.supabaseAnonKey}',
            },
            body: jsonEncode({
              'likes_count': likes,
              'supporters': supporters,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Добавили ваш голос к существующей проблеме')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('Support same issue error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Не удалось поддержать существующее обращение')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (_latitude == null || _longitude == null) {
      setState(() => _submitError =
          'Нужны координаты проблемы. Разрешите GPS или откройте форму с карты.');
      return;
    }
    if (_category == _defaultCategory &&
        (_selectedImage != null ||
            _descriptionController.text.trim().isNotEmpty)) {
      await _runSmartPrefill();
    }
    setState(() {
      _sending = true;
      _submitError = null;
    });
    final desc = _descriptionController.text.trim();
    final summary = _smartSummary?.trim();
    final title = _titleController.text.trim().isEmpty
        ? ((summary?.isNotEmpty == true)
            ? summary!
            : (desc.length > 200 ? desc.substring(0, 200) : desc))
        : _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _sending = false;
        _submitError =
            'Добавьте фото или кратко опишите проблему.';
      });
      return;
    }
    try {
      final uploadedImageUrl = await _uploadSelectedImageToStorage();
      final body = {
        'title': title.length > 200 ? title.substring(0, 200) : title,
        'description': desc.isNotEmpty ? desc : summary,
        'lat': _latitude,
        'lng': _longitude,
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'category': _category,
        'status': 'open',
        'source': 'mobile_app',
        'likes_count': 0,
        'supporters': 0,
        'images': uploadedImageUrl == null ? [] : [uploadedImageUrl],
      };

      final r = await http
          .post(
            Uri.parse(MapConfig.reportsRestUrl),
            headers: {
              'Content-Type': 'application/json',
              'apikey': MapConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${MapConfig.supabaseAnonKey}',
              'Prefer': 'return=minimal'
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Обращение отправлено')),
        );
        Navigator.of(context).pop(true);
        return;
      }
      // Попытка упала (500, 502, 503) — сохраняем локально
      await _saveToDraftBox(title, desc.isNotEmpty ? desc : (summary ?? ''), _category);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сервер не отвечает. Жалоба сохранена в Черновики!')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if ('$e'.contains('Storage upload failed')) {
        setState(() => _submitError = 'Не удалось загрузить фото в Storage. Проверьте bucket reports-media и policy на upload.');
      } else {
        await _saveToDraftBox(title, desc.isNotEmpty ? desc : summary ?? '', _category);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет сети. Жалоба сохранена в Черновики и улетит при появлении связи.')),
        );
        Navigator.of(context).pop(true);
        return;
      }
      debugPrint('Submit complaint: $e');
    }
    setState(() => _sending = false);
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _primary.withAlpha(24) : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? _primary.withAlpha(110) : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: active ? Colors.white : Colors.white70),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickIntroCard() {
    final hasGps = _latitude != null && _longitude != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Фото + 2 слова',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Загрузите фото и скажите, например: «Тут яма». AI сам выберет категорию и подтянет адрес по GPS.',
                      style: TextStyle(color: Colors.white70, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                icon: hasGps ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                label: hasGps
                    ? (_isGpsLocation
                        ? 'Точный GPS включен'
                        : 'Точка взята с карты')
                    : 'Координаты еще не получены',
                active: hasGps,
              ),
              _buildStatusChip(
                icon: Icons.sell_rounded,
                label:
                    'Категория: $_category',
                active: _category != _defaultCategory,
              ),
              if (_smartSummary != null && _smartSummary!.isNotEmpty)
                _buildStatusChip(
                  icon: Icons.description_outlined,
                  label: _smartSummary!,
                  active: true,
                ),
              if (_smartSeverity != null)
                _buildStatusChip(
                  icon: Icons.priority_high_rounded,
                  label:
                      'Приоритет AI: $_smartSeverity/3',
                  active: _smartSeverity! >= 2,
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _aiProcessing ? null : _runSmartPrefill,
              icon: _aiProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high_rounded),
              label: Text(_aiProcessing
                  ? 'AI заполняет...'
                  : 'Заполнить автоматически'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(18),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarReportCard() {
    if (_checkingSimilar) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF172032),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Проверяем, есть ли уже такая же проблема рядом...',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    if (_similarReport == null) {
      return const SizedBox.shrink();
    }

    final report = _similarReport!;
    final distanceMeters = report['distance_meters'];
    final likes = report['likes_count'] ?? 0;
    final supporters = report['supporters'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2438),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00E5FF).withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_rounded, color: Color(0xFF00E5FF)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Похоже, проблема уже отмечена',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (report['title'] as String?)?.trim().isNotEmpty == true
                ? report['title'] as String
                : (report['description'] as String?) ??
                    'Существующее обращение',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${report['category'] ?? _defaultCategory} • ${distanceMeters ?? 'рядом'} м • адрес: ${report['address'] ?? 'не указан'}',
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _supportSameIssue,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text(
                  'У меня такая же'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Поддержали: $likes • присоединились: $supporters',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) {
      return const SizedBox.shrink();
    }

    return AiScanPreview(
      imageProvider: _detectedPreviewBytes != null
          ? MemoryImage(_detectedPreviewBytes!)
          : FileImage(_selectedImage!),
      progress: _scanProgress,
      idleBorderColor: _primary.withAlpha(50),
      onRemove: () {
        setState(() {
          _selectedImage = null;
          _clearDetectionState();
          _scanProgress = const AiScanProgress.idle();
        });
      },
    );
  }

  Widget _buildDetectionSummaryCard() {
    if (_detectedObjects.isEmpty) {
      return const SizedBox.shrink();
    }

    final accent = _isSearchCategory ? const Color(0xFF4ADE80) : _primary;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10181C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha(130)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isSearchCategory
                ? '\u041f\u043e\u0434\u0441\u043a\u0430\u0437\u043a\u0438 \u0434\u043b\u044f \u043f\u043e\u0438\u0441\u043a\u0430'
                : '\u041e\u0431\u043d\u0430\u0440\u0443\u0436\u0435\u043d\u043e \u043d\u0430 \u0444\u043e\u0442\u043e',
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_searchPrompt != null) ...[
            const SizedBox(height: 6),
            Text(
              _searchPrompt!,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _detectedObjects
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(24),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withAlpha(90)),
                    ),
                    child: Text(
                      '${item.displayLabel} ${(item.confidence * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildUpscaleButton() {
    if (_selectedImage == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        onPressed: (_imageProcessing || _upscalingImage) ? null : _enhanceSelectedImage,
        icon: _upscalingImage
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
          _upscalingImage
              ? 'Real-ESRGAN x4...'
              : '\u0423\u043b\u0443\u0447\u0448\u0438\u0442\u044c \u0444\u043e\u0442\u043e \u00d74',
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: const Color(0xFF6EE7B7).withAlpha(160)),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          backgroundColor: const Color(0xFF0F1B17),
        ),
      ),
    );
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
            _buildQuickIntroCard(),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText:
                    'Заголовок',
                hintText:
                    'Можно не заполнять, AI подставит сам',
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
                labelText:
                    'Что случилось',
                hintText:
                    'Например: Тут яма, автобус не пришел, во дворе темно',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _card,
                alignLabelWithHint: true,
                suffixIcon: IconButton(
                  color: _isListening ? Colors.redAccent : _primary,
                  icon: _aiProcessing
                      ? const SizedBox(
                          width: 16.0,
                          height: 16.0,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_isListening ? Icons.mic : Icons.mic_none),
                  tooltip:
                      'Диктовать голосом',
                  onPressed: _aiProcessing ? null : _listen,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _imageProcessing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, color: Colors.white70),
                    label: const Text(
                        'Сделать фото',
                        style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _primary.withAlpha(100)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _imageProcessing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon:
                        const Icon(Icons.photo_library, color: Colors.white70),
                    label: const Text(
                        'Галерея',
                        style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _primary.withAlpha(100)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            _buildImagePreview(),
            _buildUpscaleButton(),
            _buildDetectionSummaryCard(),
            const SizedBox(height: 12.0),
            _buildSimilarReportCard(),
            const SizedBox(height: 12.0),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText:
                    'Категория',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: _card,
              ),
              dropdownColor: _card,
              style: const TextStyle(color: Colors.white),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _category = v ?? _defaultCategory;
                  if (_isSearchCategory) {
                    _applySearchPrefillFromDetectedObjects();
                  }
                });
                _scheduleSimilarReportsCheck(
                  delay: const Duration(milliseconds: 200),
                  force: true,
                );
              },
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText:
                          'Адрес',
                      hintText:
                          'Улица, дом или «Взять с карты»',
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
                    onPressed:
                        _loadingAddress ? null : _fetchAddressFromCoordinates,
                    icon: _loadingAddress
                        ? const SizedBox(
                            width: 22.0,
                            height: 22.0,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white70),
                          )
                        : const Icon(Icons.my_location),
                    tooltip:
                        'Определить адрес по координатам карты',
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
                      color:
                          _isGpsLocation ? Colors.greenAccent : Colors.white54,
                      fontSize: 12,
                      fontWeight:
                          _isGpsLocation ? FontWeight.bold : FontWeight.normal),
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
              Text(_submitError!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(
              height: 24.0,
            ),
            FilledButton.icon(
              onPressed: _sending
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _submit();
                    },
              icon: _sending
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending
                  ? 'Отправка...'
                  : 'Отправить жалобу'),
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

  Future<void> _saveToDraftBox(String title, String description, String category) async {
    try {
      await DraftBoxService.instance.saveDraft(
        title: title,
        description: description,
        lat: _latitude ?? 0,
        lng: _longitude ?? 0,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        category: category,
        imagePath: _selectedImage?.path,
      );
    } catch (err) {
      debugPrint('DraftBox save error: ');
    }
  }
}
