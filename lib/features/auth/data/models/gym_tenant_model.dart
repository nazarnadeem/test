import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Gym Vendor / Tenant model representing each registered gym chain/facility.
enum SubscriptionTier {
  starter,
  growth,
  enterprise,
}

enum TenantStatus {
  pendingApproval,
  active,
  suspended,
}

class GymTenantModel {
  final String id;
  final String gymName;
  final String tradeLicense;
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final String? adminName;
  final String? adminEmail;
  final String? adminId;
  final String address;
  final String? phone;
  final String gymCode; // Referral / Branch code
  final String? logoUrl;
  final String primaryColorHex; // Hex color (e.g. #FF5722)
  final SubscriptionTier tier;
  final String? planId;
  final String? planName;
  final double? planPrice;
  final String? billingPeriod; // 'month' or 'year'
  final DateTime? planStartDate;
  final DateTime? planExpiryDate;
  final bool isLifetimeFree; // If true, gym has permanent free lifetime subscription
  final TenantStatus status;
  final int activeMembersCount;
  final int activeTrainersCount;
  final double monthlyRevenue;
  final DateTime createdAt;

  const GymTenantModel({
    required this.id,
    required this.gymName,
    this.tradeLicense = 'STANDARD-LICENSE',
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    this.adminName,
    this.adminEmail,
    this.adminId,
    required this.address,
    this.phone,
    required this.gymCode,
    this.logoUrl,
    this.primaryColorHex = '#FF5722',
    this.tier = SubscriptionTier.growth,
    this.planId,
    this.planName,
    this.planPrice,
    this.billingPeriod = 'year',
    this.planStartDate,
    this.planExpiryDate,
    this.isLifetimeFree = false,
    this.status = TenantStatus.active,
    this.activeMembersCount = 0,
    this.activeTrainersCount = 0,
    this.monthlyRevenue = 0.0,
    required this.createdAt,
  });

  String get effectiveAdminName => adminName ?? ownerName;
  String get effectiveAdminEmail => adminEmail ?? ownerEmail;
  String get effectivePlanName => isLifetimeFree ? 'Lifetime Free Plan' : (planName ?? tierName);

  /// Returns whether the gym facility is marked Active by Super Admin
  bool get isActive => status == TenantStatus.active;

  /// Returns whether the gym facility is suspended / marked inactive
  bool get isSuspended => status == TenantStatus.suspended;

  /// Returns whether the subscription plan is currently active
  bool get isPlanActive {
    if (isLifetimeFree) return true;
    if (planExpiryDate == null) return true;
    return planExpiryDate!.isAfter(DateTime.now());
  }

