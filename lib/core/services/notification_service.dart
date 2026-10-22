import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../config/white_label_config.dart';
import 'notification_display.dart';

/// In-App Notification Alert Model
class PushNotificationAlert {
  static const membersTab = 'members';

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final String? sound;
  final String? targetAudience;
  final String? targetTenantId;
  final String? openTab;

  const PushNotificationAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.sound,
    this.targetAudience,
    this.targetTenantId,
    this.openTab,
  });

  bool get opensMembersTab => openTab == membersTab;

  /// Membership reminder pushes are shown when they arrive and are not kept in the inbox.
  bool get isMembershipReminder =>
      opensMembersTab || title.trim() == 'Membership reminders';

  /// Digest pushes open the Members tab. Other broadcasts leave the current tab.
  static String? openTabFrom(Map<dynamic, dynamic> data) {
    final tab = data['openTab']?.toString().trim();
    if (tab == membersTab) return membersTab;
    if (data['type']?.toString() == 'membership_digest') return membersTab;
    return null;
  }
}

/// One page of a gym admin's notification inbox.
class NotificationInboxPage {
  static const pageSize = 10;

  final List<PushNotificationAlert> alerts;
  final bool hasMore;

  const NotificationInboxPage({
    required this.alerts,
    required this.hasMore,
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

  /// Tab the next gym-admin screen should open, kept until that screen is showing.
  static String? _pendingOpenTab;
  static final StreamController<String> _openTabController =
      StreamController<String>.broadcast();

  /// Fires when a notification tap asks the gym admin dashboard to switch tabs.
  static Stream<String> get onOpenTab => _openTabController.stream;

  static bool get hasPendingMembersTab =>
      _pendingOpenTab == PushNotificationAlert.membersTab;

  /// Records a Members-tab open and notifies a dashboard that is already open.
  static void requestMembersTab() {
    _pendingOpenTab = PushNotificationAlert.membersTab;
    if (!_openTabController.isClosed) {
      _openTabController.add(PushNotificationAlert.membersTab);
    }
  }

  /// Clears a pending Members-tab open. Returns true when one was waiting.
  static bool consumeMembersTabRequest() {
    if (!hasPendingMembersTab) return false;
    _pendingOpenTab = null;
    return true;
  }

  static void _openFromRemoteMessage(RemoteMessage message) {
    if (PushNotificationAlert.openTabFrom(message.data) ==
        PushNotificationAlert.membersTab) {
      requestMembersTab();
    }
  }

  /// Active Firestore realtime listener subscriptions
  static StreamSubscription<dynamic>? _userInboxSub;

  /// Cache of processed notification IDs to avoid duplicate alerts
  static final Set<String> _processedAlertIds = <String>{};

  /// Whether a gym-admin account should see a super-admin broadcast.
  static bool broadcastMatchesGym({
    required String targetAudience,
    String? targetTenantId,
    String? gymTenantId,
  }) {
    if (WhiteLabelConfig.isRestricted &&
        (targetAudience == 'all' || targetAudience == 'gym_owners')) {
      return false;
    }
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
      openTab: PushNotificationAlert.openTabFrom(data),
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
      NotificationDisplay.onTap = (payload) {
        if (payload == PushNotificationAlert.membersTab) {
          requestMembersTab();
        }
      };
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
        _openFromRemoteMessage(message);
      });

      // 5. Check if app was opened directly from a terminated state via notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM app launched from terminated state via notification: ${initialMessage.notification?.title}');
        _openFromRemoteMessage(initialMessage);
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

      // White-label builds only listen on their own gym topic.
      // The platform app also listens to the shared all / gym_owners topics.
      try {
        if (!WhiteLabelConfig.isRestricted) {
          await _messaging.subscribeToTopic('all');
          await _messaging.subscribeToTopic('gym_owners');
        }
        if (tenantId != null &&
            tenantId.trim().isNotEmpty &&
            WhiteLabelConfig.allows(tenantId)) {
          await _messaging.subscribeToTopic('gym_$tenantId');
        }
        debugPrint('FCM subscribed device to gym topic gym_$tenantId');
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

  /// Loads one page of this gym admin's inbox, newest first.
  /// The backend returns at most 10 documents per call.
  static String? _inboxCursor;
  static bool _inboxHasMore = false;
  static bool _inboxLegacyMigrated = false;
  static String? _inboxUserId;
  static List<PushNotificationAlert>? _legacyAlerts;
  static int _legacyOffset = 0;

  static bool get inboxHasMore => _inboxHasMore;

  static Future<NotificationInboxPage> loadInbox({
    required String userId,
    String? tenantId,
    bool reset = true,
  }) async {
    if (!isFirebaseReady || userId.trim().isEmpty) {
      return const NotificationInboxPage(alerts: [], hasMore: false);
    }
    if (_inboxUserId != userId) {
      reset = true;
      _inboxLegacyMigrated = false;
      _inboxCursor = null;
    }
    _inboxUserId = userId;
    if (reset) _inboxCursor = null;

    try {
      final page = await _loadInboxPage(
        userId: userId,
        tenantId: tenantId,
        reset: reset,
      );
      _inboxHasMore = page.hasMore;
      return page;
    } catch (e) {
      debugPrint('Notice: Unable to read gym admin notification inbox: $e');
      _inboxHasMore = false;
      return const NotificationInboxPage(alerts: [], hasMore: false);
    }
  }

  static Future<NotificationInboxPage> _loadInboxPage({
    required String userId,
    required String? tenantId,
    required bool reset,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('listNotificationInbox');
      final response = await callable.call({
        'startAfter': reset ? null : _inboxCursor,
        'migrate': reset && !_inboxLegacyMigrated,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      if (reset) _inboxLegacyMigrated = true;
      return _pageFromBackend(data, tenantId);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        debugPrint('Notice: listNotificationInbox is not deployed. Showing saved notifications.');
        return _loadLegacyInboxPage(userId: userId, tenantId: tenantId, reset: reset);
      }
      debugPrint('Notice: Notification inbox callable failed (${e.code}).');
    } catch (e) {
      debugPrint('Notice: Notification inbox callable failed: $e');
    }

    try {
      return await _loadInboxPageFromFirestore(userId: userId, tenantId: tenantId, reset: reset);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      debugPrint('Notice: Notification documents are not readable yet. Showing saved notifications.');
      return _loadLegacyInboxPage(userId: userId, tenantId: tenantId, reset: reset);
    }
  }

  static NotificationInboxPage _pageFromBackend(
    Map<String, dynamic> data,
    String? tenantId,
  ) {
    final rawItems = data['items'];
    final alerts = <PushNotificationAlert>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final alert = _alertFromQueueDoc(map['id']?.toString() ?? '', map, tenantId);
        if (alert != null) alerts.add(alert);
      }
    }
    final cursor = data['nextCursor']?.toString().trim() ?? '';
    if (cursor.isNotEmpty) _inboxCursor = cursor;
    return NotificationInboxPage(
      alerts: alerts,
      hasMore: data['hasMore'] == true,
    );
  }

  static Future<NotificationInboxPage> _loadInboxPageFromFirestore({
    required String userId,
    required String? tenantId,
    required bool reset,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(NotificationInboxPage.pageSize);
    final cursor = _inboxCursor;
    if (!reset && cursor != null && cursor.isNotEmpty) {
      query = query.startAfter([cursor]);
    }
    final snap = await query.get();
    if (snap.docs.isNotEmpty) {
      final createdAt = snap.docs.last.data()['createdAt']?.toString().trim() ?? '';
      if (createdAt.isNotEmpty) _inboxCursor = createdAt;
    }
    final alerts = <PushNotificationAlert>[];
    for (final doc in snap.docs) {
      final alert = _alertFromQueueDoc(doc.id, doc.data(), tenantId);
      if (alert != null) alerts.add(alert);
    }
    return NotificationInboxPage(
      alerts: alerts,
      hasMore: snap.docs.length >= NotificationInboxPage.pageSize,
    );
  }

  /// Pages the notifications already stored on the user document.
  /// One read covers every page until the inbox is opened again.
  static Future<NotificationInboxPage> _loadLegacyInboxPage({
    required String userId,
    required String? tenantId,
    required bool reset,
  }) async {
    if (reset || _legacyAlerts == null || _inboxUserId != userId) {
      final snap = await _firestore.collection('users').doc(userId).get();
      final alerts = _alertsFromInboxField(snap.data(), tenantId);
      alerts.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      _legacyAlerts = alerts;
      _legacyOffset = 0;
    }
    final all = _legacyAlerts ?? const <PushNotificationAlert>[];
    final start = reset ? 0 : _legacyOffset;
    if (start >= all.length) {
      return const NotificationInboxPage(alerts: [], hasMore: false);
    }
    final end = start + NotificationInboxPage.pageSize;
    final sliceEnd = end > all.length ? all.length : end;
    _legacyOffset = sliceEnd;
    return NotificationInboxPage(
      alerts: all.sublist(start, sliceEnd),
      hasMore: sliceEnd < all.length,
    );
  }

  static List<PushNotificationAlert> _alertsFromInboxField(
    Map<String, dynamic>? data,
    String? tenantId,
  ) {
    final raw = data?['platformNotifications'];
    if (raw is! List) return [];
    final alerts = <PushNotificationAlert>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final alert = _alertFromQueueDoc(map['id']?.toString() ?? '', map, tenantId);
      if (alert != null) alerts.add(alert);
    }
    return alerts;
  }

  /// Starts a listener for the newest inbox document only.
  /// The first snapshot is history and is not announced again.
  static void startRealtimeListener({
    required String? tenantId,
    required String? userId,
  }) {
    if (!isFirebaseReady) return;
    _userInboxSub?.cancel();

    if (userId == null || userId.trim().isEmpty) return;

    try {
      var inboxSeeded = false;
      _userInboxSub = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        final alerts = <PushNotificationAlert>[];
        for (final doc in snapshot.docs) {
          final alert = _alertFromQueueDoc(doc.id, doc.data(), tenantId);
          if (alert != null) alerts.add(alert);
        }
        if (!inboxSeeded) {
          inboxSeeded = true;
          _processedAlertIds.addAll(alerts.map((alert) => alert.id));
          return;
        }
        _publishNewAlerts(alerts);
      }, onError: (e) {
        if (_isPermissionDenied(e)) {
          _userInboxSub?.cancel();
          _listenLegacyUserInbox(userId, tenantId);
          return;
        }
        debugPrint('Notice: Error in gym admin inbox listener: $e');
      });
    } catch (e) {
      debugPrint('Notice: Failed to start realtime notification listener: $e');
    }
  }

  /// Used until the notification subcollection rules are deployed.
  static void _listenLegacyUserInbox(String userId, String? tenantId) {
    var seeded = false;
    _userInboxSub = _firestore.collection('users').doc(userId).snapshots().listen((snap) {
      final alerts = _alertsFromInboxField(snap.data(), tenantId);
      if (!seeded) {
        seeded = true;
        _processedAlertIds.addAll(alerts.map((alert) => alert.id));
        return;
      }
      _publishNewAlerts(alerts);
    }, onError: (e) {
      debugPrint('Notice: Error in gym admin inbox listener: $e');
    });
  }

  static bool _isPermissionDenied(Object error) {
    if (error is FirebaseException) return error.code == 'permission-denied';
    return error.toString().contains('permission-denied');
  }

  /// Cancels the real-time notification listeners
  static void stopRealtimeListener() {
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
      payload: alert.openTab,
    );
  }

  static bool _isMembershipReminder(String docId, Map<dynamic, dynamic> data) {
    final type = data['type']?.toString();
    if (type == 'membership_digest' || type == 'membership_expiry') return true;
    if (data['openTab']?.toString().trim() == PushNotificationAlert.membersTab) return true;
    if (data['title']?.toString().trim() == 'Membership reminders') return true;
    final id = '${data['id'] ?? ''} $docId';
    return id.contains('__digest__daily__');
  }

  static PushNotificationAlert? _alertFromQueueDoc(
    String docId,
    Map<String, dynamic> data,
    String? tenantId,
  ) {
    if (_isMembershipReminder(docId, data)) return null;
    var targetAudience = data['targetAudience']?.toString().trim() ?? '';
    if (targetAudience.isEmpty) {
      final tenant = data['targetTenantId']?.toString().trim() ?? '';
      targetAudience = tenant.isNotEmpty ? 'specific_gym' : 'all';
    }
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
      openTab: PushNotificationAlert.openTabFrom(data),
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
      _inboxCursor = null;
      _inboxHasMore = false;
      _inboxLegacyMigrated = false;
      _inboxUserId = null;
      _legacyAlerts = null;
      _legacyOffset = 0;
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': null,
      }, SetOptions(merge: true));
      debugPrint('FCM Token cleared on logout for user: $userId');
    } catch (e) {
      debugPrint('Error clearing FCM token on logout: $e');
    }
  }
}
