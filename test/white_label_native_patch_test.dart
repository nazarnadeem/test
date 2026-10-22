import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/config/white_label_native_patch.dart';

void main() {
  test('native patches update identity and leave the test target alone', () {
    const manifest = '<application android:label="GCRM One" android:icon="@mipmap/ic_launcher">';
    expect(
      WhiteLabelNativePatch.androidManifest(manifest, 'IronPulse'),
      contains('android:label="IronPulse"'),
    );

    const gradle = 'applicationId = "com.gcrmone"';
    expect(
      WhiteLabelNativePatch.gradleApplicationId(gradle, 'com.ironpulse.gym'),
      'applicationId = "com.ironpulse.gym"',
    );

    const plist = '''
<key>CFBundleDisplayName</key>
<string>Gcrm One</string>
<key>CFBundleName</key>
<string>gcrm_one</string>
''';
    final patchedPlist = WhiteLabelNativePatch.infoPlist(
      plist,
      displayName: 'IronPulse',
      bundleName: 'ironpulse',
    );
    expect(patchedPlist, contains('<string>IronPulse</string>'));
    expect(patchedPlist, contains('<string>ironpulse</string>'));

    const project = '''
				PRODUCT_BUNDLE_IDENTIFIER = com.example.gcrmOne;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.gcrmOne.RunnerTests;
''';
    final patchedProject = WhiteLabelNativePatch.pbxprojBundleId(
      project,
      'com.ironpulse.gym',
    );
    expect(patchedProject, contains('PRODUCT_BUNDLE_IDENTIFIER = com.ironpulse.gym;'));
    expect(
      patchedProject,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.gcrmOne.RunnerTests;'),
    );
  });

  test('firebase files change only the requested app block', () {
    const options = '''
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'key',
    appId: 'ios-old',
    iosBundleId: 'com.gcrmone.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'key',
    appId: 'android-old',
  );
''';
    final patched = WhiteLabelNativePatch.firebaseOptionsBlock(
      options,
      'android',
      {'appId': 'android-new'},
    );
    expect(patched, contains("appId: 'android-new'"));
    expect(patched, contains("appId: 'ios-old'"));

    const services = '{"mobilesdk_app_id": "old", "package_name": "com.gcrmone"}';
    expect(
      WhiteLabelNativePatch.googleServices(
        services,
        packageName: 'com.ironpulse.gym',
        appId: 'android-new',
      ),
      '{"mobilesdk_app_id": "android-new", "package_name": "com.ironpulse.gym"}',
    );
  });
}
