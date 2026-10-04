import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_display.dart';

/// In-App Notification Alert Model
class PushNotificationAlert {
  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final String? sound;
  final String? targetAudience;
  final String? targetTenantId;

  const PushNotificationAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.sound,
    this.targetAudience,
    this.targetTenantId,
  });
}

/// Top-level background message handler required by FirebaseMessaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message received: ${message.messageId} | ${message.notification?.title}');
}

class NotificationService {
  static bool get isFirebaseReady => Firebase.apps.isNotEmpty;
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static bool _isInitialized = false;

  /// Broadcast controller for incoming real-time notifications (foreground FCM or Firestore queue)
  static final StreamController<PushNotificationAlert> _alertController =
      StreamController<PushNotificationAlert>.broadcast();

  /// Stream of incoming push notification alerts that UI can listen to
  static Stream<PushNotificationAlert> get onNotificationAlert => _alertController.stream;

  /// Active Firestore realtime listener subscriptions
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _realtimeQueueSub;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userInboxSub;

  /// Cache of processed notification IDs to avoid duplicate alerts
  static final Set<String> _processedAlertIds = <String>{};

  /// Whether a gym-admin account should see a super-admin broadcast.
  static bool broadcastMatchesGym({
    required String targetAudience,
    String? targetTenantId,
    String? gymTenantId,
  }) {
    if (targetAudience == 'all' || targetAudience == 'gym_owners') return true;
    if (targetAudience == 'specific_gym') {
      final target = targetTenantId?.trim() ?? '';
      final gym = gymTenantId?.trim() ?? '';
      return target.isNotEmpty && gym.isNotEmpty && target == gym;
    }
    return false;
  }

