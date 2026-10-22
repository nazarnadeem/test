import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/config/white_label_config.dart';
import 'package:gcrm_one/core/constants/app_strings.dart';
import 'package:gcrm_one/core/services/notification_service.dart';

void main() {
  tearDown(WhiteLabelConfig.debugReset);

  test('platform mode can open every gym', () {
    WhiteLabelConfig.applyMap({'WL_MODE': 'platform'});
    WhiteLabelConfig.validate();

    expect(WhiteLabelConfig.isRestricted, isFalse);
    expect(WhiteLabelConfig.allows('any_gym'), isTrue);
    expect(WhiteLabelConfig.allows(null), isTrue);
    expect(AppStrings.appName, 'GCRM ONE');
  });

  test('white-label mode keeps only the test gym and the live gym', () {
    WhiteLabelConfig.applyMap({
      'WL_MODE': 'white_label',
      'WL_TEST_TENANT_ID': 'tenant_test',
      'WL_LIVE_TENANT_ID': 'tenant_live',
      'WL_APP_NAME': 'IRONPULSE',
      'WL_TAGLINE': 'Train here',
    });
    WhiteLabelConfig.validate();

    expect(WhiteLabelConfig.allowedTenantIds, ['tenant_test', 'tenant_live']);
    expect(WhiteLabelConfig.allows('tenant_test'), isTrue);
    expect(WhiteLabelConfig.allows('tenant_live'), isTrue);
    expect(WhiteLabelConfig.allows('tenant_other'), isFalse);
    expect(WhiteLabelConfig.allows(null), isFalse);
    expect(AppStrings.appName, 'IRONPULSE');
    expect(AppStrings.tagline, 'Train here');
    expect(
      () => WhiteLabelConfig.ensureTenant('tenant_other'),
      throwsA(isA<TenantAccessException>()),
    );
    expect(
      () => WhiteLabelConfig.ensureGymCreationAllowed(),
      throwsA(isA<TenantAccessException>()),
    );
    expect(
      () => WhiteLabelConfig.ensureBroadcast(
        targetAudience: 'all',
      ),
      throwsA(isA<TenantAccessException>()),
    );
    WhiteLabelConfig.ensureBroadcast(
      targetAudience: 'specific_gym',
      targetTenantId: 'tenant_live',
    );

    expect(
      NotificationService.broadcastMatchesGym(
        targetAudience: 'all',
        gymTenantId: 'tenant_live',
      ),
      isFalse,
    );
    expect(
      NotificationService.broadcastMatchesGym(
        targetAudience: 'specific_gym',
        targetTenantId: 'tenant_live',
        gymTenantId: 'tenant_live',
      ),
      isTrue,
    );
    expect(
      NotificationService.broadcastMatchesGym(
        targetAudience: 'specific_gym',
        targetTenantId: 'tenant_other',
        gymTenantId: 'tenant_live',
      ),
      isFalse,
    );
  });

  test('white-label mode refuses a missing or repeated gym id', () {
    WhiteLabelConfig.applyMap({
      'WL_MODE': 'white_label',
      'WL_TEST_TENANT_ID': 'tenant_test',
    });
    expect(WhiteLabelConfig.validate, throwsA(isA<WhiteLabelConfigException>()));

    WhiteLabelConfig.applyMap({
      'WL_LIVE_TENANT_ID': 'tenant_test',
    });
    expect(WhiteLabelConfig.validate, throwsA(isA<WhiteLabelConfigException>()));
  });
}
