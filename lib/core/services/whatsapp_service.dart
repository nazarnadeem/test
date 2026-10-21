import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Loads and saves per-gym WhatsApp sender settings.
class WhatsAppService {
  /// Sends welcome_member with the member I-Card attached as the template file.
  static Future<void> sendWelcomeCard({
    String? tenantId,
    required String phone,
    required String memberName,
    required String gymName,
    required String documentUrl,
    required String filename,
    String? memberId,
  }) async {
    if (Firebase.apps.isEmpty) {
      throw Exception('WhatsApp is unavailable until Firebase is connected.');
    }
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendMemberWelcomeCard');
      await callable.call(<String, dynamic>{
        if (tenantId != null && tenantId.trim().isNotEmpty) 'tenantId': tenantId.trim(),
        if (memberId != null && memberId.trim().isNotEmpty) 'memberId': memberId.trim(),
        'phone': phone.trim(),
        'memberName': memberName.trim(),
        'gymName': gymName.trim(),
        'documentUrl': documentUrl.trim(),
        'filename': filename.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'Welcome I-Card could not be sent.');
    }
  }

  /// Loads this gym's WhatsApp settings. The access token is never returned.
  static Future<GymWhatsAppSettings> loadSettings({String? tenantId}) async {
    if (Firebase.apps.isEmpty) {
      throw Exception('WhatsApp is unavailable until Firebase is connected.');
    }
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getGymWhatsAppSettings');
      final result = await callable.call(<String, dynamic>{
        if (tenantId != null && tenantId.trim().isNotEmpty) 'tenantId': tenantId.trim(),
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return GymWhatsAppSettings.fromMap(data);
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'WhatsApp settings could not be loaded.');
    }
  }

  /// Saves optional per-gym WhatsApp sender details. A blank token keeps the saved token.
  static Future<GymWhatsAppSettings> saveSettings({
    String? tenantId,
    required String phoneNumberId,
    required String accessToken,
    required String templates,
  }) async {
    if (Firebase.apps.isEmpty) {
      throw Exception('WhatsApp is unavailable until Firebase is connected.');
    }
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('saveGymWhatsAppSettings');
      final result = await callable.call(<String, dynamic>{
        if (tenantId != null && tenantId.trim().isNotEmpty) 'tenantId': tenantId.trim(),
        'phoneNumberId': phoneNumberId.trim(),
        'accessToken': accessToken.trim(),
        'templates': templates,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return GymWhatsAppSettings.fromMap(data);
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? 'WhatsApp settings could not be saved.');
    }
  }
}

/// WhatsApp sender settings for one gym. The access token is not included.
class GymWhatsAppSettings {
  static const List<String> defaultTemplates = [
    'welcome_member',
    'membership_expired_reminder',
    'membership_expiry_reminder',
  ];

  final String phoneNumberId;
  final bool tokenSaved;
  final List<String> templates;

  const GymWhatsAppSettings({
    required this.phoneNumberId,
    required this.tokenSaved,
    required this.templates,
  });

  String get templatesText => templates.join(', ');

  factory GymWhatsAppSettings.fromMap(Map<String, dynamic> data) {
    final raw = data['templates'];
    final names = <String>[];
    if (raw is List) {
      for (final item in raw) {
        final name = item.toString().trim();
        if (name.isNotEmpty) names.add(name);
      }
    } else if (raw is String) {
      names.addAll(raw.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty));
    }
    final templates = [
      names.isNotEmpty ? names[0] : defaultTemplates[0],
      names.length > 1 ? names[1] : defaultTemplates[1],
      names.length > 2 ? names[2] : defaultTemplates[2],
    ];
    return GymWhatsAppSettings(
      phoneNumberId: data['phoneNumberId']?.toString().trim() ?? '',
      tokenSaved: data['tokenSaved'] == true,
      templates: templates,
    );
  }
}

/// Converts a stored member phone into WhatsApp digits, defaulting to India.
String? normalizeWhatsAppRecipient(String rawPhone, {String countryCode = '91'}) {
  var digits = rawPhone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0') && digits.length == 11) {
    digits = digits.substring(1);
  }
  if (digits.length == 10) digits = '$countryCode$digits';
  if (digits.length < 11 || digits.length > 15) return null;
  return digits;
}
