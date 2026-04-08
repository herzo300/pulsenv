import 'package:flutter/material.dart';

class VoiceInputButton extends StatelessWidget {
  const VoiceInputButton({
    super.key,
    required this.isListening,
    required this.aiProcessing,
    required this.onToggle,
  });

  final bool isListening;
  final bool aiProcessing;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      color: isListening ? Colors.redAccent : Colors.white70,
      icon: aiProcessing
          ? const SizedBox(
              width: 16.0,
              height: 16.0,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isListening ? Icons.mic : Icons.mic_none),
      tooltip: 'Диктовать голосом',
      onPressed: aiProcessing ? null : onToggle,
    );
  }
}
