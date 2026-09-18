class NotificationMessageFormatter {
  NotificationMessageFormatter._();

  static String compact(
    String? primary, {
    String? fallback,
    int maxLength = 110,
  }) {
    final base = _sanitize(primary);
    final reserve = _sanitize(fallback);
    final source = base.isNotEmpty ? base : reserve;
    if (source.isEmpty) {
      return 'Нажмите, чтобы посмотреть подробности.';
    }

    final sentence = _firstSentence(source);
    if (sentence.length <= maxLength) {
      if (!sentence.endsWith('.') && !sentence.endsWith('!') && !sentence.endsWith('?')) {
        return '$sentence.';
      }
      return sentence;
    }

    var cutIndex = maxLength - 1;
    final sub = sentence.substring(0, maxLength);
    
    final lastSentenceEnd = RegExp(r'[.!?]\s+[A-ZА-ЯёЁ]').allMatches(sub);
    if (lastSentenceEnd.isNotEmpty) {
      cutIndex = lastSentenceEnd.last.start + 1;
    } else {
      final lastSpace = sub.lastIndexOf(' ');
      if (lastSpace > maxLength ~/ 2) {
        cutIndex = lastSpace;
      }
    }

    var result = sentence.substring(0, cutIndex).trimRight();
    while (result.endsWith(',') || result.endsWith('-') || result.endsWith(':') || result.endsWith(';')) {
      result = result.substring(0, result.length - 1).trimRight();
    }
    if (!result.endsWith('.') && !result.endsWith('!') && !result.endsWith('?')) {
      result = '$result.';
    }
    return result;
  }

  static String _sanitize(String? value) {
    var text = (value ?? '').trim();
    if (text.isEmpty) {
      return '';
    }

    text = text.replaceAll(RegExp(r'https?://\S+'), ' ');
    text = text.replaceAll(RegExp(r'[@#][\w\-.]+'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  static String _firstSentence(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return '';
    }

    final match = RegExp(r'^(.{1,180}?[.!?])(?:\s|$)').firstMatch(normalized);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return normalized;
  }
}
