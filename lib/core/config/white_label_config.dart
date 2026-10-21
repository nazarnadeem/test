import 'dart:convert';

import 'package:flutter/services.dart';

/// Thrown when a white-label build is asked to open a gym outside its env.
class TenantAccessException implements Exception {
  /// Message shown to the signed-in user.
  final String message;

  /// Creates an access error whose [toString] matches other app exceptions.
  TenantAccessException(this.message);

  @override
  String toString() => 'Exception: $message';
}

/// Thrown when [white_label/active.json] is incomplete for white-label mode.
class WhiteLabelConfigException implements Exception {
  /// What must be fixed before the app can start.
  final String message;

  /// Creates a startup configuration error.
  WhiteLabelConfigException(this.message);

  @override
  String toString() => message;
}

/// Which gyms this binary is allowed to open.
enum WhiteLabelMode {
  /// Main GCRM app. Every tenant in the shared Firebase project is visible.
  platform,

  /// One customer app. Only the test gym and the live gym from env are visible.
  whiteLabel,
}

/// Brand and tenant scope for this build.
///
/// The main repo stays [WhiteLabelMode.platform]. A customer app is a separate
/// clone whose `white_label/active.json` sets `WL_MODE` to `white_label` and
/// names the test gym and the live gym. That file is the only config to edit.
class WhiteLabelConfig {
  WhiteLabelConfig._();

  static const String assetPath = 'white_label/active.json';

  static const String _accountDenied =
      'This account is not part of this gym app.';
  static const String _gymDenied = 'This gym is not available in this app.';
  static const String _createDenied =
      'New gyms are created in the main GCRM app. This app only opens the two gyms in its env file.';
  static const String _adminDenied =
      'Super admin is only available in the main GCRM app.';
  static const String _broadcastDenied =
      'This app can only notify its own gyms.';

  static WhiteLabelMode _mode = WhiteLabelMode.platform;
  static String _testTenantId = '';
  static String _liveTenantId = '';
  static String _appName = 'GCRM ONE';
  static String _appNamePrefix = 'GCRM ';
  static String _appNameSuffix = 'ONE';
  static String _tagline = 'All Your Gym Operations, Unified';
  static String _appDescription =
      'The modern multi-vendor operating system for gym chains, independent fitness clubs, trainers, and members.';
  static String _displayName = 'GCRM One';
  static String _supportEmail = 'support@gcrmone.com';
  static String _adminEmail = 'admin@gcrmone.com';
  static String _supportPhone = '+1 (800) 555-GCRM (4276)';

  /// True when this binary is a single-customer app.
  static bool get isRestricted => _mode == WhiteLabelMode.whiteLabel;

  /// Test gym id, then live gym id. Empty on the platform app.
  static List<String> get allowedTenantIds =>
      isRestricted ? [_testTenantId, _liveTenantId] : const [];

  /// Name shown inside the Flutter UI.
  static String get appName => _appName;

  /// First half of the wordmark, kept for branded text layouts.
  static String get appNamePrefix => _appNamePrefix;

  /// Second half of the wordmark, kept for branded text layouts.
  static String get appNameSuffix => _appNameSuffix;

  /// Short line under the app name.
  static String get tagline => _tagline;

  /// Longer product description used on the web manifest and about copy.
  static String get appDescription => _appDescription;

  /// Home-screen name applied to Android, iOS, and web by the setup script.
  static String get displayName => _displayName;

  /// Support address on the suspended-gym screen.
  static String get supportEmail => _supportEmail;

  /// Platform contact address on the suspended-gym screen.
  static String get adminEmail => _adminEmail;

  /// Phone number on the suspended-gym screen.
  static String get supportPhone => _supportPhone;

  /// Whether [tenantId] may be read or written by this build.
  static bool allows(String? tenantId) {
    if (!isRestricted) return true;
    final id = tenantId?.trim() ?? '';
    return id.isNotEmpty &&
        (id == _testTenantId || id == _liveTenantId);
  }

  /// Stops a call that targets a gym outside this app.
  static void ensureTenant(String? tenantId) {
    if (allows(tenantId)) return;
    throw TenantAccessException(_gymDenied);
  }