  /// Remaining days until plan expiration
  int get remainingDays {
    if (isLifetimeFree) return 99999;
    if (planExpiryDate == null) return 0;
    final diff = planExpiryDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Formatted duration string (e.g. "20 Aug 2026 – 20 Aug 2027" or "Lifetime Free Access")
  String get formattedPlanPeriod {
    if (isLifetimeFree) return 'Lifetime Free Access';
    final formatter = DateFormat('dd MMM yyyy');
    if (planStartDate != null && planExpiryDate != null) {
      return '${formatter.format(planStartDate!)} – ${formatter.format(planExpiryDate!)}';
    } else if (planExpiryDate != null) {
      return 'Expires ${formatter.format(planExpiryDate!)}';
    } else if (planStartDate != null) {
      return 'Started ${formatter.format(planStartDate!)}';
    }
    return 'Active Subscription';
  }

  /// Returns Flutter [Color] parsed from [primaryColorHex] with fallback to default theme primary.
  Color get primaryColor {
    try {
      String hex = primaryColorHex.replaceAll('#', '').replaceAll('0x', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse('0x$hex'));
    } catch (_) {
      return const Color(0xFFFF5722);
    }
  }

  String get tierName {
    switch (tier) {
      case SubscriptionTier.starter:
        return 'Starter';
      case SubscriptionTier.growth:
        return 'Growth Pro';
      case SubscriptionTier.enterprise:
        return 'Enterprise Custom';
    }
  }

  GymTenantModel copyWith({
    String? id,
    String? gymName,
    String? tradeLicense,
    String? ownerId,
    String? ownerName,
    String? ownerEmail,
    String? adminName,
    String? adminEmail,
    String? adminId,
    String? address,
    String? phone,
    String? gymCode,
    String? logoUrl,
    String? primaryColorHex,
    SubscriptionTier? tier,
    String? planId,
    String? planName,
    double? planPrice,
    String? billingPeriod,
    DateTime? planStartDate,
    DateTime? planExpiryDate,
    bool? isLifetimeFree,
    TenantStatus? status,
    int? activeMembersCount,
    int? activeTrainersCount,
    double? monthlyRevenue,
    DateTime? createdAt,
  }) {
    return GymTenantModel(
      id: id ?? this.id,
      gymName: gymName ?? this.gymName,
      tradeLicense: tradeLicense ?? this.tradeLicense,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      adminName: adminName ?? this.adminName,
      adminEmail: adminEmail ?? this.adminEmail,
      adminId: adminId ?? this.adminId,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gymCode: gymCode ?? this.gymCode,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      tier: tier ?? this.tier,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      planPrice: planPrice ?? this.planPrice,
      billingPeriod: billingPeriod ?? this.billingPeriod,
      planStartDate: planStartDate ?? this.planStartDate,
      planExpiryDate: planExpiryDate ?? this.planExpiryDate,
      isLifetimeFree: isLifetimeFree ?? this.isLifetimeFree,
      status: status ?? this.status,
      activeMembersCount: activeMembersCount ?? this.activeMembersCount,
      activeTrainersCount: activeTrainersCount ?? this.activeTrainersCount,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gymName': gymName,
      'tradeLicense': tradeLicense,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'adminName': adminName ?? ownerName,
      'adminEmail': adminEmail ?? ownerEmail,
      'adminId': adminId ?? ownerId,
      'address': address,
      'phone': phone,
      'gymCode': gymCode,
      'logoUrl': logoUrl,
      'primaryColorHex': primaryColorHex,
      'tier': tier.name,
      'planId': planId,
      'planName': planName,
      'planPrice': planPrice,
      'billingPeriod': billingPeriod,
      'planStartDate': planStartDate?.toIso8601String(),
      'planExpiryDate': planExpiryDate?.toIso8601String(),
      'isLifetimeFree': isLifetimeFree,
      'status': status.name,
      'activeMembersCount': activeMembersCount,
      'activeTrainersCount': activeTrainersCount,
      'monthlyRevenue': monthlyRevenue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GymTenantModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      if (value is DateTime) return value;
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    return GymTenantModel(
      id: json['id'] as String,
      gymName: json['gymName'] as String,
      tradeLicense: (json['tradeLicense'] as String?) ?? 'STANDARD-LICENSE',
      ownerId: (json['ownerId'] as String?) ?? (json['id'] as String),
      ownerName: (json['ownerName'] as String?) ?? 'Gym Owner',
      ownerEmail: (json['ownerEmail'] as String?) ?? '',
      adminName: json['adminName'] as String?,
      adminEmail: json['adminEmail'] as String?,
      adminId: json['adminId'] as String?,
      address: (json['address'] as String?) ?? '',
      phone: json['phone'] as String?,
      gymCode: (json['gymCode'] as String?) ?? 'GYM-01',
      logoUrl: json['logoUrl'] as String?,
      primaryColorHex: (json['primaryColorHex'] as String?) ?? '#FF5722',
      tier: SubscriptionTier.values.firstWhere(
        (t) => t.name == json['tier'],
        orElse: () => SubscriptionTier.growth,
      ),
      planId: json['planId'] as String?,
      planName: json['planName'] as String?,
      planPrice: (json['planPrice'] as num?)?.toDouble(),
      billingPeriod: (json['billingPeriod'] as String?) ?? 'year',
      planStartDate: parseDate(json['planStartDate']),
      planExpiryDate: parseDate(json['planExpiryDate']),
      isLifetimeFree: json['isLifetimeFree'] as bool? ?? false,
      status: TenantStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TenantStatus.active,
      ),
      activeMembersCount: json['activeMembersCount'] as int? ?? 0,
      activeTrainersCount: json['activeTrainersCount'] as int? ?? 0,
      monthlyRevenue: (json['monthlyRevenue'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}
