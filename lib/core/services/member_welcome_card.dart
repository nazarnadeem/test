import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/data/models/gym_member_model.dart';
import '../../features/auth/data/models/gym_tenant_model.dart';
import '../utils/icard_generator.dart';
import 'whatsapp_service.dart';

/// Builds a member I-Card and sends it on the welcome WhatsApp template.
class MemberWelcomeCard {
  /// Enrollment stays successful even when the card or WhatsApp send fails.
  static Future<void> sendQuietly({
    required GymMemberModel member,
    GymTenantModel? tenant,
  }) async {
    try {
      if (Firebase.apps.isEmpty) return;
      final tenantId = (member.tenantId ?? tenant?.id ?? '').trim();
      if (tenantId.isEmpty || member.id.trim().isEmpty) return;

      final uploaded = await uploadCard(member: member, tenant: tenant);
      final gymName = (tenant?.gymName ?? '').trim();
      await WhatsAppService.sendWelcomeCard(
        tenantId: tenantId,
        memberId: member.id,
        phone: member.phone,
        memberName: member.fullName,
        gymName: gymName.isEmpty ? 'Gym' : gymName,
        documentUrl: uploaded.url,
        filename: uploaded.filename,
      );
    } catch (error, stack) {
      debugPrint('Welcome I-Card was not sent: $error\n$stack');
    }
  }

  /// Uploads the I-Card PDF and returns a link Meta can download.
  static Future<({String url, String filename})> uploadCard({
    required GymMemberModel member,
    GymTenantModel? tenant,
  }) async {
    final tenantId = (member.tenantId ?? tenant?.id ?? '').trim();
    if (tenantId.isEmpty || member.id.trim().isEmpty) {
      throw Exception('The I-Card needs a gym and member.');
    }
    final pdf = await ICardGenerator.generateICardDocument(
      member: member,
      tenant: tenant,
    );
    final bytes = await pdf.save();
    final filename = _filename(member);
    final ref = FirebaseStorage.instance.ref('tenants/$tenantId/members/${member.id}_icard.pdf');
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        contentDisposition: 'attachment; filename="$filename"',
      ),
    );
    return (url: await ref.getDownloadURL(), filename: filename);
  }

  static String _filename(GymMemberModel member) {
    final raw = 'ICard_${member.firstName}_${member.lastName}.pdf';
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'ICard.pdf' : cleaned;
  }
}