  /// Stops sign-in for accounts that belong to another gym.
  static void ensureAccount(String? tenantId) {
    if (allows(tenantId)) return;
    throw TenantAccessException(_accountDenied);
  }

  /// Stops creating gyms from a customer app.
  static void ensureGymCreationAllowed() {
    if (!isRestricted) return;
    throw TenantAccessException(_createDenied);
  }

  /// Stops the platform super-admin portal inside a customer app.
  static void ensurePlatformAdminAllowed() {
    if (!isRestricted) return;
    throw TenantAccessException(_adminDenied);
  }

  /// Stops a push that would reach gyms outside this app.
  static void ensureBroadcast({
    required String targetAudience,
    String? targetTenantId,
  }) {
    if (!isRestricted) return;
    if (targetAudience == 'specific_gym' && allows(targetTenantId)) return;
    throw TenantAccessException(_broadcastDenied);
  }

  /// Loads `white_label/active.json` from the app bundle.
  static Future<void> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw WhiteLabelConfigException(
        'white_label/active.json must be a JSON object.',
      );
    }
    applyMap(Map<String, dynamic>.from(decoded));
    validate();
  }

  /// Applies a config map. Used by [load] and by tests.
  static void applyMap(Map<String, dynamic> raw) {
    final mode = _pick(raw, 'WL_MODE');
    if (mode != null) {
      _mode = mode.toLowerCase() == 'white_label'
          ? WhiteLabelMode.whiteLabel
          : WhiteLabelMode.platform;
    }
    _assign(raw, 'WL_TEST_TENANT_ID', (value) => _testTenantId = value);
    _assign(raw, 'WL_LIVE_TENANT_ID', (value) => _liveTenantId = value);
    _assign(raw, 'WL_APP_NAME', (value) => _appName = value);
    _assign(raw, 'WL_APP_NAME_PREFIX', (value) => _appNamePrefix = value);
    _assign(raw, 'WL_APP_NAME_SUFFIX', (value) => _appNameSuffix = value);
    _assign(raw, 'WL_TAGLINE', (value) => _tagline = value);
    _assign(raw, 'WL_APP_DESCRIPTION', (value) => _appDescription = value);
    _assign(raw, 'WL_DISPLAY_NAME', (value) => _displayName = value);
    _assign(raw, 'WL_SUPPORT_EMAIL', (value) => _supportEmail = value);
    _assign(raw, 'WL_ADMIN_EMAIL', (value) => _adminEmail = value);
    _assign(raw, 'WL_SUPPORT_PHONE', (value) => _supportPhone = value);
  }

  /// Rejects a white-label build that does not name two different gyms.
  static void validate() {
    if (!isRestricted) return;
    if (_testTenantId.isEmpty || _liveTenantId.isEmpty) {
      throw WhiteLabelConfigException(
        'White-label mode needs both WL_TEST_TENANT_ID and WL_LIVE_TENANT_ID in white_label/active.json.',
      );
    }
    if (_testTenantId == _liveTenantId) {
      throw WhiteLabelConfigException(
        'WL_TEST_TENANT_ID and WL_LIVE_TENANT_ID must be two different gym ids.',
      );
    }
  }

  /// Restores the main GCRM app defaults. Tests call this in tearDown.
  static void debugReset() {
    _mode = WhiteLabelMode.platform;
    _testTenantId = '';
    _liveTenantId = '';
    _appName = 'GCRM ONE';
    _appNamePrefix = 'GCRM ';
    _appNameSuffix = 'ONE';
    _tagline = 'All Your Gym Operations, Unified';
    _appDescription =
        'The modern multi-vendor operating system for gym chains, independent fitness clubs, trainers, and members.';
    _displayName = 'GCRM One';
    _supportEmail = 'support@gcrmone.com';
    _adminEmail = 'admin@gcrmone.com';
    _supportPhone = '+1 (800) 555-GCRM (4276)';
  }

  static void _assign(
    Map<String, dynamic> raw,
    String key,
    void Function(String value) set,
  ) {
    final value = _pick(raw, key);
    if (value != null) set(value);
  }

  static String? _pick(Map<String, dynamic> raw, String key) {
    final value = raw[key];
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }
}
