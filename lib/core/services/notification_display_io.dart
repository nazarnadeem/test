import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows a system notification banner on iOS, Android, and desktop.
class NotificationDisplay {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Called when the user taps a banner shown while the app is open.
  static void Function(String? payload)? onTap;

  static Future<void> initialize() async {
    if (_ready) return;
    try {
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: darwin,
          macOS: darwin,
        ),
        onDidReceiveNotificationResponse: (response) {
          onTap?.call(response.payload);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        onTap?.call(launch?.notificationResponse?.payload);
      }
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
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
      const darwin = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      await _plugin.show(
        id: id.hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'gcrm_notifications',
            'GCRM Notifications',
            channelDescription: 'Notifications for memberships, alerts and updates',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: darwin,
          macOS: darwin,
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationDisplay.show error: $e');
    }
  }
}
