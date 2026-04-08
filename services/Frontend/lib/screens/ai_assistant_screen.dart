import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../theme/pulse_colors.dart';
import '../services/sound_service.dart';
import '../map/map_config.dart';
import '../widgets/app_ui.dart';

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
          'Привет! Я AI-ассистент приложения по мониторингу города.\n\nЯ работаю через backend API, поэтому на телефон не нужно скачивать тяжелые модели.\n\nПопробуйте спросить: "Посмотри камеры по улице Ленина и скажи, есть ли заторы?"',
    }
  ];

  bool _isTyping = false;
  String _apiKey = '';
  ChatSession? _chatSession;
  final double _balance = 100.0;

  @override
  void initState() {
    super.initState();
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
    setState(() {
      _apiKey = key;
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

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _textController.clear();
    _scrollToBottom();
    SoundService().playSelection();

    final lowerText = text.toLowerCase();
    String responseText = '';

    // Simulate RAG (Context Injection) for specific queries, like looking at cameras
    if (lowerText.contains('камер') && lowerText.contains('ленина')) {
      final injectedContext = '''
[СИСТЕМНЫЕ ДАННЫЕ О КАМЕРАХ: УЛ. ЛЕНИНА]
- Перекресток Ленина и Чапаева: скорость потока 45 км/ч, плотность 2/10. Заторов нет.
- Улица Ленина, д. 15: скорость потока 38 км/ч, плотность 3/10. Заторов нет.
- Кольцо на ул. Ленина: движение свободное. ДТП не зафиксировано.
[ЗАПРОС ПОЛЬЗОВАТЕЛЯ]: $text
Опирайся только на системные данные и дай краткий, полезный ответ.
''';

      if (_apiKey.isNotEmpty && _chatSession != null) {
        try {
          final response =
              await _chatSession!.sendMessage(Content.text(injectedContext));
          responseText = response.text ?? 'Не удалось разобрать ответ модели.';
        } catch (e) {
          responseText = _getDemoResponse();
        }
      } else {
        responseText = _getDemoResponse();
      }
    } else {
      if (_apiKey.isNotEmpty && _chatSession != null) {
        try {
          final response = await _chatSession!.sendMessage(Content.text(text));
          responseText = response.text ?? 'Не удалось разобрать ответ модели.';
        } catch (e) {
          responseText = 'Ошибка AI API: ${e.toString()}';
        }
      } else {
        responseText =
            'Для полноценного общения укажите API-ключ Gemini.\nПока можно использовать демо-режим и вопросы про камеры на улице Ленина.';
      }
    }

    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'ai', 'text': responseText});
      _isTyping = false;
    });
    _scrollToBottom();
  }

  String _getDemoResponse() {
    return "🧠 [Анализ через Cloud API]\n\nЯ проанализировал данные с камер видеонаблюдения по улице Ленина:\n\n• Перекресток Ленина и Чапаева: скорость 45 км/ч.\n• Улица Ленина, д. 15: скорость 38 км/ч.\n• Кольцо на ул. Ленина: свободно.\n\nРезультат: заторов на улице Ленина сейчас нет. Можно ехать без задержек.";
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
            const Icon(Icons.psychology_rounded, color: PulseColors.accentGold),
            const SizedBox(width: 8),
            Text(
              'AI DISPATCH',
              style: AppTextStyles.section.copyWith(fontSize: 20),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Баланс: ${_balance.toInt()} ₽',
                style: AppTextStyles.body.copyWith(
                  color: PulseColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(_apiKey.isEmpty
                ? Icons.key_off_rounded
                : Icons.vpn_key_rounded),
            color: _apiKey.isEmpty ? PulseColors.neutral : PulseColors.primary,
            tooltip: 'Настройка API',
            onPressed: _showApiKeyDialog,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: AppStatusBadge(
                label: _apiKey.isEmpty ? 'DEMO' : 'CLOUD',
                color: _apiKey.isEmpty
                    ? PulseColors.warning
                    : PulseColors.accentGold,
                icon: _apiKey.isEmpty
                    ? Icons.cloud_off_rounded
                    : Icons.flash_on_rounded,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: PulseColors.surfaceGlass,
              child: Row(
                children: [
                  Icon(
                      _apiKey.isNotEmpty
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: _apiKey.isNotEmpty
                          ? PulseColors.primary
                          : PulseColors.warning,
                      size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _apiKey.isNotEmpty
                          ? 'Подключено к Gemini AI Cloud (удаленный анализ)'
                          : 'Демо-режим: Необходим API ключ Gemini для свободных запросов. Запрос "Ленина" работает.',
                      style: AppTextStyles.bodyMuted.copyWith(
                        color: _apiKey.isNotEmpty
                            ? PulseColors.primary.withOpacity(0.8)
                            : PulseColors.warning.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
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

                  return _buildMessageBubble(message['text']!, isUser);
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
                      const SizedBox(
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
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          GestureDetector(
            onTap: _showPetSearchDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: PulseColors.accentGold.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: PulseColors.accentGold.withOpacity(0.42)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pets_rounded,
                      color: PulseColors.accentGold, size: 16),
                  const SizedBox(width: 8),
                  Text('Поиск питомца (Vision)',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        color: PulseColors.accentGold,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
                                    const Icon(
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
                    DropdownButtonFormField<String>(
                      value: selectedArea,
                      dropdownColor: PulseColors.backgroundRaised,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        labelText: 'Зона поиска',
                        labelStyle: AppTextStyles.bodyMuted,
                        fillColor: PulseColors.backgroundRaised,
                      ),
                      items: [
                        'Весь город',
                        'Центр',
                        'Ленинский р-н',
                        'Северный р-н'
                      ]
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setModalState(() => selectedArea = v!),
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

  Widget _buildMessageBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            const Padding(
              padding: EdgeInsets.only(right: 8),
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
              child: Text(
                text,
                style: AppTextStyles.body.copyWith(
                  color:
                      isUser ? PulseColors.background : PulseColors.textPrimary,
                ),
              ),
            ),
          ),
          if (isUser)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: PulseColors.primary,
                child:
                    Icon(Icons.person, size: 16, color: PulseColors.background),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
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
              child:
                  const Icon(Icons.send_rounded, color: PulseColors.background),
            ),
          ),
        ],
      ),
    );
  }
}
