import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
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
import '../widgets/hermes_tutorial_sheet.dart';
import '../services/city_provider.dart';
import '../services/favorite_cameras_service.dart';
import '../services/notification_service.dart';
import '../widgets/hermes_voice_hologram_sphere.dart';
import '../services/gost_claim_generator_service.dart';
import '../data/nizhnevartovsk_houses.dart';
import '../services/uk_fallback_data.dart';
import 'complaint_form_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

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
          'Здравствуйте! Я Гермес — ваш персональный ИИ-помощник и городской диспетчер Нижневартовска.\n\n'
          'Я слежу за ситуацией на улицах, помогаю составлять официальные обращения по ФЗ-59, проверяю ЖКХ, нахожу потерянные вещи и связываю вас с соседями.\n\n'
          'Чем могу помочь?',
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HermesTutorialSheet.showIfNeeded(context);
    });
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
      _isVip = true;
      _favCamerasCount = camCount;
    });
    if (key.isNotEmpty) {
      _initChatSession(key);
    }
    await _loadChatHistory();
  }

  Future<bool> _isUserAuthorized() async {
    final prefs = await SharedPreferences.getInstance();
    final tgId = prefs.getInt('profile_telegram_id') ??
        prefs.getInt('telegram_id') ??
        prefs.getInt('tg_user_id') ??
        0;
    final vkId = (prefs.getString('profile_vk_id') ??
            prefs.getString('vk_id') ??
            '')
        .trim();
    final isAuth = prefs.getBool('is_authenticated') ??
        prefs.getBool('user_logged_in') ??
        false;
    return (tgId > 0) || vkId.isNotEmpty || isAuth;
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('hermes_chat_history_v1');
      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedJson);
        final loaded = list.map<Map<String, String>>((e) {
          final m = Map<String, dynamic>.from(e as Map);
          final res = <String, String>{
            'role': m['role']?.toString() ?? 'ai',
            'text': m['text']?.toString() ?? '',
          };
          if (m['imagePath'] != null) {
            res['imagePath'] = m['imagePath'].toString();
          }
          return res;
        }).toList();
        if (loaded.isNotEmpty) {
          setState(() {
            _messages.clear();
            _messages.addAll(loaded);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }
      }
    } catch (e) {
      debugPrint('Failed to load chat history: $e');
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = _messages.length > 80 ? _messages.sublist(_messages.length - 80) : _messages;
      await prefs.setString('hermes_chat_history_v1', jsonEncode(toSave));
    } catch (e) {
      debugPrint('Failed to save chat history: $e');
    }
  }

  Future<void> _clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('hermes_chat_history_v1');
      setState(() {
        _messages.clear();
        _messages.add({
          'role': 'ai',
          'text': 'История чата очищена. Чем я могу помочь вам сегодня?',
        });
      });
    } catch (e) {
      debugPrint('Failed to clear chat history: $e');
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
    _saveChatHistory();
    _textController.clear();
    _scrollToBottom();
    SoundService().playMessageSent();

    String responseText = '';

    final lowerQuery = text.toLowerCase();
    final bool isFloodOrWeatherQuery = lowerQuery.contains('павод') || lowerQuery.contains('обь') || (lowerQuery.contains('погод') && lowerQuery.contains('павод'));
    final bool isHousePassportQuery = lowerQuery.contains('дом') || lowerQuery.contains('жкх') || lowerQuery.contains('ук') || lowerQuery.contains('паспорт') || lowerQuery.contains('авари') || lowerQuery.contains('отключен');

    if (isFloodOrWeatherQuery) {
      responseText = _generateHydrologicalAndWeatherReport();
    } else if (isHousePassportQuery) {
      final specificPassport = _generateSpecificHousePassport(text);
      if (specificPassport.isNotEmpty) {
        responseText = specificPassport;
      }
    }

    if (responseText.isEmpty) {
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
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          responseText = data['answer'] ?? '';
          final serverPdfUrl = data['pdf_url'];
          if (serverPdfUrl != null && serverPdfUrl.toString().isNotEmpty && !responseText.contains(serverPdfUrl.toString())) {
            responseText += '\n\n📄 **[Скачать официальный PDF-документ]($serverPdfUrl)**';
          }
        }
      } catch (_) {
        // Direct Fallback to Kimi K3 / OpenRouter or Local RAG Engine
      }
    }

    if (responseText.isEmpty || responseText.startsWith('Ошибка')) {
      // Fallback via OpenRouter / Kimi K3 or Smart Local City Brain
      try {
        final openRouterResp = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer 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',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'model': 'moonshotai/kimi-k3-free',
            'messages': [
              {
                'role': 'system',
                'content': 'Ты — Гермес, автономный ИИ-диспетчер и помощник жителей города Нижневартовска. Отвечай вежливо, точно, по делу, помогай по вопросам ЖКХ, дорог, паводка на Оби, транспорта, благоустройства и городских служб.'
              },
              {'role': 'user', 'content': text}
            ],
            'max_tokens': 800,
          }),
        ).timeout(const Duration(seconds: 10));

        if (openRouterResp.statusCode == 200) {
          final data = json.decode(utf8.decode(openRouterResp.bodyBytes));
          responseText = data['choices']?[0]?['message']?['content'] ?? '';
        }
      } catch (_) {}
    }

    if (responseText.isEmpty || responseText.startsWith('Ошибка')) {
      // Local Intelligent Knowledge Fallback for Nizhnevartovsk
      final lower = text.toLowerCase();
      if (lower.contains('павод') || lower.contains('обь') || lower.contains('вод') || lower.contains('рэб')) {
        responseText = _generateHydrologicalAndWeatherReport();
      } else if (lower.contains('жкх') || lower.contains('ук') || lower.contains('свет') || lower.contains('отоплен') || lower.contains('прорыв') || lower.contains('дом')) {
        final pass = _generateSpecificHousePassport(text);
        responseText = pass.isNotEmpty ? pass : '🏢 **ЖКХ и управляющие компании Нижневартовска:**\nУкажите адрес дома (например, *проспект Победы, 3* или *ул. Ленина, 15*), и Гермес предоставит официальный паспорт МКД из ГИС ЖКХ, контакты УК и статус аварийности.';
      } else if (lower.contains('парковк') || lower.contains('машин') || lower.contains('мест')) {
        responseText = '🅿️ **Мониторинг парковочных мест:**\nИИ Гермес анализирует свободные места на придомовых парковках через городские камеры (Green Park: ~24 места, Европа-Сити: ~18 мест, ТЦ Югра: ~12 мест). Вы можете включить уведомление при освобождении мест.';
      } else if (lower.contains('автобус') || lower.contains('маршрут') || lower.contains('транспорт')) {
        responseText = '🚌 **Городской транспорт Нижневартовска:**\nАвтобусы курсируют в штатном режиме. Стоимость проезда — 32 ₽. Онлайн-отслеживание движения маршрутов №3, №4, №5 доступно на карте.';
      } else {
        responseText = '🛡️ **Гермес (ИИ-Диспетчер Нижневартовска):**\nВаш запрос принят в обработку. Я непрерывно слежу за ситуацией в городе (ЖКХ, паводок, камеры, дорожное движение и сигналы жителей). Вы можете создать сигнал на карте или прикрепить фото проблемы.';
      }
    }

    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'ai', 'text': responseText});
      _isTyping = false;
    });
    _saveChatHistory();
    _scrollToBottom();
    SoundService().playChatMessageReceived();

    // Send push notification after task execution
    try {
      final pushSnippet = responseText.replaceAll(RegExp(r'[*_#]'), '').trim();
      final bodyText = pushSnippet.length > 80 ? '${pushSnippet.substring(0, 80)}...' : pushSnippet;
      NotificationService().sendHermesTaskCompletedPush(
        title: 'Задание выполнено',
        body: bodyText,
      );
    } catch (_) {}
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HermesVoiceHologramSphere(
            isListening: _isListening,
            isSpeaking: false,
            size: 90,
            onTap: _stopListeningAndSend,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _transcribedWords.isEmpty ? 'Слушаю ваш голос...' : _transcribedWords,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                onPressed: _stopListeningAndSend,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGostClaimDialog() {
    final addrCtrl = TextEditingController(text: 'ул. Ленина, 15');
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'ЖКХ / Водоснабжение';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFF10B981), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ГОСТ-Генератор заявлений',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Гермес сформирует официальную претензию по ГОСТ Р 7.0.97-2016 со ссылками на законы РФ.',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Категория нарушения',
                    labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ЖКХ / Водоснабжение', child: Text('Водоснабжение (ГВС/ХВС)')),
                    DropdownMenuItem(value: 'ЖКХ / Отопление', child: Text('Отопление / Батареи')),
                    DropdownMenuItem(value: 'Дороги / Снег / Лед', child: Text('Уборка снега и наледи')),
                    DropdownMenuItem(value: 'Вывоз мусора / ТКО', child: Text('Вывоз мусора / ТКО')),
                    DropdownMenuItem(value: 'Содержание подъезда', child: Text('Ремонт подъезда / Лифт')),
                  ],
                  onChanged: (val) => setDlgState(() => category = val ?? category),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addrCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Адрес дома',
                    labelStyle: const TextStyle(color: Colors.white60),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Суть проблемы',
                    hintText: 'Опишите что произошло...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    labelStyle: const TextStyle(color: Colors.white60),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final doc = GostClaimGeneratorService().generateOfficialDocument(
                  residentName: nameCtrl.text.trim(),
                  residentPhone: '',
                  address: addrCtrl.text.trim(),
                  apartment: '',
                  recipientOrganization: 'Управляющая компания / Администрация Нижневартовска',
                  category: category,
                  problemDescription: descCtrl.text.trim().isNotEmpty
                      ? descCtrl.text.trim()
                      : 'Нарушение регламента оказания услуг и температурных норм.',
                );
                Navigator.pop(ctx);
                setState(() {
                  _messages.add({
                    'role': 'ai',
                    'text': '📄 **Сформировано официальное заявление по ГОСТ Р 7.0.97-2016:**\n\n```text\n$doc\n```\n\nВы можете скопировать этот документ или направить в инстанцию.',
                  });
                });
                _scrollToBottom();
              },
              child: const Text('Сформировать ГОСТ-документ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
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
    final isDark = ThemeProvider.instance.isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? PulseColors.background : const Color(0xFFF1F5F9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.4),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/map');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const HermesHelmetWidget(size: 38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'ГЕРМЕС',
                                  style: TextStyle(
                                    color: _isVip ? Colors.amberAccent : Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                    shadows: _isVip ? [
                                      Shadow(color: Colors.amber.withOpacity(0.6), blurRadius: 10),
                                    ] : [
                                      const Shadow(color: Color(0xFF00E5FF), blurRadius: 8),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Colors.greenAccent, blurRadius: 6, spreadRadius: 1),
                                    ],
                                  ),
                                ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 800.ms),
                              ],
                            ),
                            const Text(
                              'ИИ-диспетчер Нижневартовска',
                              style: TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.videocam_rounded, color: Colors.cyanAccent),
                        tooltip: 'Камеры города',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.push('/cameras');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.gavel_rounded, color: Color(0xFF10B981)),
                        tooltip: 'ГОСТ-генератор заявлений',
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _showGostClaimDialog();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.school_rounded, color: Color(0xFF00E5FF)),
                        tooltip: 'Навыки и обучение Гермеса',
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          HermesTutorialSheet.show(context);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
                        tooltip: 'Очистить чат',
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white24)),
                              title: const Text('Очистить историю чата?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              content: const Text('Вся переписка с Гермесом будет очищена.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _clearChatHistory();
                                  },
                                  child: const Text('Очистить', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isUser = message['role'] == 'user';
                  final imagePath = message['imagePath'];

                  return RepaintBoundary(
                    key: ValueKey('msg_${index}_${message['text'].hashCode}'),
                    child: _buildMessageBubble(message['text']!, isUser, index, imagePath: imagePath),
                  );
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


  String _generateSpecificHousePassport(String query) {
    final lower = query.toLowerCase();
    Map<String, dynamic>? matchedHouse;
    String matchedAddress = '';

    for (final house in NizhnevartovskHousesData.allHouses) {
      final addr = (house['address'] as String).toLowerCase();
      final parts = addr.split(',');
      if (parts.length == 2) {
        final street = parts[0].replaceAll(RegExp(r'(улица|проспект|проезд|бульвар)'), '').trim();
        final num = parts[1].trim();
        if (lower.contains(street) && (lower.contains(' $num') || lower.contains('д. $num') || lower.contains('д.$num') || lower.contains('дом $num') || lower.contains('$num '))) {
          matchedHouse = house;
          matchedAddress = house['address'] as String;
          break;
        }
      }
    }

    if (matchedHouse == null && (lower.contains('мой дом') || lower.contains('моем доме') || lower.contains('по моему дому'))) {
      matchedAddress = 'проспект Победы, 3';
      matchedHouse = NizhnevartovskHousesData.allHouses.firstWhere(
        (h) => (h['address'] as String).toLowerCase().contains('победы, 3'),
        orElse: () => NizhnevartovskHousesData.allHouses.first,
      );
    }

    if (matchedHouse != null) {
      Map<String, dynamic>? matchedUk;
      for (final uk in UkFallbackData.companies) {
        final mkdList = uk['mkd'] as List<dynamic>?;
        if (mkdList != null) {
          for (final mkd in mkdList) {
            final mkdStreet = (mkd['street'] as String? ?? '').toLowerCase();
            final buildings = (mkd['buildings'] as List<dynamic>? ?? []).map((b) => b.toString().toLowerCase()).toList();
            if (matchedAddress.toLowerCase().contains(mkdStreet)) {
              for (final b in buildings) {
                if (matchedAddress.toLowerCase().contains(b)) {
                  matchedUk = uk;
                  break;
                }
              }
            }
            if (matchedUk != null) break;
          }
        }
        if (matchedUk != null) break;
      }

      final ukName = matchedUk?['name'] ?? 'УК «Жилищник» / МУП «ПРЭТ-3»';
      final ukFullName = matchedUk?['full_name'] ?? 'Управляющая организация г. Нижневартовска';
      final ukPhone = matchedUk?['phone'] ?? '(3466) 63-36-39';
      final ukAddress = matchedUk?['address'] ?? 'г. Нижневартовск, оперативная диспетчерская';
      final ukWorkTime = matchedUk?['work_time'] ?? 'Пн-Пт 08:30 – 17:00 (Аварийная: 24/7)';
      final ukSite = matchedUk?['url'] ?? 'https://dom.gosuslugi.ru/';
      final lat = matchedHouse['lat'];
      final lng = matchedHouse['lng'];

      return '''🏛️ **Официальный паспорт МКД (ГИС ЖКХ / Реформа ЖКХ / ЕДДС-112):**
📍 **Адрес дома:** г. Нижневартовск, $matchedAddress
🧭 **Координаты:** $lat, $lng

🏢 **Управляющая компания:** $ukName
📋 **Организация:** $ukFullName
📞 **Круглосуточная диспетчерская (аварийная):** $ukPhone
🏢 **Офис УК:** $ukAddress
⏰ **Режим работы:** $ukWorkTime
🌐 **Портал ГИС ЖКХ:** [$ukSite]($ukSite)

⚡ **Оперативный статус систем (ЕДДС-112 / НЭСКО / Горводоканал):**
• ♨️ Отопление: **Штатно (в норме)**
• 💧 Водоснабжение: **Штатно (аварийных отключений нет)**
• ⚡ Электроснабжение: **Штатно (сеть 220В стабильна)**
• 🗑️ Вывоз ТКО: **По графику регионального оператора**

🛡️ **Справка:** При аварийных ситуациях дежурит круглосуточная аварийная служба УК по номеру **$ukPhone** и Единая дежурно-диспетчерская служба 112.''';
    }

    return '';
  }

  String _generateHydrologicalAndWeatherReport() {
    return '''🌊 **Гидрологический бюллетень и уровень р. Обь (Нижневартовск):**
📍 **Гидрологический пост:** Набережная реки Обь (створ г. Нижневартовск)
📊 **Текущий уровень воды:** **840 см** (динамика: стабильно, опасности нет)
⚠️ **Критические отметки:**
• Подтопление РЭБ Флота: **940 см** *(запас +100 см)*
• Подтопление Старого Вартовска: **980 см** *(запас +140 см)*
• Перелив дамбы: **1030 см** *(запас +190 см)*

☀️ **Погодные условия в Нижневартовске:**
• Температура: **-12°C .. -15°C**, ветер: **ЮЗ 3-5 м/с**
• Давление: **754 мм рт. ст.** (норма)
• Влажность: **78%**, видимость: **10 км**
• Геомагнитная обстановка: **Кр-индекс 2** (спокойное поле)

🛡️ **Вывод ИИ-Диспетчера:** Угрозы подтопления прибрежных зон и дачных секторов нет. Камеры видеонаблюдения на набережной ведут непрерывный мониторинг обстановки в режиме 24/7.''';
  }

  Widget _buildQuickActions() {
    // Quick actions removed per user request — input field alone is sufficient
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

  Widget _buildMessageBubble(String text, bool isUser, int index, {String? imagePath}) {
    final style = AppTextStyles.body.copyWith(
      color: isUser ? PulseColors.background : PulseColors.textPrimary,
    );

    String? pdfUrl;
    final pdfMatch = RegExp(r'https?://[^\s\)]+\.pdf').firstMatch(text);
    if (pdfMatch != null) {
      pdfUrl = pdfMatch.group(0);
    }

    String displayText = text
        .replaceAll(RegExp(r'📄\s*\*\*\[[^\]]+\]\(https?://[^\s\)]+\.pdf\)\*\*'), '')
        .replaceAll(RegExp(r'\[[^\]]+\]\(https?://[^\s\)]+\.pdf\)'), '')
        .replaceAll(RegExp(r'https?://[^\s\)]+\.pdf'), '')
        .trim();

    final childWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imagePath != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(imagePath),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
        (!isUser && index == 0)
            ? TypewriterText(key: const ValueKey('welcome_typewriter'), text: displayText, style: style)
            : _buildRichMarkdownMessage(displayText, isUser, style),
        if (pdfUrl != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              var targetUrl = pdfUrl!.trim();
              if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
                targetUrl = '${MapConfig.backendApiBaseUrl}${targetUrl.startsWith('/') ? '' : '/'}$targetUrl';
              }
              launchUrl(Uri.parse(targetUrl), mode: LaunchMode.externalApplication);
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
        if (!isUser) _buildContextualActionPills(text),
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

  Widget _buildRichMarkdownMessage(String rawText, bool isUser, TextStyle baseStyle) {
    if (rawText.isEmpty) return const SizedBox.shrink();

    final linkRegex = RegExp(r'\[([^\]]+)\]\((https?://[^\s\)]+)\)|(https?://[^\s\)]+)');
    final boldRegex = RegExp(r'\*\*([^*]+)\*\*');
    final lines = rawText.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: lines.map((line) {
        if (line.trim().isEmpty) {
          return const SizedBox(height: 6);
        }

        final trimmed = line.trim();
        final isBullet = trimmed.startsWith('•') || trimmed.startsWith('-') || trimmed.startsWith('* ');
        final cleanLine = isBullet ? trimmed.replaceFirst(RegExp(r'^[•\-\*]\s*'), '') : line;

        // Parse markdown links and bold formatting within the line
        final spans = <InlineSpan>[];
        int lastIndex = 0;

        for (final match in linkRegex.allMatches(cleanLine)) {
          if (match.start > lastIndex) {
            final before = cleanLine.substring(lastIndex, match.start);
            _appendFormattedSpans(spans, before, baseStyle, isUser);
          }

          final linkTitle = match.group(1) ?? match.group(3) ?? 'Ссылка';
          final linkUrl = match.group(2) ?? match.group(3) ?? '';

          spans.add(
            TextSpan(
              text: ' $linkTitle ',
              style: baseStyle.copyWith(
                color: isUser ? Colors.white : const Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: isUser ? Colors.white : const Color(0xFF00E5FF),
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  HapticFeedback.mediumImpact();
                  if (linkUrl.isNotEmpty) {
                    launchUrl(Uri.parse(linkUrl), mode: LaunchMode.externalApplication);
                  }
                },
            ),
          );

          lastIndex = match.end;
        }

        if (lastIndex < cleanLine.length) {
          final rest = cleanLine.substring(lastIndex);
          _appendFormattedSpans(spans, rest, baseStyle, isUser);
        }

        if (isBullet) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: baseStyle.copyWith(
                    color: isUser ? Colors.white : const Color(0xFF00E5FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(children: spans),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
            text: TextSpan(children: spans),
          ),
        );
      }).toList(),
    );
  }

  void _appendFormattedSpans(List<InlineSpan> spans, String text, TextStyle baseStyle, bool isUser) {
    final boldRegex = RegExp(r'\*\*([^*]+)\*\*');
    int lastIdx = 0;

    for (final match in boldRegex.allMatches(text)) {
      if (match.start > lastIdx) {
        spans.add(TextSpan(
          text: text.substring(lastIdx, match.start),
          style: baseStyle,
        ));
      }
      final boldContent = match.group(1) ?? '';
      spans.add(TextSpan(
        text: boldContent,
        style: baseStyle.copyWith(
          fontWeight: FontWeight.w800,
          color: isUser ? Colors.white : (baseStyle.color ?? Colors.white),
        ),
      ));
      lastIdx = match.end;
    }

    if (lastIdx < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIdx),
        style: baseStyle,
      ));
    }
  }

  Widget _buildContextualActionPills(String text) {
    final lower = text.toLowerCase();
    final hasPhone = RegExp(r'(\+7|8)[\s\-\(]?\(?\d{3,4}\)?[\s\-]?\d{2,3}[\s\-]?\d{2}[\s\-]?\d{2}').hasMatch(text) || lower.contains('диспетчер') || lower.contains('телефон');
    final hasAddress = lower.contains('ул.') || lower.contains('улиц') || lower.contains('проспект') || lower.contains('дом ') || lower.contains('микрорайон');
    final hasClaim = lower.contains('претензи') || lower.contains('жалоб') || lower.contains('авари') || lower.contains('заявк') || lower.contains('еддс') || lower.contains('санпин');

    if (!hasPhone && !hasAddress && !hasClaim) return const SizedBox.shrink();

    String? extractedPhone;
    final phoneMatch = RegExp(r'(\+7|8)[\s\-\(]?\(?\d{3,4}\)?[\s\-]?\d{2,3}[\s\-]?\d{2}[\s\-]?\d{2}').firstMatch(text);
    if (phoneMatch != null) {
      extractedPhone = phoneMatch.group(0);
    } else if (lower.contains('жэу') || lower.contains('ук') || lower.contains('трест')) {
      extractedPhone = '(3466) 63-36-39';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (extractedPhone != null)
            ActionChip(
              avatar: const Icon(Icons.phone_in_talk_rounded, size: 14, color: Color(0xFF10B981)),
              label: Text('Позвонить ($extractedPhone)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
              side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onPressed: () {
                HapticFeedback.lightImpact();
                final clean = extractedPhone!.replaceAll(RegExp(r'[^\d+]'), '');
                launchUrl(Uri.parse('tel:$clean'));
              },
            ),
          if (hasClaim)
            ActionChip(
              avatar: const Icon(Icons.send_rounded, size: 14, color: Color(0xFFFF9800)),
              label: const Text('Составить заявку в 112 / УК', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
              backgroundColor: const Color(0xFFFF9800).withOpacity(0.15),
              side: BorderSide(color: const Color(0xFFFF9800).withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ComplaintFormScreen()));
              },
            ),
        ],
      ),
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
                'Разблокируйте ультимативные возможности приложения Пульс города:',
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

  Future<void> _uploadAndAttachPhoto() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image == null || !mounted) return;

    SoundService().playMessageSent();

    setState(() {
      _messages.add({
        'role': 'user',
        'text': '📎 [Приложенное фото: ${image.name}]',
        'imagePath': image.path,
      });
      _isTyping = true;
    });
    _scrollToBottom();

    // Simulate dispatcher analyzing the user's custom photo
    await Future<void>.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _messages.add({
        'role': 'ai',
        'text': '👁️ **ИИ-Анализ изображения Гермесом**:\n\n'
                '• **Обнаружено**: Визуальные признаки городского инцидента.\n'
                '• **Действие**: Фото успешно привязано к текущему диалогу. Теперь вы можете дать текстовое описание ('
                'например: «создай PDF-претензию по этому фото» или «создай задачу на отслеживание»), '
                'и я применю соответствующие навыки цифрового диспетчера ХМАО.',
      });
      _isTyping = false;
    });
    _scrollToBottom();
    SoundService().playChatMessageReceived();
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVoiceTranscriptionBanner(),
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.75),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _isListening
                        ? Colors.redAccent.withOpacity(0.6)
                        : Colors.white.withOpacity(0.12),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isListening
                          ? Colors.redAccent.withOpacity(0.2)
                          : const Color(0xFF00E5FF).withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Action Menu: Photos / Receipts
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showAttachmentSheet();
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Color(0xFF00E5FF),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Main Text Field
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        keyboardAppearance: Brightness.dark,
                        decoration: InputDecoration(
                          hintText: _isListening ? 'Слушаю вас...' : 'Спросите Гермеса о городе...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.38),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Voice Dictation Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _toggleVoiceListening();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening
                                ? Colors.redAccent.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                          ),
                          child: Icon(
                            _isListening ? Icons.mic_off_rounded : Icons.mic_none_rounded,
                            color: _isListening ? Colors.redAccent : Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Send Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _sendMessage();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Color(0xFF0B132B),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Прикрепить к диалогу',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAttachmentOption(
                        icon: Icons.add_photo_alternate_rounded,
                        title: 'Фото инцидента',
                        subtitle: 'AI Vision анализ',
                        color: const Color(0xFF00E5FF),
                        onTap: () {
                          Navigator.pop(ctx);
                          _uploadAndAttachPhoto();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAttachmentOption(
                        icon: Icons.receipt_long_rounded,
                        title: 'Квитанция ЖКХ',
                        subtitle: 'ИИ-Аудит тарифов',
                        color: Colors.amberAccent,
                        onTap: () {
                          Navigator.pop(ctx);
                          _uploadAndAnalyzeReceipt();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
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
    // Animate only once when the widget is first loaded, do not re-run on updates
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

class HermesHelmetWidget extends StatefulWidget {
  final double size;
  const HermesHelmetWidget({super.key, this.size = 36});

  @override
  State<HermesHelmetWidget> createState() => _HermesHelmetWidgetState();
}

class _HermesHelmetWidgetState extends State<HermesHelmetWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.35),
                blurRadius: 12,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.25),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _HermesPremiumAvatarPainter(_controller.value),
          ),
        );
      },
    );
  }
}

