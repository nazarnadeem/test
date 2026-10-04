import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/constants/app_strings.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/models/push_notification_model.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';
import 'package:gcrm_one/core/services/notification_service.dart';
import 'package:gcrm_one/features/auth/presentation/screens/super_admin_dashboard_screen.dart';

void main() {
  group('Super Admin Push Notification Tests', () {
    late AuthController authController;

    setUp(() async {
      authController = AuthController(authRepository: MockAuthService());
      await authController.login(
        email: AppStrings.demoSuperAdminEmail,
        password: AppStrings.demoSuperAdminPass,
      );
      await authController.loadGymTenants();
      await authController.loadPlatformPlans();
      await authController.loadNotificationsHistory();
    });

    test('Gym admin inbox keeps broadcasts for their gym and hides other gyms', () {
      expect(
        NotificationService.broadcastMatchesGym(
          targetAudience: 'all',
          gymTenantId: 'gym_1',
        ),
        isTrue,
      );
      expect(
        NotificationService.broadcastMatchesGym(
          targetAudience: 'gym_owners',
          gymTenantId: 'gym_1',
        ),
        isTrue,
      );
      expect(
        NotificationService.broadcastMatchesGym(
          targetAudience: 'specific_gym',
          targetTenantId: 'gym_1',
          gymTenantId: 'gym_1',
        ),
        isTrue,
      );
      expect(
        NotificationService.broadcastMatchesGym(
          targetAudience: 'specific_gym',
          targetTenantId: 'gym_2',
          gymTenantId: 'gym_1',
        ),
        isFalse,
      );
    });

    test('AuthController dispatches push notifications and stores history with custom sound', () async {
      expect(authController.sentNotifications.isNotEmpty, isTrue);

      final result = await authController.sendPushNotification(
        title: '⚡ System Upgrade Test',
        body: 'Testing custom notification sound broadcast',
        targetAudience: 'all',
        sound: 'notification.mp3',
      );

      expect(result, isNotNull);
      expect(result!.title, '⚡ System Upgrade Test');
      expect(result.sound, 'notification.mp3');
      expect(result.targetAudience, 'all');
      expect(authController.sentNotifications.first.title, '⚡ System Upgrade Test');
    });

    testWidgets('SuperAdminDashboardScreen switches to Push Alerts tab and shows broadcasts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SuperAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Find Push Alerts tab
      final pushAlertsTab = find.textContaining('Push Alerts');
      expect(pushAlertsTab, findsOneWidget);

      await tester.tap(pushAlertsTab);
      await tester.pumpAndSettle();

      // Verify header and sound info
      expect(find.textContaining('Push Broadcasts'), findsOneWidget);
      expect(find.textContaining('notification.mp3 active'), findsOneWidget);
    });

    testWidgets('SuperAdmin opens Send Notification modal and submits broadcast with custom sound',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SuperAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on AppBar Broadcast action icon
      final broadcastIcon = find.byTooltip('Broadcast Push Notification');
      expect(broadcastIcon, findsOneWidget);
      await tester.tap(broadcastIcon);
      await tester.pumpAndSettle();

      // Verify Modal Content
      expect(find.text('Send Push Notification'), findsOneWidget);
      expect(find.text('TARGET AUDIENCE'), findsOneWidget);
      expect(find.text('All Users'), findsOneWidget);
      expect(find.text('Gym Admins'), findsOneWidget);
      expect(find.text('Specific Gym'), findsOneWidget);
      expect(find.text('Custom Alert Sound Active'), findsOneWidget);
      expect(find.textContaining('Plays notification.mp3'), findsOneWidget);

      // Tap a template chip
      final maintenanceTemplate = find.text('⚡ Maintenance');
      expect(maintenanceTemplate, findsOneWidget);
      await tester.tap(maintenanceTemplate);
      // Verify title filled (appears in input field and preview card)
      expect(find.text('⚡ Scheduled Maintenance'), findsWidgets);

      // Tap Send Button
      final sendBtn = find.text('Send Push Notification Now');
      expect(sendBtn, findsOneWidget);
      await tester.ensureVisible(sendBtn);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      // Verify SnackBar with custom sound notice
      expect(find.textContaining('Push notification dispatched! Sound: notification.mp3'), findsOneWidget);
    });

    testWidgets('SuperAdmin gym card has Notify button opening pre-targeted modal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SuperAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Notify button exists on gym card
      final notifyBtn = find.text('Notify').first;
      expect(notifyBtn, findsOneWidget);
      await tester.tap(notifyBtn);
      await tester.pumpAndSettle();

      // Verify modal is open and targeted
      expect(find.text('Send Push Notification'), findsOneWidget);
      expect(find.text('Specific Gym'), findsOneWidget);
    });
  });
}
