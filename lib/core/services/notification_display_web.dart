import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Shows a browser notification while the gym admin session is open.
class NotificationDisplay {
  static bool _ready = false;

  static Future<void> initialize() async {
    if (_ready) return;
    try {
      if (web.Notification.permission != 'granted') {
        final result = (await web.Notification.requestPermission().toDart).toDart;
        if (result != 'granted') return;
      }
      _ready = true;
    } catch (e) {
      debugPrint('NotificationDisplay.initialize error: $e');
    }
  }

  static Future<void> show({
    required String id,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (!_ready || title.trim().isEmpty) return;
    try {
      web.Notification(
        title,
        web.NotificationOptions(body: body, tag: id),
      );
    } catch (e) {
      debugPrint('NotificationDisplay.show error: $e');
    }
  }
}
