import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/config/white_label_json_merge.dart';

void main() {
  test('local gym ids and name win, and new main-app keys are added', () {
    final merged = mergeWhiteLabelJson(
      local: {
        'WL_MODE': 'white_label',
        'WL_TEST_TENANT_ID': 'tenant_test',
        'WL_LIVE_TENANT_ID': 'tenant_live',
        'WL_APP_NAME': 'IRONPULSE',
      },
      incoming: {
        'WL_MODE': 'platform',
        'WL_TEST_TENANT_ID': '',
        'WL_LIVE_TENANT_ID': '',
        'WL_APP_NAME': 'GCRM ONE',
        'WL_NEW_FIELD': 'from-main',
      },
    );

    expect(merged['WL_MODE'], 'white_label');
    expect(merged['WL_TEST_TENANT_ID'], 'tenant_test');
    expect(merged['WL_LIVE_TENANT_ID'], 'tenant_live');
    expect(merged['WL_APP_NAME'], 'IRONPULSE');
    expect(merged['WL_NEW_FIELD'], 'from-main');
  });
}
