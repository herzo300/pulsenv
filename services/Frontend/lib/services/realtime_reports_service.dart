import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeReportInsertEvent {
  const RealtimeReportInsertEvent({
    required this.id,
    required this.category,
    required this.title,
  });

  final String id;
  final String category;
  final String title;
}

class RealtimeReportsService {
  RealtimeReportsService._();

  static final RealtimeReportsService instance = RealtimeReportsService._();

  final StreamController<RealtimeReportInsertEvent> _insertController =
      StreamController<RealtimeReportInsertEvent>.broadcast();

  RealtimeChannel? _channel;
  bool _started = false;

  Stream<RealtimeReportInsertEvent> get inserts => _insertController.stream;

  Future<void> start() async {
    if (_started) return;

    try {
      final client = Supabase.instance.client;
      final channelName = 'public:reports:insert:v1';

      _channel = client
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'reports',
            callback: (payload) {
              final row = payload.newRecord;
              final id = (row['id']?.toString() ?? '').trim();
              if (id.isEmpty) return;

              final category = (row['category']?.toString() ?? 'Прочее').trim();
              final title = (row['title']?.toString() ?? 'Новая жалоба').trim();

              _insertController.add(
                RealtimeReportInsertEvent(
                  id: id,
                  category: category.isEmpty ? 'Прочее' : category,
                  title: title.isEmpty ? 'Новая жалоба' : title,
                ),
              );
            },
          )
          .subscribe((status, [error]) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              debugPrint('RealtimeReportsService: subscribed.');
            } else if (error != null) {
              debugPrint('RealtimeReportsService: $status / $error');
            } else {
              debugPrint('RealtimeReportsService: status=$status');
            }
          });

      _started = true;
    } catch (error) {
      debugPrint('RealtimeReportsService start failed: $error');
    }
  }

  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    _started = false;
    if (channel != null) {
      try {
        await Supabase.instance.client.removeChannel(channel);
      } catch (error) {
        debugPrint('RealtimeReportsService stop failed: $error');
      }
    }
  }
}
