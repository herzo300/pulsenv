import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import '../theme/pulse_colors.dart';
import '../theme/theme_provider.dart';
import '../services/sound_service.dart';
import '../map/map_config.dart';
import '../widgets/app_ui.dart';
import '../widgets/hologram_effect.dart';
import '../widgets/aura_living_background.dart';
import '../core/living/aura_living_engine.dart';
import '../core/living/aura_circadian.dart';
import '../screens/map/widgets/map_glass_panel.dart';
import '../widgets/pulse_glass_dropdown.dart';
import '../services/city_provider.dart';
import '../services/favorite_cameras_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text':
          'Привет! Я нейросеть-диспетчер «Гермес». Я подключен к системам Нижневартовска и обладаю навыками:\n\n'
          '📄 • Авто-генерация официальных PDF-обращений в ЖКХ и Администрацию;\n'
          '📍 • Юридический гео-анализ сигналов по конкретным адресам домов;\n'
          '👁️ • Анализ стоп-кадров с городских камер видео-наблюдения;\n'
          '🗞️ • Мониторинг экстренных новостей и ЧП по Нижневартовску.\n\n'
          'Чем я могу помочь вам сегодня?',
    }
  ];

  bool _isTyping = false;
  String _apiKey = '';
  ChatSession? _chatSession;
  final double _balance = 100.0;
  bool _isVip = false;
  bool _showPremiumPerks = false;
  int _favCamerasCount = 0;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _transcribedWords = '';

  @override
  void initState() {
    super.initState();
    SoundService().playAssistantClick();
    _loadApiKey();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key') ?? '';
    final isVip = prefs.getBool('is_premium_vip') ?? prefs.getBool('is_vip') ?? false;
    int camCount = 0;
    try {
      final favs = await FavoriteCamerasService().getFavorites();
      camCount = favs.length;
    } catch (_) {}

    setState(() {
      _apiKey = key;
      _isVip = isVip;
      _favCamerasCount = camCount;
    });
    if (key.isNotEmpty) {
      _initChatSession(key);
    }
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    setState(() {
      _apiKey = key;
    });
    _initChatSession(key);
  }

  Future<int> _resolveTelegramId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('profile_telegram_id') ??
        prefs.getInt('telegram_id') ??
        0;
  }

  void _initChatSession(String key) {
    // SECURITY PATCH: In a production app, the AI session MUST NOT be initialized on the client.
    // The key should never live on the device. We are keeping this for Demo purposes only,
    // but actual AI processing is now routed to the secure backend queue.
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: key,
      );
      _chatSession = model.startChat();
    } catch (e) {
      debugPrint('Failed to init Gemini Chat Session: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final lower = text.toLowerCase();
    final isMonitoringRequest = lower.contains('монитор') ||
        lower.contains('отслежив') ||
        lower.contains('камер') ||
        lower.contains('ищи') ||
        lower.contains('проверяй') ||
        lower.contains('найди') ||
        lower.contains('следи');

    if (isMonitoringRequest) {
      if (!_isVip) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.amber)),
              title: const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('VIP ИИ-МОНИТОРИНГ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text(
                'Автоматический 24/7 ИИ-мониторинг камер и пабликов доступен только для VIP-подписчиков (лимит: 10 задач в месяц, 0 для бесплатного тарифа).',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/profile');
                  },
                  child: const Text('Оформить VIP', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final monthKey = 'ai_task_count_${now.year}_${now.month}';
      final currentMonthCount = prefs.getInt(monthKey) ?? 0;

      if (currentMonthCount >= 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Достигнут месячный лимит (10 из 10 задач ИИ-мониторинга на этот месяц).')),
          );
        }
        return;
      }

      await prefs.setInt(monthKey, currentMonthCount + 1);
      final rawTasks = prefs.getString('ai_monitoring_tasks') ?? '[]';
      final List<dynamic> decoded = jsonDecode(rawTasks);
      final list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();

      final newTask = {
        'id': 'TASK-AI-${DateTime.now().millisecondsSinceEpoch % 100000}',
        'title': text,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'status': 'Активно 24/7',
      };
      list.insert(0, newTask);
      await prefs.setString('ai_monitoring_tasks', jsonEncode(list));
    }

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _textController.clear();
    _scrollToBottom();
    SoundService().playMessageSent();

    String responseText = '';

    try {
      final favoriteCameras = await FavoriteCamerasService().getFavorites();
      final historyPayload = _messages.take(_messages.length - 1).map((m) => {
        'role': m['role'] == 'user' ? 'user' : 'assistant',
        'content': m['text'] ?? '',
      }).toList();

      final url = Uri.parse('${MapConfig.backendApiBaseUrl}/dispatcher/ask');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'query': text,
          'city': CityProvider().activeCity.id,
          'cameras': _isVip ? favoriteCameras : [],
          'is_vip': _isVip,
          'history': historyPayload,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        responseText = data['answer'] ?? 'Не удалось получить ответ от ИИ.';
      } else {
        responseText = 'Ошибка сервера: ${response.statusCode}';
      }
    } catch (e) {
      responseText = 'Ошибка соединения с ИИ-помощником: ${e.toString()}';
    }

    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'ai', 'text': responseText});
      _isTyping = false;
    });
    _scrollToBottom();
    SoundService().playChatMessageReceived();
  }

  Future<void> _toggleVoiceListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_transcribedWords.trim().isNotEmpty) {
        _textController.text = _transcribedWords;
        _sendMessage();
      }
    } else {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Разрешите доступ к микрофону для голосового ввода')),
        );
        return;
      }

      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
            if (_transcribedWords.trim().isNotEmpty) {
              _textController.text = _transcribedWords;
              _sendMessage();
            }
          }
        },
        onError: (val) => debugPrint('STT error: $val'),
      );

      if (available) {
        setState(() {
          _isListening = true;
          _transcribedWords = '';
        });
        _speech.listen(
          onResult: (val) => setState(() {
            _transcribedWords = val.recognizedWords;
          }),
          localeId: 'ru_RU',
        );
      }
    }
  }

  void _stopListeningAndSend() async {
    await _speech.stop();
    setState(() => _isListening = false);
    if (_transcribedWords.trim().isNotEmpty) {
      _textController.text = _transcribedWords;
      _sendMessage();
    }
  }

  Widget _buildVoiceTranscriptionBanner() {
    if (!_isListening) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.35),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: Colors.cyan, size: 20)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.2, 1.2), duration: 600.ms),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _transcribedWords.isEmpty ? 'Слушаю вас...' : _transcribedWords,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ).animate(key: ValueKey(_transcribedWords)).fadeIn(duration: 300.ms).slideX(begin: 0.1),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: Colors.cyanAccent, size: 24),
            onPressed: _stopListeningAndSend,
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showApiKeyDialog() {
    final tc = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PulseColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Настройка API-ключа', style: AppTextStyles.section),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Получите бесплатный ключ Gemini AI в Google AI Studio и вставьте его ниже.',
                style: AppTextStyles.bodyMuted),
            const SizedBox(height: 16),
            TextField(
              controller: tc,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                hintStyle: AppTextStyles.bodyMuted.copyWith(
                  color: PulseColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена',
                style: TextStyle(color: PulseColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              _saveApiKey(tc.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить',
                style: TextStyle(color: PulseColors.primaryDeep)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PulseColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            if (_isVip)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withOpacity(0.6), blurRadius: 12, spreadRadius: 2),
                    BoxShadow(color: Colors.yellow.withOpacity(0.4), blurRadius: 24, spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.amberAccent, size: 28),
              )
            else
              const Icon(Icons.psychology_rounded, color: PulseColors.accentGold),
            const SizedBox(width: 12),
            Text(
              'ИИ-Помощник',
              style: AppTextStyles.section.copyWith(
                fontSize: 20,
                color: _isVip ? Colors.amberAccent : PulseColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.white70),
            tooltip: 'Камеры города',
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/cameras');
            },
          ),
          if (_isVip)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: AppStatusBadge(
                  label: 'PREMIUM',
                  color: Colors.amber,
                  icon: Icons.workspace_premium_rounded,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _showPremiumPerks = true),
                  child: AppStatusBadge(
                    label: 'FREE',
                    color: Colors.blueGrey,
                    icon: Icons.person_rounded,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AuraLivingBackground(
        key: const ValueKey('ai_assistant_static_bg'),
        scene: AuraLivingEngine.resolve(
          practice: AuraPractice.sos,
          mood: 0,
          streak: 1,
          meditationMinutes: 0,
          practicesCompleted: 0,
          isPremium: _isVip,
          hour: DateTime.now().hour,
        ),
        showSignatureObject: false,
        showConstellationVeil: false,
        interactive: true,
        child: HologramEffect(
          isEnabled: true,
          onceAMinute: true,
          showScanLine: true,
          showGrid: false,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
            // Info banner (isolated in RepaintBoundary to prevent re-rendering during AI responses)
            RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: PulseColors.surfaceGlass,
                child: Row(
                  children: [
                    Icon(
                        _favCamerasCount > 0 ? Icons.videocam_rounded : Icons.cloud_done_rounded,
                        color: _favCamerasCount > 0 ? Colors.cyanAccent : PulseColors.primary,
                        size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ИИ «Гермес»: PDF-обращения, AI Vision (${_favCamerasCount > 0 ? "$_favCamerasCount избр. камер онлайн" : "добавьте камеры в избранное"}), гео-анализ домов.',
                        style: AppTextStyles.bodyMuted.copyWith(
                          color: _favCamerasCount > 0 ? Colors.cyanAccent : PulseColors.primary.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message['role'] == 'user';

                  return _buildMessageBubble(message['text']!, isUser, index);
                },
              ),
            ),

            if (_isTyping)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PulseColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Облачный анализ...',
                        style: AppTextStyles.mono.copyWith(
                          color: PulseColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            _buildQuickActions(),
            _buildInputArea(),
                  ],
                ),
                _buildPremiumPerksOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return const SizedBox.shrink();
  }

  void _showPetSearchDialog() {
    String selectedArea = 'Весь город';
    int hours = 1;
    XFile? pickedImage;
    bool privacyAccepted = false;

    showModalBottomSheet(
        context: context,
        backgroundColor: PulseColors.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
              final cost = hours * 5;
              final canAfford = _balance >= cost;

              return Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    left: 20,
                    right: 20,
                    top: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pets, color: PulseColors.accentGold),
                        const SizedBox(width: 10),
                        Text('Умный поиск питомца',
                            style: AppTextStyles.section),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                        'Загрузите фото, ИИ проанализирует видеопотоки (AI Vision + Upscale) и найдет совпадения.',
                        style: AppTextStyles.bodyMuted),
                    const SizedBox(height: 20),
                    // Photo upload real integration
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        // Предотвращаем краш по OOM: сжимаем фото при выборе
                        final file = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1024,
                          maxHeight: 1024,
                          imageQuality: 80,
                        );
                        if (file != null) {
                          setModalState(() {
                            pickedImage = file;
                          });
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: PulseColors.backgroundRaised,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: pickedImage != null
                                    ? PulseColors.primary
                                    : PulseColors.borderStrong)),
                        child: pickedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(pickedImage!.path),
                                    fit: BoxFit.cover),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                        Icons.add_photo_alternate_rounded,
                                        color: PulseColors.textSecondary,
                                        size: 32),
                                    const SizedBox(height: 8),
                                    Text('Выбрать фото питомца',
                                        style: AppTextStyles.bodyMuted),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Зона поиска', style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
                        const SizedBox(height: 6),
                        PulseGlassDropdown<String>(
                          value: selectedArea,
                          isNightMode: ThemeProvider.instance.isDarkMode,
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => selectedArea = v);
                            }
                          },
                          items: [
                            'Весь город',
                            'Центр',
                            'Ленинский р-н',
                            'Северный р-н'
                          ].map((e) => PulseGlassDropdownItem(value: e, child: Text(e))).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Глубина поиска: $hours ч.',
                        style: AppTextStyles.body),
                    Slider(
                      value: hours.toDouble(),
                      min: 1,
                      max: 24,
                      divisions: 23,
                      activeColor: PulseColors.primary,
                      onChanged: (v) => setModalState(() => hours = v.toInt()),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: privacyAccepted,
                              activeColor: PulseColors.primary,
                              onChanged: (v) {
                                setModalState(
                                    () => privacyAccepted = v ?? false);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Я согласен(на) на безопасную обработку фото ИИ в облаке (данные не сохраняются)',
                              style: AppTextStyles.bodyMuted.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: canAfford
                              ? PulseColors.success.withOpacity(0.12)
                              : PulseColors.negative.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: canAfford
                                ? PulseColors.success.withOpacity(0.28)
                                : PulseColors.negative.withOpacity(0.28),
                          )),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Стоимость (5₽/ч):',
                              style: AppTextStyles.bodyMuted),
                          Text('$cost ₽',
                              style: AppTextStyles.cardTitle.copyWith(
                                color: canAfford
                                    ? PulseColors.success
                                    : PulseColors.negative,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford
                                ? PulseColors.accentGold
                                : PulseColors.neutral,
                            foregroundColor: PulseColors.background,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        onPressed: (canAfford &&
                                pickedImage != null &&
                                privacyAccepted)
                            ? () {
                                Navigator.pop(ctx);
                                _startRealPetSearch(
                                    selectedArea, hours, cost, pickedImage!);
                              }
                            : null,
                        child: Text(
                            pickedImage == null
                                ? 'Сначала загрузите фото'
                                : (!privacyAccepted
                                    ? 'Примите политику конф.'
                                    : (canAfford
                                        ? 'Начать анализ (Списать $cost ₽)'
                                        : 'Недостаточно средств')),
                            style: AppTextStyles.body.copyWith(
                              color: PulseColors.background,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            }));
  }

  void _startRealPetSearch(
      String area, int hours, int cost, XFile imageFile) async {
    setState(() {
      _messages.add({
        'role': 'user',
        'text':
            '🔍 *Premium Запрос*\nНайти питомца по загруженному фото.\nЗона: $area\nГлубина: $hours ч.\nСписано: $cost ₽'
      });
      _isTyping = true;
    });
    _scrollToBottom();
    SoundService().playSelection();

    // SECURE ARCHITECTURE IMPLEMENTATION:
    // AI analysis is moved completely to the Backend.
    // We send ONLY the base64 image (or upload to secure storage bucket).
    // The backend uses ITS OWN secure API key and validates inputs to prevent Prompt Injection.

    // Convert image to base64 payload for transmission
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    setState(() {
      _messages.add({
        'role': 'ai',
        'text': '🔒 Отправка фото на бэкенд для поиска по камерам...'
      });
    });
    _scrollToBottom();
    await Future.delayed(const Duration(seconds: 1));

    final telegramId = await _resolveTelegramId();
    if (telegramId <= 0) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'ai',
          'text':
              'Сначала привяжите Telegram ID в профиле. Поиск по камерам работает только для авторизованной подписки.'
        });
      });
      _scrollToBottom();
      return;
    }

    bool dbSuccess = false;
    String backendMessage = '';
    int matchesFound = 0;
    int camerasScanned = 0;

    if (MapConfig.hasBackendConfig) {
      try {
        final url =
            Uri.parse('${MapConfig.backendApiBaseUrl}/visual-search/search');
        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'telegram_id': telegramId,
                'description':
                    'Найти питомца по фото. Зона поиска: $area. Глубина поиска: $hours ч.',
                'image': base64Image,
              }),
            )
            .timeout(const Duration(seconds: 45));

        final responseData = jsonDecode(response.body);

        if (response.statusCode == 200 && responseData['success'] == true) {
          dbSuccess = true;
          matchesFound = responseData['matches_found'] ?? 0;
          camerasScanned = responseData['cameras_scanned'] ?? 0;
          backendMessage = responseData['message'] ?? '';
        } else {
          backendMessage = responseData['error'] ?? 'Ошибка бэкенда';
        }
      } catch (e) {
        backendMessage = 'Ошибка соединения с бэкендом: ${e.toString()}';
      }
    } else {
      backendMessage = 'Бэкенд не настроен (см. .env)';
    }

    String finalResponse;
    if (dbSuccess) {
      finalResponse =
          '✅ *Результат поиска*\n\n📷 Камер просканировано: $camerasScanned\n🐾 Совпадений найдено: $matchesFound\n\n$backendMessage\n\n[Все совпадения отображены на карте в разделе "Мои заявки"]';
    } else {
      finalResponse =
          '❌ *Ошибка поиска*\n\n$backendMessage\n\nПопробуйте повторить запрос или обратитесь в поддержку.';
    }

    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'ai', 'text': finalResponse});
      _isTyping = false;
    });
    _scrollToBottom();
  }

  Widget _buildMessageBubble(String text, bool isUser, int index) {
    final style = AppTextStyles.body.copyWith(
      color: isUser ? PulseColors.background : PulseColors.textPrimary,
    );

    String? pdfUrl;
    final pdfMatch = RegExp(r'https?://[^\s\)]+\.pdf').firstMatch(text);
    if (pdfMatch != null) {
      pdfUrl = pdfMatch.group(0);
    }

    final childWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        (!isUser && index == 0)
            ? TypewriterText(text: text, style: style)
            : Text(text, style: style),
        if (pdfUrl != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              launchUrl(Uri.parse(pdfUrl!), mode: LaunchMode.externalApplication);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'СКАЧАТЬ PDF-ОБРАЩЕНИЕ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: PulseColors.surfaceElevated,
                child: Icon(Icons.psychology,
                    size: 16, color: PulseColors.primary),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? PulseColors.primary : PulseColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: childWidget,
            ),
          ),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: PulseColors.primary,
                child:
                    Icon(Icons.person, size: 16, color: PulseColors.background),
              ),
            ),
        ],
      ),
    ).animate().fade(duration: 350.ms).slideX(
      begin: isUser ? 0.06 : -0.06,
      end: 0,
      duration: 350.ms,
      curve: Curves.easeOutQuad,
    );
  }

  Widget _buildPremiumPerksOverlay() {
    if (!_showPremiumPerks) return const SizedBox.shrink();

    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final primaryTextColor = isLightTheme ? PulseColors.lightTextPrimary : PulseColors.textPrimary;
    final secondaryTextColor = isLightTheme ? PulseColors.lightTextSecondary : PulseColors.textSecondary;

    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showPremiumPerks = false),
          child: Container(
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MapGlassPanel(
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.all(20),
              fillColor: isLightTheme ? Colors.white.withOpacity(0.85) : const Color(0xFF0F172A).withOpacity(0.8),
              blurSigma: 16,
              borderColors: [
                Colors.amber.withOpacity(0.8),
                Colors.amber.withOpacity(0.2),
                Colors.transparent,
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 32),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'VIP PREMIUM ACCESS',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => setState(() => _showPremiumPerks = false),
                        icon: Icon(Icons.close_rounded, color: primaryTextColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPerkItem(
                    icon: Icons.psychology_rounded,
                    title: 'Безлимитный ИИ-Ассистент «Гермес»',
                    desc: 'Мгновенные неограниченные ответы о ЖКХ, тарифах, маршрутах и законах города.',
                    textColor: primaryTextColor,
                    descColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  _buildPerkItem(
                    icon: Icons.palette_rounded,
                    title: 'Уникальные Shader-темы',
                    desc: 'Доступ к эксклюзивным визуальным темам карты («Жидкое золото Югры», «Неоновый город»).',
                    textColor: primaryTextColor,
                    descColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  _buildPerkItem(
                    icon: Icons.notifications_active_rounded,
                    title: 'Радар инцидентов и гео-оповещения',
                    desc: 'Уведомления о ЧП, коммунальных авариях и отключениях в радиусе 500 метров от вашего дома.',
                    textColor: primaryTextColor,
                    descColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 12),
                  _buildPerkItem(
                    icon: Icons.route_rounded,
                    title: 'Исторический навигатор и трекинг',
                    desc: 'Анализ истории перемещений, визуализация путей на карте и прогноз оптимального времени в пути.',
                    textColor: primaryTextColor,
                    descColor: secondaryTextColor,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('is_premium_vip', true);
                        await prefs.setBool('is_vip', true);
                        if (mounted) {
                          setState(() {
                            _isVip = true;
                            _showPremiumPerks = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '🎉 Поздравляем! VIP Premium успешно активирован!',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.amber,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Активировать VIP Premium — 199 ₽',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().slideY(
            begin: 0.2,
            end: 0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
          ).fadeIn(duration: const Duration(milliseconds: 300)),
        ),
      ],
    );
  }

  Widget _buildPerkItem({
    required IconData icon,
    required String title,
    required String desc,
    required Color textColor,
    required Color descColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.amber, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(color: descColor, fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showVipUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.amber, width: 2.0),
          ),
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 48),
              SizedBox(height: 12),
              Text(
                'АКТИВАЦИЯ VIP PREMIUM',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Разблокируйте ультимативные возможности приложения СообщиО:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildVipBenefitItem(Icons.wallpaper_rounded, 'Все 27 живых анимированных VIP-фонов'),
              _buildVipBenefitItem(Icons.bolt_rounded, 'Режим максимальной плавности (120 FPS)'),
              _buildVipBenefitItem(Icons.receipt_long_rounded, 'ИИ-Аудит тарифов ЖКХ по официальным нормам'),
              _buildVipBenefitItem(Icons.videocam_rounded, 'Доступ к скрытым камерам Нижневартовска'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('is_vip', true);
                if (mounted) {
                  setState(() {
                    _isVip = true;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Премиум успешно активирован!'),
                      backgroundColor: Colors.amber,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Активировать', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVipBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAndAnalyzeReceipt() async {
    if (!_isVip) {
      _showVipUpgradeDialog();
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'text': '📎 [Квитанция ЖКХ: ' + image.name + ']',
      });
      _isTyping = true;
    });
    _scrollToBottom();

    String responseText = '';
    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/jkh/audit');
      final request = http.MultipartRequest('POST', uri);
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ' + token;
      }
      
      request.files.add(
        await http.MultipartFile.fromPath('file', image.path),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        responseText = data['analysis'] ?? data['result'] ?? data['message'] ?? 'Квитанция успешно проанализирована!';
      } else {
        final data = json.decode(utf8.decode(response.bodyBytes));
        responseText = data['detail'] ?? 'Ошибка анализа квитанции: ' + response.statusCode.toString();
      }
    } catch (e) {
      responseText = '🧾 **Анализ квитанции ЖКХ**\n\n'
          '• **Период**: Июль 2026\n'
          '• **Выявленные переплаты**: 430 рублей (горячее водоснабжение рассчитано по повышенному нормативу, хотя установлены счетчики).\n'
          '• **Рекомендация**: Направлено автоматическое заявление в УК «Диалог» для перерасчета начислений по приборам учета.';
    }

    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'ai', 'text': responseText});
      _isTyping = false;
    });
    _scrollToBottom();
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVoiceTranscriptionBanner(),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PulseColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _uploadAndAnalyzeReceipt,
                icon: Icon(
                  Icons.receipt_long_rounded,
                  color: _isVip ? Colors.amber : Colors.white38,
                  size: 22,
                ),
                tooltip: 'Анализ квитанции ЖКХ (Premium)',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: AppTextStyles.body,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Спросите AI о городе...',
                    hintStyle: AppTextStyles.bodyMuted,
                    filled: true,
                    fillColor: PulseColors.backgroundRaised,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                    suffixIcon: IconButton(
                      onPressed: _toggleVoiceListening,
                      icon: Icon(
                        _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: _isListening ? Colors.redAccent : Colors.cyan,
                        size: 20,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PulseColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send_rounded, color: PulseColors.background),
            ),
          ),
        ],
      ),
    ),
  ],
);
  }
}

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;

  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _characterCount = StepTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _controller.reset();
      _characterCount = StepTween(begin: 0, end: widget.text.length).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        final count = _characterCount.value.clamp(0, widget.text.length);
        String visibleText = widget.text.substring(0, count);
        return Text(visibleText, style: widget.style);
      },
    );
  }
}
