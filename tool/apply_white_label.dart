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
  final mode = _optional(env, 'WL_MODE');
  if (mode != 'white_label') {
    stderr.writeln(
      'Refusing to apply. WL_MODE is "$mode". This command only runs in a customer clone, where WL_MODE is white_label. Leave this repo as platform.',
    );
    exitCode = 1;
    return;
  }
  final origin = _remoteUrl(root, 'origin');
  if (origin == null || _isMainRepoUrl(origin)) {
    stderr.writeln(
      'Refusing to apply. origin must be the customer repo, not the main GCRM repo. In the customer folder: git remote rename origin upstream, then git remote add origin <customer-repo-url>.',
    );
    exitCode = 1;
    return;
  }
  final upstream = _remoteUrl(root, 'upstream');
  if (upstream == null || !_isMainRepoUrl(upstream)) {
    stderr.writeln(
      'Refusing to apply. upstream must be the main GCRM repo. In the customer folder: git remote rename origin upstream, then git remote add origin <customer-repo-url>.',
    );
    exitCode = 1;
    return;
  }
  _detachMainTracking(root);

  final displayName = _required(env, 'WL_DISPLAY_NAME');
  final bundleName = _required(env, 'WL_BUNDLE_NAME');
  final description = _required(env, 'WL_APP_DESCRIPTION');
  final applicationId = _required(env, 'WL_ANDROID_APPLICATION_ID');
  final iosBundleId = _required(env, 'WL_IOS_BUNDLE_ID');
  final androidAppId = _optional(env, 'WL_FIREBASE_ANDROID_APP_ID');
  final iosAppId = _optional(env, 'WL_FIREBASE_IOS_APP_ID');

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

  stdout.writeln('Applied white_label/active.json ($mode) in ${root.path}.');
  stdout.writeln('The main app was not changed. Push only with: git push -u origin HEAD');
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

const _mainRepoSuffix = 'nazarnadeem/gcrmone';

String? _remoteUrl(Directory root, String remote) {
  final result = Process.runSync(
    'git',
    ['remote', 'get-url', remote],
    workingDirectory: root.path,
  );
  if (result.exitCode != 0) return null;
  final url = '${result.stdout}'.trim();
  if (url.isEmpty) return null;
  return url;
}

bool _isMainRepoUrl(String url) {
  final normalized = url.trim().toLowerCase().replaceAll(RegExp(r'\.git$'), '');
  return normalized.endsWith(_mainRepoSuffix);
}

/// A clone still tracks the main repo after `git remote rename origin upstream`.
/// A plain `git push` then updates the parent app. Drop that tracking.
void _detachMainTracking(Directory root) {
  final tracking = Process.runSync(
    'git',
    ['rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}'],
    workingDirectory: root.path,
  );
  if (tracking.exitCode != 0) return;
  final remote = '${tracking.stdout}'.trim().split('/').first;
  if (remote.isEmpty) return;
  final url = _remoteUrl(root, remote);
  if (url == null || !_isMainRepoUrl(url)) return;
  final unset = Process.runSync(
    'git',
    ['branch', '--unset-upstream'],
    workingDirectory: root.path,
  );
  if (unset.exitCode != 0) {
    stderr.writeln(
      'Could not detach this branch from the main GCRM repo. Do not push until that link is gone.',
    );
    exit(1);
  }
  stdout.writeln(
    'This branch was tracking the main GCRM repo. A plain git push would update the parent app, so that link is removed.',
  );
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