  /// Builds an in-app alert from an FCM message, including data-only payloads.
  static PushNotificationAlert? alertFromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final title = message.notification?.title ?? data['title']?.toString();
    final body = message.notification?.body ?? data['body']?.toString() ?? '';
    if (title == null || title.trim().isEmpty) return null;
    final id = data['notificationId']?.toString().trim().isNotEmpty == true
        ? data['notificationId'].toString()
        : (message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString());
    return PushNotificationAlert(
      id: id,
      title: title,
      body: body,
      receivedAt: DateTime.now(),
      sound: data['sound']?.toString() ?? 'notification.mp3',
      targetAudience: data['targetAudience']?.toString(),
      targetTenantId: data['targetTenantId']?.toString(),
    );
  }

  /// Default notification channel and sound identifier for custom push notification audio
  static const String notificationChannelId = 'gcrm_notifications';
  static const String notificationChannelName = 'GCRM Notifications';
  static const String notificationSoundName = 'notification';

  /// Initializes push notifications: sets up presentation options, listeners, and requests OS permission.
  static Future<NotificationSettings?> initialize() async {
    if (!isFirebaseReady) return null;
    if (_isInitialized) return null;

    try {
      // System banners are shown by NotificationDisplay so foreground
      // messages are not presented twice on iOS.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );
      await NotificationDisplay.initialize();

      // 2. Request permission explicitly so the user sees the system prompt
      final settings = await requestPermission();

      // 3. Foreground FCM message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM foreground message: ${message.notification?.title} - ${message.notification?.body}');
        final alert = alertFromRemoteMessage(message);
        if (alert != null) {
          _emitAlert(alert);
        }
      });

      // 4. Notification tap when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM message opened from background: ${message.notification?.title}');
      });

      // 5. Check if app was opened directly from a terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM app launched from terminated state via notification: ${initialMessage.notification?.title}');
      }

      _isInitialized = true;
      return settings;
    } catch (e) {
      debugPrint('NotificationService.initialize error: $e');
      return null;
    }
  }

  /// Explicitly requests permission from iOS or Android 13+ (POST_NOTIFICATIONS)
  static Future<NotificationSettings> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User notification permission status: ${settings.authorizationStatus}');
    return settings;
  }

  /// Initializes and binds the FCM token to a specific user in Firestore.
  static Future<void> initializeAndSaveToken(
    String userId, {
    String? tenantId,
    String? role,
  }) async {
    if (!isFirebaseReady) return;
    try {
      await initialize();

      // Ensure permission is granted or provisional
      final currentSettings = await _messaging.getNotificationSettings();
      final hasPermission =
          currentSettings.authorizationStatus == AuthorizationStatus.authorized ||
          currentSettings.authorizationStatus == AuthorizationStatus.provisional;

      if (!hasPermission) {
        final requested = await requestPermission();
        if (requested.authorizationStatus != AuthorizationStatus.authorized &&
            requested.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint('Notification permission denied by user.');
        }
      }

      // Safe token retrieval with APNS resolution for iOS
      String? token;
      try {
        if (!kIsWeb && Platform.isIOS) {
          // Poll for APNS device token so Firebase iOS SDK does not error out with apns-token-not-set
          String? apnsToken;
          for (int attempt = 1; attempt <= 15; attempt++) {
            apnsToken = await _messaging.getAPNSToken();
            if (apnsToken != null && apnsToken.isNotEmpty) {
              debugPrint('APNS token verified on iOS (attempt $attempt).');
              break;
            }
            await Future.delayed(const Duration(milliseconds: 400));
          }
          if (apnsToken == null) {
            debugPrint('Notice: APNS token not ready after polling. Attempting FCM token retrieval.');
          }
        }

        // Fetch FCM token with retry backoff
        for (int attempt = 1; attempt <= 4; attempt++) {
          try {
            token = await _messaging.getToken();
            if (token != null && token.trim().isNotEmpty) {
              break;
            }
          } catch (tErr) {
            debugPrint('FCM getToken attempt $attempt error: $tErr');
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      } catch (tokenError) {
        debugPrint('Notice: Error fetching FCM token: $tokenError');
      }

      if (token != null && token.isNotEmpty) {
        debugPrint('FCM Token successfully obtained: $token');
        await _saveTokenToDatabase(
          token: token,
          userId: userId,
          tenantId: tenantId,
          role: role,
        );
      }

      // Subscribe device to broadcast topics for resilient audience dispatch
      try {
        await _messaging.subscribeToTopic('all');
        await _messaging.subscribeToTopic('gym_owners');
        if (tenantId != null && tenantId.trim().isNotEmpty) {
          await _messaging.subscribeToTopic('gym_$tenantId');
        }
        debugPrint('FCM subscribed device to topics (all, gym_owners, gym_$tenantId)');
      } catch (topicError) {
        debugPrint('Notice: FCM topic subscription: $topicError');
      }

      // Listen to token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _saveTokenToDatabase(
          token: newToken,
          userId: userId,
          tenantId: tenantId,
          role: role,
        );
      });
    } catch (e) {
      debugPrint('Failed to initialize and save push notification token: $e');
    }
  }

  /// Saves or merges the FCM token into Firestore users collection.
  static Future<void> _saveTokenToDatabase({
    required String token,
    required String userId,
    String? tenantId,
    String? role,
  }) async {
    try {
      final data = <String, dynamic>{
        'fcmToken': token.trim(),
        'fcmPlatform': kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android'),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      };
      if (tenantId != null && tenantId.isNotEmpty) {
        data['tenantId'] = tenantId;
      }
      if (role != null && role.isNotEmpty) {
        data['role'] = role;
      }

      await _firestore.collection('users').doc(userId).set(
        data,
        SetOptions(merge: true),
      );
      debugPrint('FCM Token successfully saved for user: $userId (tenant: $tenantId)');
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }

  /// Loads broadcasts already delivered to this gym admin, newest first.
  static Future<List<PushNotificationAlert>> loadInbox({
    required String userId,
    String? tenantId,
    int limit = 40,
  }) async {
    if (!isFirebaseReady || userId.trim().isEmpty) return [];

    final byId = <String, PushNotificationAlert>{};

    try {
      final userSnap = await _firestore.collection('users').doc(userId).get();
      for (final alert in _alertsFromInboxField(userSnap.data())) {
        byId[alert.id] = alert;
      }
    } catch (e) {
      debugPrint('Notice: Unable to read gym admin notification inbox: $e');
    }

    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _firestore
            .collection('notifications_queue')
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
      } catch (orderedError) {
        debugPrint('Notice: Ordered notification history failed, reading recent docs: $orderedError');
        snap = await _firestore.collection('notifications_queue').limit(limit).get();
      }
      for (final doc in snap.docs) {
        final alert = _alertFromQueueDoc(doc.id, doc.data(), tenantId);
        if (alert != null) byId.putIfAbsent(alert.id, () => alert);
      }
    } catch (e) {
      debugPrint('Notice: Unable to read notifications_queue history: $e');
    }

    final alerts = byId.values.toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    if (alerts.length > limit) {
      return alerts.sublist(0, limit);
    }
    return alerts;
  }

  /// Starts listeners that surface new broadcasts while the gym admin app is open.
  /// The first snapshot is history and is not announced again.
  static void startRealtimeListener({
    required String? tenantId,
    required String? userId,
  }) {
    if (!isFirebaseReady) return;
    _realtimeQueueSub?.cancel();
    _userInboxSub?.cancel();

    if (userId != null && userId.trim().isNotEmpty) {
      var inboxSeeded = false;
      _userInboxSub = _firestore.collection('users').doc(userId).snapshots().listen((snap) {
        final alerts = _alertsFromInboxField(snap.data());
        if (!inboxSeeded) {
          inboxSeeded = true;
          _processedAlertIds.addAll(alerts.map((alert) => alert.id));
          return;
        }
        _publishNewAlerts(alerts);
      }, onError: (e) {
        debugPrint('Notice: Error in gym admin inbox listener: $e');
      });
    }

    try {
      var queueSeeded = false;
      _realtimeQueueSub = _firestore
          .collection('notifications_queue')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots()
          .listen((snapshot) {
        final alerts = <PushNotificationAlert>[];
        for (final doc in snapshot.docs) {
          final alert = _alertFromQueueDoc(doc.id, doc.data(), tenantId);
          if (alert != null) alerts.add(alert);
        }
        if (!queueSeeded) {
          queueSeeded = true;
          _processedAlertIds.addAll(alerts.map((alert) => alert.id));
          return;
        }
        _publishNewAlerts(alerts);
      }, onError: (e) {
        debugPrint('Notice: Error in notifications_queue real-time listener: $e');
      });
    } catch (e) {
      debugPrint('Notice: Failed to start realtime notification listener: $e');
    }
  }

  /// Cancels the real-time notification listeners
  static void stopRealtimeListener() {
    _realtimeQueueSub?.cancel();
    _realtimeQueueSub = null;
    _userInboxSub?.cancel();
    _userInboxSub = null;
  }

  static void _publishNewAlerts(List<PushNotificationAlert> alerts) {
    for (final alert in alerts) {
      _emitAlert(alert);
    }
  }

  static void _emitAlert(PushNotificationAlert alert) {
    if (!_processedAlertIds.add(alert.id)) return;
    _alertController.add(alert);
    NotificationDisplay.show(
      id: alert.id,
      title: alert.title,
      body: alert.body,
    );
  }

  static List<PushNotificationAlert> _alertsFromInboxField(Map<String, dynamic>? data) {
    final raw = data?['platformNotifications'];
    if (raw is! List) return [];
    final alerts = <PushNotificationAlert>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString() ?? '';
      final title = map['title']?.toString() ?? '';
      if (id.isEmpty || title.isEmpty) continue;
      alerts.add(PushNotificationAlert(
        id: id,
        title: title,
        body: map['body']?.toString() ?? '',
        receivedAt: _parseAlertTime(map['createdAt']),
        sound: map['sound']?.toString() ?? 'notification.mp3',
        targetAudience: map['targetAudience']?.toString(),
        targetTenantId: map['targetTenantId']?.toString(),
      ));
    }
    return alerts;
  }

  static PushNotificationAlert? _alertFromQueueDoc(
    String docId,
    Map<String, dynamic> data,
    String? tenantId,
  ) {
    final targetAudience = data['targetAudience']?.toString() ?? 'all';
    final targetTenantId = data['targetTenantId']?.toString();
    if (!broadcastMatchesGym(
      targetAudience: targetAudience,
      targetTenantId: targetTenantId,
      gymTenantId: tenantId,
    )) {
      return null;
    }
    final title = data['title']?.toString() ?? '';
    if (title.isEmpty) return null;
    return PushNotificationAlert(
      id: docId,
      title: title,
      body: data['body']?.toString() ?? '',
      receivedAt: _parseAlertTime(data['createdAt']),
      sound: data['sound']?.toString() ?? 'notification.mp3',
      targetAudience: targetAudience,
      targetTenantId: targetTenantId,
    );
  }

  static DateTime _parseAlertTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  /// Clears the token on logout so subsequent users on the same device don't receive unwanted notifications.
  static Future<void> clearTokenOnLogout(String userId) async {
    if (!isFirebaseReady) return;
    try {
      stopRealtimeListener();
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': null,
      }, SetOptions(merge: true));
      debugPrint('FCM Token cleared on logout for user: $userId');
    } catch (e) {
      debugPrint('Error clearing FCM token on logout: $e');
    }
  }
}
