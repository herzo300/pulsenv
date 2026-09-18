import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../map/map_config.dart';
import '../core/app_router.dart';
import '../services/backend_api_service.dart';
import '../services/analytics_service.dart';
import '../services/device_location_service.dart';
import '../services/object_detection_service.dart';
import '../services/city_provider.dart';
import '../theme/pulse_colors.dart';
import '../theme/theme_provider.dart';
import '../services/draft_box_service.dart';
import '../services/geocoding_service.dart';
import '../data/nizhnevartovsk_houses.dart';
import '../widgets/ai_scan_preview.dart';
import '../widgets/app_ui.dart';
import '../widgets/wow_effects.dart';
import '../widgets/neutral_animated_form_background.dart';
import 'complaint/widgets/index.dart';

class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({
    super.key,
    this.initialCenter,
    this.initialDraftId,
    this.initialAddress,
    this.initialCategory,
    this.initialDescription,
  });

  final LatLng? initialCenter;
  final String? initialDraftId;
  final String? initialAddress;
  final String? initialCategory;
  final String? initialDescription;

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  static final Color _primary = PulseColors.primary;
  static const String _defaultCategory = 'Прочее';
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
    'ЧП',
    'ЖКХ',
    'Дороги',
    'Освещение',
    'Транспорт',
    'Экология',
    'Безопасность',
    'Снег/Наледь',
    'Медицина',
    'Образование',
    'Парковки',
    'Строительство',
    'Животные',
    'Вещи',
    'Мероприятие',
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
  int _shakeTrigger = 0;

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
  bool _crossPostToSocials = false;
  String? _lastSimilarSignature;
  AiScanProgress _scanProgress = const AiScanProgress.idle();

  String get _searchCategory => _categories.length > 1
      ? _categories[_categories.length - 2]
      : _defaultCategory;
  bool get _isSearchCategory => _category == _searchCategory;

  @override
  void initState() {
    super.initState();
    _initializeObjectDetection();
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _addressController.text = widget.initialAddress!;
    }
    if (widget.initialDescription != null && widget.initialDescription!.isNotEmpty) {
      _descriptionController.text = widget.initialDescription!;
    }
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _category = widget.initialCategory!;
    }
    _titleController.addListener(_handleDraftChanged);
    _descriptionController.addListener(_handleDraftChanged);
    _addressController.addListener(_handleDraftChanged);
    if (widget.initialCenter != null) {
      _latitude = widget.initialCenter!.latitude;
      _longitude = widget.initialCenter!.longitude;
    }
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

  // =================== Initialization ===================

  Future<void> _initializeObjectDetection() async {
    try {
      await ObjectDetectionService.instance.ensureInitialized();
      if (!mounted) return;
      setState(() => _objectDetectionReady = true);
    } catch (error) {
      debugPrint('Object detection init error: $error');
    }
  }

  // =================== GPS & Location ===================

  Future<void> _fetchGPSLocation() async {
    if (mounted) setState(() => _loadingAddress = true);
    try {
      final result = await DeviceLocationService.instance.resolve(forceCurrentGPS: true);
      if (!result.isSuccess) {
        if (result.failure != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result.failure!.userMessage)));
          // GPS выключен в телефоне — сразу открываем настройки местоположения
          await DeviceLocationService.instance
              .openFailureSettings(result.failure!);
        }
        return;
      }

      final position = result.position!;
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isGpsLocation = true;
      });
      await _fetchAddressFromCoordinates();
    } catch (e) {
      debugPrint('GPS error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Не удалось определить GPS. Попробуйте на улице или укажите место на карте.')));
      }
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  void _showOnMap() {
    if (_latitude != null && _longitude != null) {
      final payload = {
        'action': 'show_on_map',
        'lat': _latitude,
        'lng': _longitude,
      };
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(payload);
      } else {
        AppRouter.goToMap(
          context: context,
          payload: {
            'lat': _latitude!.toString(),
            'lng': _longitude!.toString(),
          },
        );
      }
    }
  }

  Future<void> _fetchAddressFromCoordinates() async {
    if (_latitude == null || _longitude == null) return;
    setState(() => _loadingAddress = true);
    try {
      final localAddress = await GeocodingService.instance.reverseGeocode(
        lat: _latitude!,
        lng: _longitude!,
      );
      if (localAddress != null && localAddress.isValid) {
        _suspendDraftWatchers = true;
        _addressController.text = localAddress.full;
        _suspendDraftWatchers = false;
        _scheduleSimilarReportsCheck(
            delay: const Duration(milliseconds: 250));
      } else {
        final url = Uri.parse(
            '${MapConfig.backendApiBaseUrl}/geo/reverse?lat=$_latitude&lon=$_longitude');
        final r = await http.get(url).timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) {
          final data = jsonDecode(r.body) as Map<String, dynamic>;
          final displayName = data['address'] as String?;
          if (displayName != null && displayName.isNotEmpty) {
            _suspendDraftWatchers = true;
            _addressController.text = displayName;
            _suspendDraftWatchers = false;
            _scheduleSimilarReportsCheck(
                delay: const Duration(milliseconds: 250));
          }
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode (local failed, trying HTTP): $e');
      try {
        final url = Uri.parse(
            '${MapConfig.backendApiBaseUrl}/geo/reverse?lat=$_latitude&lon=$_longitude');
        final r = await http.get(url).timeout(const Duration(seconds: 5));
        if (r.statusCode == 200) {
          final data = jsonDecode(r.body) as Map<String, dynamic>;
          final displayName = data['address'] as String?;
          if (displayName != null && displayName.isNotEmpty) {
            _suspendDraftWatchers = true;
            _addressController.text = displayName;
            _suspendDraftWatchers = false;
            _scheduleSimilarReportsCheck(
                delay: const Duration(milliseconds: 250));
          }
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Не удалось определить адрес: $err')));
        }
      }
    }
    if (mounted) setState(() => _loadingAddress = false);
  }

  // =================== Draft & Similar Reports ===================

  void _handleDraftChanged() {
    if (_suspendDraftWatchers || _aiProcessing || _sending) return;
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

  void _scheduleSimilarReportsCheck(
      {Duration delay = const Duration(milliseconds: 650),
      bool force = false}) {
    _similarSearchDebounce?.cancel();
    final hasDraftSignal = _titleController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _addressController.text.trim().isNotEmpty ||
        _smartSummary?.trim().isNotEmpty == true;
    if (_latitude == null || _longitude == null || !hasDraftSignal) {
      _lastSimilarSignature = null;
      _similarReport = null;
      if (mounted) setState(() {});
      return;
    }
    final signature = _buildSimilarSignature();
    if (!force && signature == _lastSimilarSignature) return;
    _similarSearchDebounce = Timer(delay, () {
      if (!mounted) return;
      _findSimilarReports(signatureOverride: signature, force: force);
    });
  }

  Set<String> _tokenize(String value) {
    final matches = RegExp('[A-Za-z0-9]+|[\u0410-\u044F\u0401\u0451]+')
        .allMatches(value.toLowerCase());
    return matches
        .map((m) => m.group(0) ?? '')
        .where((t) => t.length > 2 && !_stopWords.contains(t))
        .toSet();
  }

  double _tokenOverlap(Set<String> left, Set<String> right) {
    if (left.isEmpty || right.isEmpty) return 0;
    final intersection = left.intersection(right).length;
    final union = left.union(right).length;
    return union == 0 ? 0 : intersection / union;
  }

  Map<String, dynamic>? _pickBestSimilar(List<Map<String, dynamic>> reports) {
    if (_latitude == null || _longitude == null) return null;
    final draftTokens = _tokenize([
      _titleController.text,
      _descriptionController.text,
      _smartSummary
    ].whereType<String>().join(' '));
    final draftAddress = _addressController.text.trim().toLowerCase();
    double bestScore = 0;
    Map<String, dynamic>? bestReport;
    for (final report in reports) {
      final lat = (report['lat'] as num?)?.toDouble();
      final lng = (report['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final distanceMeters = _distance.as(
          LengthUnit.Meter, LatLng(_latitude!, _longitude!), LatLng(lat, lng));
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
          'similarity_score': score
        };
      }
    }
    return bestScore < 0.42 ? null : bestReport;
  }

  Future<void> _findSimilarReports(
      {String? signatureOverride,
      bool force = false,
      bool trackScanProgress = false}) async {
    if (_latitude == null || _longitude == null) {
      _lastSimilarSignature = null;
      if (mounted) setState(() => _similarReport = null);
      if (trackScanProgress) {
        _updateScanProgress(
            stage: AiScanStage.duplicateSearch,
            value: 0.92,
            title: 'Поиск дублей пропущен',
            subtitle:
                'Нужна геопривязка, чтобы проверить похожие обращения рядом.');
      }
      return;
    }
    final signature = signatureOverride ?? _buildSimilarSignature();
    if (!force && signature == _lastSimilarSignature) return;
    setState(() => _checkingSimilar = true);
    if (trackScanProgress) {
      _updateScanProgress(
          stage: AiScanStage.duplicateSearch,
          value: 0.84,
          title: 'Поиск дублей',
          subtitle: 'Сверяем обращение с ближайшими сигналами на карте.');
    }
    try {
      final latMin = (_latitude! - 0.002).toStringAsFixed(6);
      final latMax = (_latitude! + 0.002).toStringAsFixed(6);
      final lngMin = (_longitude! - 0.0025).toStringAsFixed(6);
      final lngMax = (_longitude! + 0.0025).toStringAsFixed(6);
      final url =
          '${MapConfig.reportsApiUrl}?select=id,title,description,address,category,status,lat,lng,likes_count,supporters,created_at&status=eq.open&lat=gte.$latMin&lat=lte.$latMax&lng=gte.$lngMin&lng=lte.$lngMax&order=created_at.desc&limit=40';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final reports = (jsonDecode(response.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final matchedReport = _pickBestSimilar(reports);
        if (mounted) setState(() => _similarReport = matchedReport);
        if (trackScanProgress) {
          _updateScanProgress(
              stage: AiScanStage.duplicateSearch,
              value: 0.96,
              title: 'Поиск дублей',
              subtitle: matchedReport != null
                  ? 'Найден похожий городской сигнал рядом с вашей точкой.'
                  : 'Похожие обращения рядом не обнаружены.');
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
          .patch(Uri.parse('${MapConfig.reportsApiUrl}?id=eq.$id'),
              headers: {'Content-Type': 'application/json'},
              body:
                  jsonEncode({'likes_count': likes, 'supporters': supporters}))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Добавили ваш голос к существующей проблеме')));
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('Support same issue error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Не удалось поддержать существующее обращение')));
      }
    }
  }

  // =================== Voice Input ===================

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
            _runSmartPrefill();
          }
        },
        onError: (val) => debugPrint('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
            onResult: (val) => setState(
                () => _descriptionController.text = val.recognizedWords),
            localeId: 'ru_RU');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // =================== AI Processing ===================

  Future<http.Response> _postBackendJson(String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 25)}) async {
    return _backendApi.postJson(path, body, timeout: timeout);
  }

  void _updateScanProgress(
      {required AiScanStage stage,
      required double value,
      String? title,
      String? subtitle,
      bool active = true}) {
    if (!mounted) return;
    setState(() => _scanProgress = AiScanProgress(
        stage: stage,
        value: value,
        active: active,
        title: title,
        subtitle: subtitle));
  }

  Future<void> _settleScanProgress(
      {required String title, required String subtitle}) async {
    if (!mounted) return;
    setState(() => _scanProgress = AiScanProgress(
        stage: AiScanStage.complete,
        value: 1,
        active: true,
        title: title,
        subtitle: subtitle));
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() => _scanProgress = const AiScanProgress.idle());
  }

  Future<void> _runSmartPrefill() async {
    if (_aiProcessing) return;
    final text = _descriptionController.text.trim();
    final hasImage = _selectedImage != null;
    if (text.isEmpty && _selectedImage == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Добавьте фото или пару слов о ситуации')));
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
          subtitle: 'Готовим изображение и выделяем визуальные признаки.');
    }
    try {
      String? encodedImage;
      if (_selectedImage != null) {
        _updateScanProgress(
            stage: AiScanStage.scanning,
            value: 0.32,
            title: 'Сканирование кадра',
            subtitle: 'Нормализуем фото, подсвечиваем контуры и GPS-контекст.');
        encodedImage = base64Encode(await _selectedImage!.readAsBytes());
      }
      if (hasImage) {
        _updateScanProgress(
            stage: AiScanStage.classification,
            value: 0.56,
            title: 'Классификация AI',
            subtitle:
                'Определяем категорию, адрес и краткое описание ситуации.');
      }
      final response = await _postBackendJson('/ai/sanitize_report', {
        'text': text,
        'image': encodedImage,
        'lat': _latitude,
        'lng': _longitude,
        'address': _addressController.text.trim()
      });
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
            subtitle: 'AI собрал черновик обращения и геопривязку.');
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
          final cur = _descriptionController.text.trim();
          if (cur.isEmpty || cur.length <= 12) {
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
        if (severity is num) _smartSeverity = severity.toInt();
      });
      _suspendDraftWatchers = false;
      await _findSimilarReports(force: true, trackScanProgress: hasImage);
      if (hasImage) {
        await _settleScanProgress(
            title: _similarReport != null
                ? 'Похожий сигнал найден'
                : 'Проверка завершена',
            subtitle: _similarReport != null
                ? 'Рядом уже есть похожее обращение, можно поддержать его в один тап.'
                : 'Дубликаты рядом не найдены. Можно отправлять новое обращение.');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI заполнил черновик: $_category')));
      }
    } catch (error) {
      debugPrint('Smart prefill error: $error');
      if (hasImage) {
        await _settleScanProgress(
            title: 'Сканирование прервано',
            subtitle:
                'AI не завершил анализ. Попробуйте другое фото или повторите позже.');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Не удалось автоматически заполнить обращение')));
      }
    }
    if (mounted) {
      setState(() {
        _aiProcessing = false;
        _imageProcessing = false;
      });
    }
  }

  // =================== Image Handling ===================

  void _clearDetectionState() {
    _detectedPreviewBytes = null;
    _detectedObjects = const [];
    _searchPrompt = null;
  }

  String _buildSearchPrompt(List<DetectedSearchObject> objects) {
    final labels = objects
        .take(3)
        .map((item) => item.displayLabel)
        .where((l) => l.trim().isNotEmpty)
        .join(', ');
    return labels.isEmpty
        ? 'На фото нет ясных объектов.'
        : 'Похоже на: $labels';
  }

  void _applyObjectDetection(ObjectDetectionResult result) {
    final topObjects = result.objects.take(4).toList(growable: false);
    _detectedPreviewBytes = result.previewBytes;
    _detectedObjects = topObjects;
    _searchPrompt = topObjects.isEmpty ? null : _buildSearchPrompt(topObjects);
  }

  void _applySearchPrefillFromDetectedObjects() {
    if (!_isSearchCategory || _detectedObjects.isEmpty) return;
    final labels = _detectedObjects
        .take(3)
        .map((item) => item.displayLabel)
        .where((l) => l.trim().isNotEmpty)
        .join(', ');
    if (labels.isEmpty) return;
    final searchTitle = 'Поиск: $labels';
    final searchHint =
        'Локально распознано на фото: $labels.';
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

  String _guessImageExtension(String path) {
    final l = path.toLowerCase();
    if (l.endsWith('.png')) return 'png';
    if (l.endsWith('.webp')) return 'webp';
    if (l.endsWith('.heic')) return 'heic';
    return 'jpg';
  }

  String _guessImageMimeType(String ext) {
    switch (ext) {
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

List<int> _compressImageIsolate(List<int> inputBytes) {
  try {
    final image = img.decodeImage(Uint8List.fromList(inputBytes));
    if (image == null) return inputBytes;
    
    // Resize if too large (max 1280px dimension) to save extra bandwidth
    img.Image resized = image;
    if (image.width > 1280 || image.height > 1280) {
      resized = img.copyResize(
        image,
        width: image.width > image.height ? 1280 : null,
        height: image.height >= image.width ? 1280 : null,
      );
    }
    
    return img.encodeJpg(resized, quality: 75);
  } catch (e) {
    return inputBytes;
  }
}

  Future<String?> _uploadSelectedImageToStorage() async {
    final image = _selectedImage;
    if (image == null) return null;
    
    // Compress to JPEG in a background Isolate to prevent UI frame drop
    final rawBytes = await image.readAsBytes();
    final compressedBytes = await compute(_compressImageIsolate, rawBytes);
    
    final objectPath =
        'reports/${DateTime.now().toUtc().millisecondsSinceEpoch}_${math.Random().nextInt(1 << 32)}.jpg';
    final response = await http
        .post(
            Uri.parse(MapConfig.storageUploadUrl(
                MapConfig.reportsMediaBucket, objectPath)),
            headers: {
              'Content-Type': 'image/jpeg',
              'x-upsert': 'false'
            },
            body: compressedBytes)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Storage upload failed: HTTP ${response.statusCode} ${response.body}');
    }
    return MapConfig.storagePublicUrl(MapConfig.reportsMediaBucket, objectPath);
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
          title: 'Локальный vision-анализ',
          subtitle: 'Модель ищет объекты на снимке.');
    });
    try {
      final detectionResult =
          await ObjectDetectionService.instance.detectObjects(bytes);
      if (!mounted) return;
      setState(() {
        _applyObjectDetection(detectionResult);
        if (_isSearchCategory) _applySearchPrefillFromDetectedObjects();
      });
    } catch (error) {
      debugPrint('Object detection error: $error');
    }
    try {
      if (_selectedImage != null) {
        final inputImage = InputImage.fromFile(_selectedImage!);
        final textRecognizer = TextRecognizer();
        final recognizedText = await textRecognizer.processImage(inputImage);
        if (recognizedText.text.trim().isNotEmpty) {
          _suspendDraftWatchers = true;
          final prevText = _descriptionController.text.trim();
          final extractedInfo =
              'Распознанный текст на фото: \n${recognizedText.text.trim()}';
          if (!prevText.contains('Распознанный текст на фото')) {
            _descriptionController.text = prevText.isEmpty
                ? extractedInfo
                : '$prevText\n\n$extractedInfo';
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
    if (image == null || _upscalingImage) return;
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
            subtitle: 'Улучшаем снимок на backend.');
      });
      final response = await _postBackendJson('/ai/upscale_image',
          {'image': base64Encode(bytes), 'max_input_side': 512},
          timeout: const Duration(minutes: 4));
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
          '${Directory.systemTemp.path}/soobshio_upscaled_${DateTime.now().microsecondsSinceEpoch}.jpg');
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(cached
              ? 'Real-ESRGAN x4: взяли готовый upscale $outputWidth x $outputHeight'
              : 'Real-ESRGAN x4: фото улучшено до $outputWidth x $outputHeight')));
    } catch (error) {
      debugPrint('Upscale error: $error');
      if (mounted) {
        setState(() {
          _imageProcessing = false;
          _scanProgress = const AiScanProgress.idle();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Не удалось улучшить фото. Отправим оригинал — попробуйте снова позже.')));
      }
    } finally {
      if (mounted) setState(() => _upscalingImage = false);
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
                  'Запускаем AI-сканирование и собираем первичные признаки.');
        });
        await _analyzeSelectedImage(bytes);
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Не удалось выбрать фото. Проверьте доступ к галерее и попробуйте снова.')));
      }
    }
  }

  // =================== Submission ===================

  void _showSmartDupeBlockerDialog(BuildContext context, int? dupId, String detailMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        final isDark = ThemeProvider.instance.isDarkMode;
        final bgColor = isDark ? const Color(0xCC0C1424) : Colors.white.withOpacity(0.95);
        final borderColor = isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.12);
        final textColor = isDark ? Colors.white : Colors.black87;
        
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: bgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: borderColor, width: 1.5),
            ),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                SizedBox(width: 8),
                Text(
                  'Найдено совпадение',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              detailMessage,
              style: TextStyle(color: textColor.withOpacity(0.85), fontSize: 14),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Отмена', style: TextStyle(color: textColor.withOpacity(0.6))),
              ),
              Row(
                children: [
                  if (dupId != null) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withOpacity(0.18),
                        foregroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('На карте'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('auth_token') ?? '';
                          final res = await http.get(
                            Uri.parse('${MapConfig.backendApiBaseUrl}/reports/$dupId'),
                            headers: {
                              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                            },
                          );
                          if (res.statusCode == 200) {
                            final decoded = jsonDecode(utf8.decode(res.bodyBytes));
                            final double lat = (decoded['latitude'] ?? decoded['lat'] ?? 0.0) as double;
                            final double lng = (decoded['longitude'] ?? decoded['lng'] ?? 0.0) as double;
                            
                            Navigator.of(context).pop({
                              'action': 'show_on_map',
                              'lat': lat,
                              'lng': lng,
                            });
                          }
                        } catch (e) {
                          debugPrint('Error navigating to duplicate: $e');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PulseColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
                      label: const Text('Поддержать'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('auth_token') ?? '';
                          final res = await http.post(
                            Uri.parse('${MapConfig.backendApiBaseUrl}/reports/$dupId/actions'),
                            headers: {
                              'Content-Type': 'application/json',
                              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                            },
                            body: jsonEncode({'action': 'join'}),
                          );
                          if (res.statusCode == 200) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Вы успешно поддержали существующее обращение!')),
                            );
                            Navigator.of(context).pop(true);
                          } else {
                            final bodyStr = utf8.decode(res.bodyBytes);
                            String errDetail = 'Ошибка при поддержке сообщения';
                            try {
                              errDetail = jsonDecode(bodyStr)['detail'] ?? errDetail;
                            } catch (_) {}
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errDetail)),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error supporting duplicate: $e');
                        }
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (_latitude == null || _longitude == null) {
      setState(() => _submitError =
          'Нужны координаты. Разрешите GPS или откройте форму с карты.');
      return;
    }
    if (_category == _defaultCategory &&
        (_selectedImage != null ||
            _descriptionController.text.trim().isNotEmpty)) {
      await _runSmartPrefill();
    }

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
        _submitError = 'Добавьте фото или кратко опишите ситуацию.';
        _shakeTrigger++;
      });
      return;
    }

    setState(() {
      _sending = true;
      _submitError = null;
    });

    // Перепроверка координат по OSM-реестру домов (astra P0): snap к
    // центроиду дома только если дом найден по адресу И находится рядом
    // (<= 300 м от исходной точки). Иначе сохраняем точку пользователя —
    // центроид дальнего дома испортил бы привязку дворов/дорог.
    final addressText = _addressController.text.trim();
    if (addressText.isNotEmpty &&
        _latitude != null &&
        _longitude != null) {
      final house = NizhnevartovskHousesData.findByAddress(addressText);
      if (house != null) {
        final hLat = (house['lat'] as num?)?.toDouble();
        final hLng = (house['lng'] as num?)?.toDouble();
        if (hLat != null && hLng != null) {
          const earthR = 6371000.0;
          final dLat = (_latitude! - hLat) * math.pi / 180;
          final dLng = (_longitude! - hLng) * math.pi / 180;
          final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(_latitude! * math.pi / 180) *
                  math.cos(hLat * math.pi / 180) *
                  math.sin(dLng / 2) *
                  math.sin(dLng / 2);
          final distM = earthR * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
          if (distM <= 300) {
            _latitude = hLat;
            _longitude = hLng;
          }
        }
      }
    }

    String? uploadedImageUrl;
    try {
      uploadedImageUrl = await _uploadSelectedImageToStorage();
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
        'cross_post': _crossPostToSocials,
        'images': uploadedImageUrl == null ? [] : [uploadedImageUrl]
      };
      final r = await http
          .post(Uri.parse(MapConfig.reportsApiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Prefer': 'return=minimal'
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 409) {
        setState(() => _sending = false);
        String detail = '';
        try {
          final decoded = jsonDecode(utf8.decode(r.bodyBytes));
          detail = decoded['detail'] ?? '';
        } catch (_) {}
        
        final regExp = RegExp(r'ID: #(\d+)');
        final match = regExp.firstMatch(detail);
        final dupIdStr = match != null ? match.group(1) : null;
        final dupId = dupIdStr != null ? int.tryParse(dupIdStr) : null;
        
        if (!mounted) return;
        _showSmartDupeBlockerDialog(context, dupId, detail);
        return;
      }
      if (r.statusCode >= 200 && r.statusCode < 300) {
        Map<String, dynamic>? createdData;
        try {
          createdData = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        } catch (_) {}
        if (_category == 'Животные' || _category == 'Вещи') {
          await _saveItemToLocalLostAndFound(title, desc.isNotEmpty ? desc : (summary ?? ''), _category, uploadedImageUrl);
        }
        if (!mounted) return;
        AnalyticsService.trackEvent('complaint_submitted');
        HapticFeedback.heavyImpact();
        // Show animated success overlay before popping
        await showDialog<void>(
          context: context,
          barrierColor: Colors.black54,
          builder: (ctx) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: child,
            ),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF10B981), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutBack,
                      builder: (context, v, _) => Transform.scale(
                        scale: v,
                        child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                          ),
                          child: const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Сигнал отправлен!',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Спасибо за вклад в улучшение города',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (mounted) Navigator.of(context).pop(createdData ?? true);
        return;
      }
      await _saveToDraftBox(
          title, desc.isNotEmpty ? desc : (summary ?? ''), _category);
      if (_category == 'Животные' || _category == 'Вещи') {
        await _saveItemToLocalLostAndFound(title, desc.isNotEmpty ? desc : (summary ?? ''), _category, uploadedImageUrl);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Сервер не отвечает. Сообщение сохранено в черновики.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if ('$e'.contains('Storage upload failed')) {
        setState(() => _submitError =
            'Не удалось загрузить фото. Проверьте подключение к интернету и попробуйте снова.');
      } else {
        await _saveToDraftBox(
            title, desc.isNotEmpty ? desc : summary ?? '', _category);
        if (_category == 'Животные' || _category == 'Вещи') {
          await _saveItemToLocalLostAndFound(title, desc.isNotEmpty ? desc : (summary ?? ''), _category, uploadedImageUrl);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Нет сети. Сообщение сохранено в черновики и отправится при появлении связи.')));
        Navigator.of(context).pop(true);
        return;
      }
      debugPrint('Submit complaint: $e');
    }
    setState(() => _sending = false);
  }

  Future<void> _saveItemToLocalLostAndFound(
      String title, String description, String category, String? imageUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('my_lost_and_found_items') ?? '[]';
      final List<dynamic> list = jsonDecode(raw);
      
      final newItem = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'title': title,
        'description': description,
        'category': category,
        'lat': _latitude,
        'lng': _longitude,
        'address': _addressController.text.trim().isEmpty
            ? CityProvider().activeCity.name
            : _addressController.text.trim(),
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
        'images': imageUrl != null ? [imageUrl] : [],
      };
      
      list.insert(0, newItem);
      await prefs.setString('my_lost_and_found_items', jsonEncode(list));
      
      final myReported = prefs.getStringList('my_reported_ids') ?? [];
      myReported.add(newItem['id'].toString());
      await prefs.setStringList('my_reported_ids', myReported);
    } catch (e) {
      debugPrint('Error saving local lost & found item: $e');
    }
  }

  Future<void> _saveToDraftBox(
      String title, String description, String category) async {
    try {
      await DraftBoxService.instance.saveDraft(
          title: title,
          description: description,
          lat: _latitude ?? 0,
          lng: _longitude ?? 0,
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          category: category,
          imagePath: _selectedImage?.path);
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  // =================== Build ===================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildBaseContent(context),
          VlmAnalysisOverlay(
              isAnalyzing: _aiProcessing,
              statusText: _imageProcessing
                  ? "ИИ ГЕМИНИ АНАЛИЗИРУЕТ ФОТО..."
                  : "ИИ СИСТЕМА ОБРАБАТЫВАЕТ ТЕКСТ..."),
        ],
      ),
    );
  }

  Widget _buildProgressStepper() {
    final steps = const [
      (Icons.location_on_rounded, 'Где'),
      (Icons.edit_note_rounded, 'Что'),
      (Icons.photo_camera_rounded, 'Фото'),
      (Icons.check_circle_rounded, 'Подтвердить'),
    ];

    final hasLocation = _latitude != null || _addressController.text.trim().isNotEmpty;
    final hasWhat = _category != _defaultCategory &&
        _descriptionController.text.trim().isNotEmpty;
    final hasPhoto = _selectedImage != null;
    final completions = [hasLocation, hasWhat, hasPhoto, hasWhat && hasPhoto];

    int current = 0;
    for (var i = 0; i < completions.length; i++) {
      if (!completions[i]) {
        current = i;
        break;
      }
      if (i == completions.length - 1) current = i;
    }

    return Semantics(
      label: 'Шаг ${current + 1} из ${steps.length}: ${steps[current].$2}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i <= current
                          ? PulseColors.primary.withAlpha(180)
                          : PulseColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              _StepIndicatorItem(
                icon: steps[i].$1,
                label: steps[i].$2,
                index: i,
                current: current,
                done: completions[i],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBaseContent(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Сообщить о ситуации',
            style: AppTextStyles.section.copyWith(fontSize: 20)),
        backgroundColor: PulseColors.surfaceGlass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.close, color: PulseColors.textPrimary),
            onPressed: () => Navigator.of(context).pop()),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
      body: NeutralAnimatedFormBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 128),
            children: [
              _buildProgressStepper(),
              const SizedBox(height: 16.0),
              Animate(
                target: _shakeTrigger.toDouble(),
                effects: const [
                  ShakeEffect(
                    hz: 10,
                    curve: Curves.easeOutQuad,
                    duration: Duration(milliseconds: 400),
                    offset: Offset(6, 0),
                  )
                ],
                child: ComplaintFormFields(
                  titleController: _titleController,
                  descriptionController: _descriptionController,
                  addressController: _addressController,
                  category: _category,
                  categories: _categories,
                  defaultCategory: _defaultCategory,
                  isListening: _isListening,
                  aiProcessing: _aiProcessing,
                  loadingAddress: _loadingAddress,
                  latitude: _latitude,
                  longitude: _longitude,
                  isGpsLocation: _isGpsLocation,
                  onCategoryChanged: (v) {
                    setState(() {
                      _category = v ?? _defaultCategory;
                      if (_isSearchCategory) {
                        _applySearchPrefillFromDetectedObjects();
                      }
                    });
                    _scheduleSimilarReportsCheck(
                        delay: const Duration(milliseconds: 200), force: true);
                  },
                  onAddressRefresh: _fetchAddressFromCoordinates,
                  onGpsRefresh: _fetchGPSLocation,
                  onVoiceToggle: _listen,
                  onShowOnMap: _showOnMap,
                  crossPostToSocials: _crossPostToSocials,
                  onCrossPostChanged: (val) => setState(() => _crossPostToSocials = val),
                ),
              ),
              const SizedBox(height: 12.0),
              PhotoCapturePanel(
                imageProcessing: _imageProcessing,
                selectedImage: _selectedImage,
                detectedPreviewBytes: _detectedPreviewBytes,
                detectedObjects: _detectedObjects,
                searchPrompt: _searchPrompt,
                isSearchCategory: _isSearchCategory,
                onPickImage: _pickImage,
                onRemoveImage: _clearImage,
                onEnhanceImage: _enhanceSelectedImage,
                imagePreviewWidget: AiScanPanel(
                    selectedImage: _selectedImage,
                    detectedPreviewBytes: _detectedPreviewBytes,
                    scanProgress: _scanProgress,
                    onRemoveImage: _clearImage),
                upscaleButtonWidget: UpscaleImageButton(
                    hasImage: _selectedImage != null,
                    isProcessing: _imageProcessing,
                    isUpscaling: _upscalingImage,
                    onPressed: _enhanceSelectedImage),
                detectionSummaryWidget: DetectionSummaryCard(
                    detectedObjects: _detectedObjects,
                    searchPrompt: _searchPrompt,
                    isSearchCategory: _isSearchCategory),
              ),
              const SizedBox(height: 12.0),
              SimilarReportCard(
                  checkingSimilar: _checkingSimilar,
                  similarReport: _similarReport,
                  defaultCategory: _defaultCategory,
                  onSupport: _supportSameIssue,
                  latitude: _latitude,
                  longitude: _longitude),
              const SizedBox(height: 12.0),
              GpsLocationWidget(
                  latitude: _latitude,
                  longitude: _longitude,
                  isGpsLocation: _isGpsLocation),
              if (_submitError != null) ...[
                const SizedBox(height: 12.0),
                Text(_submitError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 20.0),
              _buildDraftCards(),
            ],
          ),
        ),
      ),
    );
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _clearDetectionState();
      _scanProgress = const AiScanProgress.idle();
    });
  }

  Widget _buildDraftCards() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DraftBoxService.instance.getPendingDrafts(),
      builder: (context, snapshot) {
        final drafts = snapshot.data;
        if (drafts == null || drafts.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ЧЕРНОВИКИ',
              style: AppTextStyles.overline.copyWith(
                color: PulseColors.textTertiary,
              ),
            ),
            const SizedBox(height: 10),
            ...drafts.map((draft) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: PulseColors.primary.withAlpha(30),
                          ),
                          child: Icon(
                            Icons.drafts_rounded,
                            size: 18,
                            color: PulseColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (draft['title'] as String?)?.isNotEmpty == true
                                    ? draft['title'] as String
                                    : 'Без названия',
                                style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${draft['category'] ?? 'Прочее'} • ${_formatDraftTimestamp(draft['timestamp'] as int?)}',
                                style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 16,
                          color: PulseColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )),
          ],
        );
      },
    );
  }

  String _formatDraftTimestamp(int? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    return '${diff.inDays} дн назад';
  }

  Widget _buildBottomActionBar() {
    final _primary = PulseColors.primary;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
            color: PulseColors.surfaceGlass,
            border: Border(top: BorderSide(color: PulseColors.borderStrong))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _submit();
                    },
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_sending ? 'Отправка...' : 'Сообщить о ситуации'),
              style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StepIndicatorItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final bool done;

  const _StepIndicatorItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = index == current;
    final color = done || isCurrent
        ? PulseColors.primary
        : PulseColors.textTertiary;

    Widget iconContainer = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || isCurrent
            ? PulseColors.primary.withAlpha(isCurrent ? 60 : 40)
            : PulseColors.surfaceSoft,
        border: Border.all(color: color, width: 1.4),
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        size: 14,
        color: color,
      ),
    );

    if (isCurrent && !done) {
      iconContainer = TweenAnimationBuilder<double>(
        key: ValueKey('step_scale_$index'),
        tween: Tween<double>(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: iconContainer,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconContainer,
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isCurrent ? PulseColors.primary : PulseColors.textTertiary,
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
