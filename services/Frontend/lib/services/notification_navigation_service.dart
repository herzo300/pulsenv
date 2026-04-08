import 'dart:isolate';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

import '../screens/map_screen.dart';
import 'notification_tap_payload_store.dart';

class NotificationNavigationService {
  NotificationNavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _actionPortName =
      'soobshio.notification.navigation.actions';

  static ReceivePort? _receivePort;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _bindActionPort();
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
    );

    final initialAction = await AwesomeNotifications()
        .getInitialNotificationAction(removeFromActionEvents: false);
    if (initialAction != null) {
      _handleAction(initialAction);
    }

    _initialized = true;
  }

  static void _bindActionPort() {
    _receivePort?.close();
    IsolateNameServer.removePortNameMapping(_actionPortName);

    final receivePort = ReceivePort();
    receivePort.listen((dynamic data) {
      final payload = data is Map
          ? NotificationTapPayloadStore.normalizePayload(data)
          : null;
      if (!NotificationTapPayloadStore.hasMarkerTarget(payload)) {
        return;
      }
      NotificationTapPayloadStore.setPendingPayload(payload);
      _openMap();
    });

    _receivePort = receivePort;
    IsolateNameServer.registerPortWithName(
      receivePort.sendPort,
      _actionPortName,
    );
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    final sendPort = IsolateNameServer.lookupPortByName(_actionPortName);
    sendPort?.send(receivedAction.toMap());
  }

  static void _handleAction(ReceivedAction receivedAction) {
    NotificationTapPayloadStore.setPendingPayload(receivedAction.payload);
    _openMap();
  }

  static void _openMap() {
    final payload = NotificationTapPayloadStore.consumePendingPayload();
    if (!NotificationTapPayloadStore.hasMarkerTarget(payload)) {
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      NotificationTapPayloadStore.setPendingPayload(payload);
      return;
    }

    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(initialNotificationPayload: payload),
      ),
      (route) => false,
    );
  }
}