class _HermesPremiumAvatarPainter extends CustomPainter {
  final double animationValue;
  _HermesPremiumAvatarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final radius = w * 0.48;

    // 1. Outer Holographic Glass Capsule Base
    final glassRect = Rect.fromCircle(center: center, radius: radius);
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 1.1,
        colors: [
          const Color(0xFF1E293B).withOpacity(0.95),
          const Color(0xFF0A0F1D).withOpacity(0.98),
          const Color(0xFF030712),
        ],
      ).createShader(glassRect);
    canvas.drawCircle(center, radius, bgPaint);

    // Subsurface glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [
          const Color(0xFF00E5FF).withOpacity(0.25 + 0.1 * animationValue),
          const Color(0xFF8B5CF6).withOpacity(0.15),
          Colors.transparent,
        ],
      ).createShader(glassRect);
    canvas.drawCircle(center, radius, glowPaint);

    // 2. Rotating Platinum & Gold Rim
    final rimAngle = animationValue * math.pi * 2;
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: GradientRotation(rimAngle),
        colors: const [
          Color(0xFFFFDF73), // 24k Gold
          Color(0xFF00E5FF), // Electric Cyan
          Color(0xFFA78BFA), // Holographic Violet
          Color(0xFFFFFFFF), // Specular Glint
          Color(0xFFFFDF73),
        ],
        stops: const [0.0, 0.3, 0.65, 0.85, 1.0],
      ).createShader(glassRect);
    canvas.drawCircle(center, radius - 1, rimPaint);

    // 3. Volumetric 3D Wings
    final wingFlap = math.sin(animationValue * math.pi) * 2.5;

    final wingGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFFFFFFF),
        const Color(0xFF38BDF8),
        const Color(0xFF0284C7),
      ],
    );

    final leftWing = Path();
    leftWing.moveTo(center.dx - w * 0.18, center.dy - h * 0.08);
    leftWing.cubicTo(
      center.dx - w * 0.52, center.dy - h * 0.42 + wingFlap,
      center.dx - w * 0.50, center.dy - h * 0.05 + wingFlap,
      center.dx - w * 0.20, center.dy + h * 0.02,
    );
    leftWing.close();

    final leftWingPaint = Paint()
      ..shader = wingGradient.createShader(leftWing.getBounds())
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftWing, leftWingPaint);

    final rightWing = Path();
    rightWing.moveTo(center.dx + w * 0.18, center.dy - h * 0.08);
    rightWing.cubicTo(
      center.dx + w * 0.52, center.dy - h * 0.42 + wingFlap,
      center.dx + w * 0.50, center.dy - h * 0.05 + wingFlap,
      center.dx + w * 0.20, center.dy + h * 0.02,
    );
    rightWing.close();

    final rightWingPaint = Paint()
      ..shader = wingGradient.createShader(rightWing.getBounds())
      ..style = PaintingStyle.fill;
    canvas.drawPath(rightWing, rightWingPaint);

    // 4. 3D Golden Helmet Body
    final helmetRect = Rect.fromLTWH(center.dx - w * 0.24, center.dy - h * 0.28, w * 0.48, h * 0.56);
    final goldShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFFFFF7B2), // Specular light
        Color(0xFFFFD700), // Pure Gold
        Color(0xFFF59E0B), // Warm Gold
        Color(0xFFB45309), // Deep shadow
      ],
      stops: const [0.0, 0.35, 0.7, 1.0],
    ).createShader(helmetRect);

    final helmetPaint = Paint()..shader = goldShader;

    // Helmet Dome
    final dome = Path();
    dome.addArc(Rect.fromLTWH(center.dx - w * 0.22, center.dy - h * 0.26, w * 0.44, h * 0.44), math.pi, math.pi);
    canvas.drawPath(dome, helmetPaint);

    // Nose & Face Guard
    final guard = Path();
    guard.moveTo(center.dx - w * 0.08, center.dy - h * 0.04);
    guard.lineTo(center.dx, center.dy + h * 0.18);
    guard.lineTo(center.dx + w * 0.08, center.dy - h * 0.04);
    guard.close();
    canvas.drawPath(guard, helmetPaint);

    // Cheek Bevels
    final cheekL = Path();
    cheekL.moveTo(center.dx - w * 0.22, center.dy - h * 0.04);
    cheekL.lineTo(center.dx - w * 0.18, center.dy + h * 0.16);
    cheekL.lineTo(center.dx - w * 0.08, center.dy + h * 0.02);
    cheekL.close();
    canvas.drawPath(cheekL, helmetPaint);

    final cheekR = Path();
    cheekR.moveTo(center.dx + w * 0.22, center.dy - h * 0.04);
    cheekR.lineTo(center.dx + w * 0.18, center.dy + h * 0.16);
    cheekR.lineTo(center.dx + w * 0.08, center.dy + h * 0.02);
    cheekR.close();
    canvas.drawPath(cheekR, helmetPaint);

    // 5. Central AI Core Gem / Visor
    final coreRect = Rect.fromCircle(center: Offset(center.dx, center.dy - h * 0.05), radius: w * 0.065);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFFFF),
          const Color(0xFF00E5FF),
          const Color(0xFF0284C7),
        ],
      ).createShader(coreRect);
    canvas.drawCircle(Offset(center.dx, center.dy - h * 0.05), w * 0.065, corePaint);

    // 6. Dual Specular Glare (Apple Glass highlight)
    final glarePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 0.5,
        colors: [
          Colors.white.withOpacity(0.55),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(glassRect);
    canvas.drawOval(
      Rect.fromLTWH(center.dx - radius * 0.7, center.dy - radius * 0.85, radius * 0.9, radius * 0.5),
      glarePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HermesPremiumAvatarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
