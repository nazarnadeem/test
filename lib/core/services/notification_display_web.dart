import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Shows a browser notification while the gym admin session is open.
class NotificationDisplay {
  static bool _ready = false;

  /// Called when the user taps a banner shown while the app is open.
  static void Function(String? payload)? onTap;

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
    String? payload,
  }) async {
    await initialize();
    if (!_ready || title.trim().isEmpty) return;
    try {
      final notification = web.Notification(
        title,
        web.NotificationOptions(body: body, tag: id),
      );
      if (payload != null) {
        notification.onclick = ((web.Event event) {
          onTap?.call(payload);
        }).toJS;
      }
    } catch (e) {
      debugPrint('NotificationDisplay.show error: $e');
    }
  }
}
