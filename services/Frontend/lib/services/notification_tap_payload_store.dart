class NotificationTapPayloadStore {
  NotificationTapPayloadStore._();

  static Map<String, String?>? _pendingPayload;
  static String? _lastHandledKey;

  static bool hasMarkerTarget(Map<String, String?>? payload) {
    if (payload == null || payload.isEmpty) {
      return false;
    }
    if (payload['type'] == 'weather_anomaly' || payload['open_weather'] == 'true') {
      return true;
    }
    final reportId = payload['report_id']?.trim() ?? '';
    final lat = payload['lat']?.trim() ?? '';
    final lng = payload['lng']?.trim() ?? '';
    final address = payload['address']?.trim() ?? '';
    return reportId.isNotEmpty || (lat.isNotEmpty && lng.isNotEmpty) || address.isNotEmpty;
  }

  static Map<String, String?>? normalizePayload(Map<dynamic, dynamic>? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }

    final normalized = <String, String?>{};
    payload.forEach((key, value) {
      final normalizedKey = key?.toString().trim();
      if (normalizedKey == null || normalizedKey.isEmpty) {
        return;
      }
      final normalizedValue = value?.toString().trim();
      normalized[normalizedKey] =
          (normalizedValue == null || normalizedValue.isEmpty)
              ? null
              : normalizedValue;
    });

    return normalized.isEmpty ? null : normalized;
  }

  static void setPendingPayload(Map<dynamic, dynamic>? payload) {
    final normalized = normalizePayload(payload);
    if (!hasMarkerTarget(normalized)) {
      return;
    }

    final key = [
      normalized!['report_id'] ?? '',
      normalized['lat'] ?? '',
      normalized['lng'] ?? '',
      normalized['address'] ?? '',
    ].join('|');
    if (key == _lastHandledKey) {
      return;
    }

    _lastHandledKey = key;
    _pendingPayload = Map<String, String?>.from(normalized);
  }

  static Map<String, String?>? consumePendingPayload() {
    if (_pendingPayload == null) {
      return null;
    }
    final payload = Map<String, String?>.from(_pendingPayload!);
    _pendingPayload = null;
    _lastHandledKey = null;
    return payload;
  }
}
