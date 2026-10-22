import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/utils/member_qr_service.dart';
import 'package:gcrm_one/features/auth/data/models/gym_member_model.dart';

void main() {
  group('MemberQrService Privacy & Verification Tests', () {
    final testMember = GymMemberModel(
      id: 'mem_marcus_777',
      tenantId: 'tenant_gold_gym_01',
      firstName: 'Marcus',
      lastName: 'Sterling',
      gender: 'Male',
      dateOfBirth: DateTime(1995, 4, 12),
      phone: '+91 98765 43210',
      email: 'marcus.s@example.com',
      address: 'Private Residence Address',
      membershipPlan: 'Diamond Annual Pass',
      startDate: DateTime(2026, 1, 1),
      expiryDate: DateTime(2027, 1, 1),
      isActive: true,
      totalCheckIns: 14,
    );

    test('generateQrPayload protects privacy and does not expose sensitive data', () {
      final payload = MemberQrService.generateQrPayload(
        member: testMember,
        tenantId: 'tenant_gold_gym_01',
      );

      // Must be a valid URL
      expect(payload.startsWith('https://gcrmone.app/pass?'), isTrue);

      // Must NOT contain sensitive private info in raw text
      expect(payload.contains('Marcus'), isFalse);
      expect(payload.contains('Sterling'), isFalse);
      expect(payload.contains('98765'), isFalse);
      expect(payload.contains('marcus.s@example.com'), isFalse);
      expect(payload.contains('Private Residence'), isFalse);
      expect(payload.contains('Diamond Annual Pass'), isFalse);

      // Must contain secure token components
      expect(payload.contains('t=tenant_gold_gym_01'), isTrue);
      expect(payload.contains('m=mem_marcus_777'), isTrue);
      expect(payload.contains('sig='), isTrue);
    });

    test('parsePayload decodes official URL into member verification data', () {
      final payload = MemberQrService.generateQrPayload(
        member: testMember,
        tenantId: 'tenant_gold_gym_01',
      );

      final parsed = MemberQrService.parsePayload(payload);
      expect(parsed, isNotNull);
      expect(parsed!['memberId'], 'mem_marcus_777');
      expect(parsed['tenantId'], 'tenant_gold_gym_01');
      expect(parsed['signature'], isNotEmpty);
    });

    test('parsePayload supports deep link and plain ID fallbacks', () {
      final deepLink = MemberQrService.parsePayload('gcrmone://checkin?m=mem_test_888&t=tenant_01');
      expect(deepLink, isNotNull);
      expect(deepLink!['memberId'], 'mem_test_888');

      final directId = MemberQrService.parsePayload('mem_plain_id_999');
      expect(directId, isNotNull);
      expect(directId!['memberId'], 'mem_plain_id_999');
    });
  });
}
