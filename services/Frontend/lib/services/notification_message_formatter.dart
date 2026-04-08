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
      return 'Нажмите, чтобы посмотреть подробности';
    }

    final sentence = _firstSentence(source);
    if (sentence.length <= maxLength) {
      return sentence;
    }
    return '${sentence.substring(0, maxLength - 1).trimRight()}…';
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
