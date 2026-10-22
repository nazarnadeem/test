import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../features/auth/data/models/gym_member_model.dart';

/// Secure QR Code Service for Member I-Cards and Admin Verification.
///
/// Ensures privacy:
/// - Outside app (system camera/generic QR reader): Generates an opaque verification URL
///   without revealing any personal info (no name, phone, photo, or medical/payment data).
/// - Within app: Decodes verification tokens or direct IDs to validate membership,
///   record attendance check-in, and display success/error details.
class MemberQrService {
  static const String _domain = 'https://gcrmone.app/pass';
  static const String _secretSalt = 'gcrm_one_secure_pass_salt_2026';

  /// Generates a privacy-preserving QR code payload for a gym member.
  /// If scanned outside the app, it appears as a secure URL without exposing details.
  static String generateQrPayload({
    required GymMemberModel member,
    required String tenantId,
  }) {
    final memberId = member.id.trim();
    final tid = tenantId.trim();

    // Generate cryptographic hash signature
    final hmac = Hmac(sha256, utf8.encode(_secretSalt));
    final signature = hmac.convert(utf8.encode('$tid:$memberId')).toString().substring(0, 12);

    return '$_domain?t=${Uri.encodeComponent(tid)}&m=${Uri.encodeComponent(memberId)}&sig=$signature';
  }

  /// Parses scanned raw QR text from camera or manual input.
  /// Supports:
  /// 1. Secure GCRM One URL (e.g. https://gcrmone.app/pass?t=...&m=...&sig=...)
  /// 2. Deep links (gcrmone://checkin?m=...)
  /// 3. Direct Member ID fallback (mem_...)
  static Map<String, String>? parsePayload(String rawData) {
    final trimmed = rawData.trim();
    if (trimmed.isEmpty) return null;

    // Check if it's an HTTPS or custom scheme URI
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('gcrmone://')) {
      try {
        final uri = Uri.parse(trimmed);
        final memberId = uri.queryParameters['m'] ?? uri.queryParameters['memberId'] ?? uri.queryParameters['id'];
        final tenantId = uri.queryParameters['t'] ?? uri.queryParameters['tenantId'] ?? '';
        final sig = uri.queryParameters['sig'] ?? '';

        if (memberId != null && memberId.isNotEmpty) {
          return {
            'memberId': memberId,
            'tenantId': tenantId,
            'signature': sig,
            'raw': trimmed,
          };
        }
      } catch (_) {
        // Fallback to plain parsing
      }
    }

    // Direct plain member ID fallback (e.g. mem_xxx or alphanumeric)
    return {
      'memberId': trimmed,
      'tenantId': '',
      'signature': '',
      'raw': trimmed,
    };
  }
}
