import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

import '../../../theme/pulse_colors.dart';
import '../../../map/map_config.dart';
import '../../../services/favorite_cameras_service.dart';


class VoiceAssistantButton extends StatefulWidget {
  const VoiceAssistantButton({super.key});

  @override
  State<VoiceAssistantButton> createState() => _VoiceAssistantButtonState();
}

class _VoiceAssistantButtonState extends State<VoiceAssistantButton> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isProcessing = false;
  String _currentWords = '';
  
  Future<void> _toggleListening() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      _processVoiceQuery(_currentWords);
    } else {
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
            _processVoiceQuery(_currentWords);
          }
        },
        onError: (val) => debugPrint('onError: $val'),
      );
      
      if (available) {
        setState(() {
          _isListening = true;
          _currentWords = '';
        });
        _speech.listen(
          onResult: (val) => setState(() {
            _currentWords = val.recognizedWords;
          }),
          localeId: 'ru_RU',
        );
      }
    }
  }
  
  Future<void> _processVoiceQuery(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final prefs = await FavoriteCamerasService().getFavorites();
      if (prefs.isEmpty) {
        if (!mounted) return;
        _showResultDialog('Нет избранных камер. Добавьте камеры в избранное, чтобы использовать этот функционал.');
        setState(() => _isProcessing = false);
        return;
      }
      
      // format favorites for the backend
      final cameras = prefs.map((e) => {'title': e['title'], 'url': e['url']}).toList();
      
      final url = Uri.parse('${MapConfig.backendApiBaseUrl}/cameras/analyze-voice');
      final reqBody = jsonEncode({
        'query': query,
        'cameras': cameras,
      });
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: reqBody,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showResultDialog(data['report'] ?? 'Нет отчета');
        } else {
          _showResultDialog('Ошибка: ${data['report']}');
        }
      } else {
        _showResultDialog('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      _showResultDialog('Ошибка сети: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultDialog(String text) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: PulseColors.background.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PulseColors.border.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('AI Ответ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  Text(text, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PulseColors.primary,
                    ),
                    child: const Text('Закрыть', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return FloatingActionButton(
        onPressed: null,
        backgroundColor: PulseColors.primary.withOpacity(0.5),
        child: const CircularProgressIndicator(color: Colors.white),
      );
    }
    
    return FloatingActionButton(
      onPressed: _toggleListening,
      backgroundColor: _isListening ? PulseColors.negative : PulseColors.primary,
      child: Icon(
        _isListening ? Icons.mic : Icons.mic_none,
        color: Colors.white,
      ),
    );
  }
}
