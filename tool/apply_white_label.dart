import 'dart:convert';
import 'dart:io';

import 'package:gcrm_one/core/config/white_label_native_patch.dart';

/// Copies `white_label/active.json` onto Android, iOS, and web identity files.
///
/// Run from the repo root:
/// `dart run tool/apply_white_label.dart`
void main() {
  final root = Directory.current;
  final envFile = File('${root.path}/white_label/active.json');
  if (!envFile.existsSync()) {
    stderr.writeln('Missing white_label/active.json. Run this from the repo root.');
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(envFile.readAsStringSync());
  if (decoded is! Map) {
    stderr.writeln('white_label/active.json must be a JSON object.');
    exitCode = 1;
    return;
  }
  final env = Map<String, dynamic>.from(decoded);
  final displayName = _required(env, 'WL_DISPLAY_NAME');
  final bundleName = _required(env, 'WL_BUNDLE_NAME');
  final description = _required(env, 'WL_APP_DESCRIPTION');
  final applicationId = _required(env, 'WL_ANDROID_APPLICATION_ID');
  final iosBundleId = _required(env, 'WL_IOS_BUNDLE_ID');
  final androidAppId = _optional(env, 'WL_FIREBASE_ANDROID_APP_ID');
  final iosAppId = _optional(env, 'WL_FIREBASE_IOS_APP_ID');
  final mode = _optional(env, 'WL_MODE');

  _write(
    root,
    'android/app/src/main/AndroidManifest.xml',
    (source) => WhiteLabelNativePatch.androidManifest(source, displayName),
  );
  _write(
    root,
    'android/app/build.gradle.kts',
    (source) => WhiteLabelNativePatch.gradleApplicationId(source, applicationId),
  );
  _write(
    root,
    'ios/Runner/Info.plist',
    (source) => WhiteLabelNativePatch.infoPlist(
      source,
      displayName: displayName,
      bundleName: bundleName,
    ),
  );
  _write(
    root,
    'ios/Runner.xcodeproj/project.pbxproj',
    (source) => WhiteLabelNativePatch.pbxprojBundleId(source, iosBundleId),
  );
  _write(
    root,
    'web/index.html',
    (source) => WhiteLabelNativePatch.webIndex(
      source,
      displayName: displayName,
      description: description,
    ),
  );
  _write(
    root,
    'web/manifest.json',
    (source) => WhiteLabelNativePatch.webManifest(
      source,
      displayName: displayName,
      description: description,
    ),
  );

  if (androidAppId.isNotEmpty) {
    _write(
      root,
      'android/app/google-services.json',
      (source) => WhiteLabelNativePatch.googleServices(
        source,
        packageName: applicationId,
        appId: androidAppId,
      ),
    );
    _write(
      root,
      'lib/firebase_options.dart',
      (source) => WhiteLabelNativePatch.firebaseOptionsBlock(
        source,
        'android',
        {'appId': androidAppId},
      ),
    );
  }

  if (iosAppId.isNotEmpty) {
    _write(
      root,
      'ios/Runner/GoogleService-Info.plist',
      (source) => WhiteLabelNativePatch.googleServiceInfo(
        source,
        bundleId: iosBundleId,
        appId: iosAppId,
      ),
    );
    _write(
      root,
      'lib/firebase_options.dart',
      (source) => WhiteLabelNativePatch.firebaseOptionsBlock(
        source,
        'ios',
        {
          'appId': iosAppId,
          'iosBundleId': iosBundleId,
        },
      ),
    );
  }

  stdout.writeln('Applied white_label/active.json ($mode).');
  if (mode == 'white_label' && (androidAppId.isEmpty || iosAppId.isEmpty)) {
    stdout.writeln(
      'Firebase app ids are still empty. Register this application id and bundle id in the existing Firebase project, paste WL_FIREBASE_ANDROID_APP_ID and WL_FIREBASE_IOS_APP_ID, then run this script again.',
    );
  }
}

String _required(Map<String, dynamic> env, String key) {
  final value = _optional(env, key);
  if (value.isEmpty) {
    stderr.writeln('white_label/active.json is missing $key.');
    exit(1);
  }
  return value;
}

String _optional(Map<String, dynamic> env, String key) {
  return env[key]?.toString().trim() ?? '';
}

void _write(Directory root, String relativePath, String Function(String source) patch) {
  final file = File('${root.path}/$relativePath');
  if (!file.existsSync()) {
    stderr.writeln('Skipped missing file: $relativePath');
    return;
  }
  final current = file.readAsStringSync();
  final next = patch(current);
  if (next == current) {
    stdout.writeln('Unchanged $relativePath');
    return;
  }
  file.writeAsStringSync(next);
  stdout.writeln('Updated $relativePath');
}
