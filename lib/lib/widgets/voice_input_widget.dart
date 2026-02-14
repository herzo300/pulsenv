// lib/widgets/voice_input_widget.dart
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Виджет голосового ввода
class VoiceInputWidget extends StatefulWidget {
  final Function(String) onResult;
  final String? hintText;
  
  const VoiceInputWidget({
    Key? key,
    required this.onResult,
    this.hintText,
  }) : super(key: key);
  
  @override
  State<VoiceInputWidget> createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends State<VoiceInputWidget> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  double _confidence = 0.0;
  
  @override
  void initState() {
    super.initState();
    _initSpeech();
  }
  
  Future<void> _initSpeech() async {
    await _speech.initialize(
      onError: (error) {
        debugPrint('Speech error: $error');
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
  }
  
  Future<void> _startListening() async {
    if (!_speech.isAvailable) {
      await _initSpeech();
    }
    
    if (_speech.isAvailable) {
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });
      
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
            _confidence = result.confidence;
          });
          
          if (result.finalResult) {
            widget.onResult(_recognizedText);
            setState(() => _isListening = false);
          }
        },
        localeId: 'ru_RU',
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
      );
    }
  }
  
  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    
    if (_recognizedText.isNotEmpty) {
      widget.onResult(_recognizedText);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Индикатор записи
        if (_isListening)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Анимированные полоски
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 4,
                      height: _isListening ? 20 + (index * 5.0) : 10,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  'Слушаю...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_recognizedText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _recognizedText,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Кнопка микрофона
        GestureDetector(
          onTapDown: (_) => _startListening(),
          onTapUp: (_) => _stopListening(),
          onTapCancel: () => _stopListening(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isListening ? 80 : 64,
            height: _isListening ? 80 : 64,
            decoration: BoxDecoration(
              color: _isListening 
                  ? Colors.red 
                  : Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isListening ? Colors.red : Theme.of(context).colorScheme.primary)
                      .withOpacity(0.3),
                  blurRadius: _isListening ? 20 : 10,
                  spreadRadius: _isListening ? 5 : 2,
                ),
              ],
            ),
            child: Icon(
              _isListening ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: _isListening ? 32 : 28,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          _isListening ? 'Отпустите для завершения' : (widget.hintText ?? 'Удерживайте для записи'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }
}
