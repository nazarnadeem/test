import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/features/auth/data/models/gym_member_model.dart';
import 'package:gcrm_one/features/auth/data/models/gym_membership_plan_model.dart';

void main() {
  group('Gym Member Plan Validity Schedule & Expiry Logic Tests', () {
    test('GymMemberModel computes isExpired and daysRemaining accurately for active plans', () {
      final now = DateTime.now();
      
      // Active member starting today for 30 days
      final activeMember = GymMemberModel(
        id: 'mem_1',
        tenantId: 'tenant_1',
        firstName: 'John',
        lastName: 'Doe',
        phone: '+91 9876543210',
        membershipPlan: 'Monthly Pass',
        startDate: now,
        expiryDate: now.add(const Duration(days: 30)),
      );
      expect(activeMember.isExpired, isFalse);
      expect(activeMember.daysRemaining, greaterThanOrEqualTo(29));
      expect(activeMember.formattedStart, isNotEmpty);
      expect(activeMember.formattedExpiry, isNotEmpty);
    });

    test('GymMemberModel flags expired status when ending date has passed', () {
      final now = DateTime.now();

      // Expired member whose plan ended yesterday
      final expiredMember = GymMemberModel(
        id: 'mem_2',
        tenantId: 'tenant_1',
        firstName: 'Jane',
        lastName: 'Smith',
        phone: '+91 9876543211',
        membershipPlan: 'Monthly Pass',
        startDate: now.subtract(const Duration(days: 60)),
        expiryDate: now.subtract(const Duration(days: 1)),
      );
      expect(expiredMember.isExpired, isTrue);
      expect(expiredMember.daysRemaining, equals(0));
    });

    test('Lifetime Free members are never expired regardless of dates', () {
      final now = DateTime.now();

      final lifetimeMember = GymMemberModel(
        id: 'mem_3',
        tenantId: 'tenant_1',
        firstName: 'Alex',
        lastName: 'VIP',
        phone: '+91 9876543212',
        membershipPlan: 'Lifetime Free',
        isLifetimeFree: true,
        startDate: now.subtract(const Duration(days: 100)),
        expiryDate: now.subtract(const Duration(days: 10)),
      );
      expect(lifetimeMember.isExpired, isFalse);
      expect(lifetimeMember.formattedExpiry, equals('Never (Lifetime Free)'));
    });

    test('Automatic End Date Calculation matches plan duration in days', () {
      const plan = GymMembershipPlanModel(
        id: 'plan_quarterly',
        tenantId: 'tenant_metro_01',
        name: 'Quarterly Pro',
        price: 4500,
        durationDays: 90,
        features: ['Gym Access'],
      );

      final now = DateTime.now();
      final startDate = now;
      final calculatedEndDate = startDate.add(Duration(days: plan.durationDays));

      final member = GymMemberModel(
        id: 'mem_auto_calc',
        tenantId: 'tenant_metro_01',
        firstName: 'Marcus',
        lastName: 'Brody',
        phone: '+91 9988776655',
        membershipPlan: plan.name,
        startDate: startDate,
        expiryDate: calculatedEndDate,
      );

      expect(member.startDate, equals(startDate));
      expect(member.expiryDate, equals(calculatedEndDate));
      expect(member.daysRemaining, greaterThanOrEqualTo(89));
      expect(member.isExpired, isFalse);
    });
  });
}
