import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/services/notification_service.dart';

void main() {
  test('membership digest payload opens the members tab', () {
    expect(
      PushNotificationAlert.openTabFrom({
        'type': 'membership_digest',
        'openTab': 'members',
      }),
      PushNotificationAlert.membersTab,
    );
    expect(
      PushNotificationAlert.openTabFrom({'type': 'membership_digest'}),
      PushNotificationAlert.membersTab,
    );
    expect(
      PushNotificationAlert.openTabFrom({
        'type': 'membership_expiry',
        'memberId': 'member-1',
      }),
      isNull,
    );
    expect(PushNotificationAlert.openTabFrom({'openTab': 'overview'}), isNull);
  });

  test('a members-tab request stays pending until the dashboard consumes it', () {
    NotificationService.requestMembersTab();
    expect(NotificationService.hasPendingMembersTab, isTrue);
    expect(NotificationService.consumeMembersTabRequest(), isTrue);
    expect(NotificationService.hasPendingMembersTab, isFalse);
    expect(NotificationService.consumeMembersTabRequest(), isFalse);
  });
}
