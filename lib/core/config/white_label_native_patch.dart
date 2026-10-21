/// String transforms that copy [white_label/active.json] onto native project files.
class WhiteLabelNativePatch {
  WhiteLabelNativePatch._();

  /// Sets the Android launcher label.
  static String androidManifest(String source, String displayName) {
    return source.replaceFirst(
      RegExp('android:label="[^"]*"'),
      'android:label="${_xml(displayName)}"',
    );
  }

  /// Sets the Play Store application id. The Kotlin namespace stays put.
  static String gradleApplicationId(String source, String applicationId) {
    return source.replaceFirst(
      RegExp('applicationId\\s*=\\s*"[^"]*"'),
      'applicationId = "$applicationId"',
    );
  }

  /// Sets the iOS display name and the short bundle name.
  static String infoPlist(
    String source, {
    required String displayName,
    required String bundleName,
  }) {
    final named = _plistString(source, 'CFBundleDisplayName', displayName);
    return _plistString(named, 'CFBundleName', bundleName);
  }

  /// Sets the app bundle id and leaves the test target id alone.
  static String pbxprojBundleId(String source, String bundleId) {
    final line = RegExp(
      r'^(\s*PRODUCT_BUNDLE_IDENTIFIER = )([^;]+)(;\s*)$',
      multiLine: true,
    );
    return source.replaceAllMapped(line, (match) {
      final current = match.group(2)!.trim();
      if (current.endsWith('.RunnerTests')) return match.group(0)!;
      return '${match.group(1)}$bundleId${match.group(3)}';
    });
  }

  /// Updates one FirebaseOptions block inside `firebase_options.dart`.
  static String firebaseOptionsBlock(
    String source,
    String blockName,
    Map<String, String> fields,
  ) {
    final marker = 'static const FirebaseOptions $blockName = FirebaseOptions(';
    final start = source.indexOf(marker);
    if (start < 0) return source;
    final end = source.indexOf(');', start);
    if (end < 0) return source;
    var block = source.substring(start, end);
    fields.forEach((key, value) {
      if (value.trim().isEmpty) return;
      final field = RegExp("$key:\\s*'[^']*'");
      if (!field.hasMatch(block)) return;
      block = block.replaceFirst(field, "$key: '$value'");
    });
    return source.replaceRange(start, end, block);
  }

  /// Points `google-services.json` at the Android app registered for this build.
  static String googleServices(
    String source, {
    required String packageName,
    required String appId,
  }) {
    var next = source;
    if (packageName.trim().isNotEmpty) {
      next = next.replaceFirst(
        RegExp('"package_name"\\s*:\\s*"[^"]*"'),
        '"package_name": "$packageName"',
      );
    }
    if (appId.trim().isNotEmpty) {
      next = next.replaceFirst(
        RegExp('"mobilesdk_app_id"\\s*:\\s*"[^"]*"'),
        '"mobilesdk_app_id": "$appId"',
      );
    }
    return next;
  }

  /// Points `GoogleService-Info.plist` at the iOS app registered for this build.
  static String googleServiceInfo(
    String source, {
    required String bundleId,
    required String appId,
  }) {
    var next = source;
    if (bundleId.trim().isNotEmpty) {
      next = _plistString(next, 'BUNDLE_ID', bundleId);
    }
    if (appId.trim().isNotEmpty) {
      next = _plistString(next, 'GOOGLE_APP_ID', appId);
    }
    return next;
  }

  /// Sets the browser tab title and description.
  static String webIndex(
    String source, {
    required String displayName,
    required String description,
  }) {
    var next = source.replaceFirst(
      RegExp('<title>[^<]*</title>'),
      '<title>${_xml(displayName)}</title>',
    );
    next = next.replaceFirst(
      RegExp('apple-mobile-web-app-title" content="[^"]*"'),
      'apple-mobile-web-app-title" content="${_xml(displayName)}"',
    );
    next = next.replaceFirst(
      RegExp('<meta name="description" content="[^"]*"'),
      '<meta name="description" content="${_xml(description)}"',
    );
    return next;
  }

  /// Sets the installed web app name.
  static String webManifest(
    String source, {
    required String displayName,
    required String description,
  }) {
    var next = source.replaceFirst(
      RegExp('"name"\\s*:\\s*"[^"]*"'),
      '"name": "${_json(displayName)}"',
    );
    next = next.replaceFirst(
      RegExp('"short_name"\\s*:\\s*"[^"]*"'),
      '"short_name": "${_json(displayName)}"',
    );
    next = next.replaceFirst(
      RegExp('"description"\\s*:\\s*"[^"]*"'),
      '"description": "${_json(description)}"',
    );
    return next;
  }

  static String _plistString(String source, String key, String value) {
    final pattern = RegExp(
      '(<key>${RegExp.escape(key)}</key>\\s*<string>)[^<]*(</string>)',
    );
    return source.replaceFirstMapped(pattern, (match) {
      return '${match.group(1)}${_xml(value)}${match.group(2)}';
    });
  }

  static String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static String _json(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }
}
