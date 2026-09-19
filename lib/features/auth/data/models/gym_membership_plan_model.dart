import 'package:flutter/material.dart';

/// Gym Membership Plan Model for gym facilities / tenants.
/// Used by Gym Admins to define their gym's membership packages,
/// pricing tiers, duration, plan type (Monthly, Quarterly, Yearly),
/// access type, max check-ins per day, perks, and enrollment terms.
class GymMembershipPlanModel {
  final String id;
  final String? tenantId;
  final String name;
  final String tagline; // Description / Tagline
  final double price; // Package fee (₹)
  final double admissionFee; // One-time registration / onboarding fee (₹)
  final int durationDays; // Duration in days (e.g. 30 for 1 Month, 90 for 3M, 365 for 1 Year)
  final String billingCycle; // Plan Type: 'Monthly', 'Quarterly', 'Half-Yearly', 'Yearly', 'Custom'
  final String accessType; // '24/7 Full Access', 'Standard Hours', 'Peak Hours Only', 'Off-Peak (Daytime)', 'Weekend Only', 'Classes & Floor'
  final int maxCheckInsPerDay; // 0 = Unlimited, 1 = 1/day, 2 = 2/day, etc.
  final String category; // 'Strength & Cardio', 'Personal Training', 'HIIT & Group', 'VIP All-Access', 'Standard'
  final List<String> features;
  final bool isPopular;
  final bool isActive;
  final int enrolledMembersCount;
  final Color accentColor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GymMembershipPlanModel({
    required this.id,
    this.tenantId,
    required this.name,
    this.tagline = '',
    required this.price,
    this.admissionFee = 0.0,
    this.durationDays = 30,
    this.billingCycle = 'Monthly',
    this.accessType = '24/7 Full Access',
    this.maxCheckInsPerDay = 0,
    this.category = 'Strength & Cardio',
    required this.features,
    this.isPopular = false,
    this.isActive = true,
    this.enrolledMembersCount = 0,
    this.accentColor = const Color(0xFFFF5722),
    this.createdAt,
    this.updatedAt,
  });

  /// Alias for description
  String get description => tagline;

  /// Alias for plan type (Monthly, Quarterly, Yearly, etc.)
  String get planType => billingCycle;

  /// Formatted duration string helper
  String get durationLabel {
    if (durationDays == 365) return '1 Year (365 Days)';
    if (durationDays == 180) return '6 Months (180 Days)';
    if (durationDays == 90) return '3 Months (90 Days)';
    if (durationDays == 30) return '1 Month (30 Days)';
    if (durationDays % 30 == 0) return '${durationDays ~/ 30} Months';
    return '$durationDays Days';
  }

  /// Max check-ins per day label
  String get maxCheckInsLabel {
    if (maxCheckInsPerDay == 0) return 'Unlimited Daily Check-Ins';
    if (maxCheckInsPerDay == 1) return '1 Check-In / Day';
    return '$maxCheckInsPerDay Check-Ins / Day';
  }

  /// Formatted price with Rupee symbol
  String get formattedPrice {
    final intPrice = price.toInt();
    if (price == intPrice.toDouble()) {
      return '₹$intPrice';
    }
    return '₹${price.toStringAsFixed(2)}';
  }

  /// Approximate equivalent monthly rate for long-term packages
  String? get monthlyEquivalentLabel {
    if (durationDays <= 30) return null;
    final double months;
    if (durationDays == 365) {
      months = 12.0;
    } else if (durationDays == 180) {
      months = 6.0;
    } else if (durationDays == 90) {
      months = 3.0;
    } else {
      months = durationDays / 30.0;
    }
    final perMonth = (price / months).round();
    return '₹$perMonth / month';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'name': name,
      'tagline': tagline,
      'price': price,
      'admissionFee': admissionFee,
      'durationDays': durationDays,
      'billingCycle': billingCycle,
      'accessType': accessType,
      'maxCheckInsPerDay': maxCheckInsPerDay,
      'category': category,
      'features': features,
      'isPopular': isPopular,
      'isActive': isActive,
      'enrolledMembersCount': enrolledMembersCount,
      'accentColor': accentColor.toARGB32(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory GymMembershipPlanModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is String) {
        parsedCreatedAt = DateTime.tryParse(json['createdAt'] as String);
      }
    }

    DateTime? parsedUpdatedAt;
    if (json['updatedAt'] != null) {
      if (json['updatedAt'] is String) {
        parsedUpdatedAt = DateTime.tryParse(json['updatedAt'] as String);
      }
    }

    return GymMembershipPlanModel(
      id: docId ?? (json['id'] as String? ?? ''),
      tenantId: json['tenantId'] as String?,
      name: json['name'] as String? ?? 'Membership Plan',
      tagline: json['tagline'] as String? ?? (json['description'] as String? ?? ''),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      admissionFee: (json['admissionFee'] as num?)?.toDouble() ?? 0.0,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
      billingCycle: json['billingCycle'] as String? ?? (json['planType'] as String? ?? 'Monthly'),
      accessType: json['accessType'] as String? ?? '24/7 Full Access',
      maxCheckInsPerDay: (json['maxCheckInsPerDay'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? 'Strength & Cardio',
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isPopular: json['isPopular'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      enrolledMembersCount: (json['enrolledMembersCount'] as num?)?.toInt() ?? 0,
      accentColor: json['accentColor'] != null
          ? Color(json['accentColor'] as int)
          : const Color(0xFFFF5722),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  GymMembershipPlanModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? tagline,
    double? price,
    double? admissionFee,
    int? durationDays,
    String? billingCycle,
    String? accessType,
    int? maxCheckInsPerDay,
    String? category,
    List<String>? features,
    bool? isPopular,
    bool? isActive,
    int? enrolledMembersCount,
    Color? accentColor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GymMembershipPlanModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      price: price ?? this.price,
      admissionFee: admissionFee ?? this.admissionFee,
      durationDays: durationDays ?? this.durationDays,
      billingCycle: billingCycle ?? this.billingCycle,
      accessType: accessType ?? this.accessType,
      maxCheckInsPerDay: maxCheckInsPerDay ?? this.maxCheckInsPerDay,
      category: category ?? this.category,
      features: features ?? this.features,
      isPopular: isPopular ?? this.isPopular,
      isActive: isActive ?? this.isActive,
      enrolledMembersCount: enrolledMembersCount ?? this.enrolledMembersCount,
      accentColor: accentColor ?? this.accentColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Preset template options for quick plan creation
  static List<GymMembershipPlanModel> get defaultGymTemplates => [
        const GymMembershipPlanModel(
          id: 'gplan_gold_annual',
          name: 'Gold Annual Pass',
          tagline: 'Full gym access + personal locker & steam bath',
          price: 18000.0,
          admissionFee: 0.0,
          durationDays: 365,
          billingCycle: 'Yearly',
          accessType: '24/7 Full Access',
          maxCheckInsPerDay: 0,
          category: 'Strength & Cardio',
          features: [
            '24/7 Gym Floor Access',
            'Full Cardio & Strength Zones',
            'Personal Locker & Shower',
            'Steam & Sauna Access',
            '1x Free Trainer Consultation',
          ],
          isPopular: true,
          isActive: true,
          enrolledMembersCount: 48,
          accentColor: Color(0xFFFF5722),
        ),
        const GymMembershipPlanModel(
          id: 'gplan_plat_all_access',
          name: 'Platinum All-Access',
          tagline: 'VIP unlimited access with dedicated PT & nutrition support',
          price: 28000.0,
          admissionFee: 0.0,
          durationDays: 365,
          billingCycle: 'Yearly',
          accessType: '24/7 Full Access',
          maxCheckInsPerDay: 0,
          category: 'VIP All-Access',
          features: [
            'VIP Floor & Lounge Access',
            '4x Monthly 1-on-1 PT Sessions',
            'Custom Diet & Nutrition Chart',
            'Unlimited Group Classes & Yoga',
            'Complimentary Towel & Shaker Kit',
          ],
          isPopular: false,
          isActive: true,
          enrolledMembersCount: 22,
          accentColor: Color(0xFFA855F7),
        ),
        const GymMembershipPlanModel(
          id: 'gplan_monthly_hiit',
          name: 'Monthly HIIT & Strength',
          tagline: 'Ideal for month-to-month dynamic training & fat loss',
          price: 2499.0,
          admissionFee: 500.0,
          durationDays: 30,
          billingCycle: 'Monthly',
          accessType: 'Peak & Group Hours',
          maxCheckInsPerDay: 1,
          category: 'HIIT & Group',
          features: [
            'High-Intensity Functional Zone',
            'CrossFit & Kettlebell Area',
            'Locker Room Access',
            'Bi-weekly Body Composition Scan',
          ],
          isPopular: false,
          isActive: true,
          enrolledMembersCount: 35,
          accentColor: Color(0xFF00E599),
        ),
        const GymMembershipPlanModel(
          id: 'gplan_quarterly_cardio',
          name: 'Quarterly Cardio Plus',
          tagline: '3-Month focused endurance and treadmill coaching',
          price: 6500.0,
          admissionFee: 0.0,
          durationDays: 90,
          billingCycle: 'Quarterly',
          accessType: 'Standard (Gym Hours)',
          maxCheckInsPerDay: 1,
          category: 'Strength & Cardio',
          features: [
            'Full Cardio Theater Access',
            'Stretching & Core Zone',
            'Hydration Bar Access',
            'Shower & Locker Facility',
          ],
          isPopular: false,
          isActive: true,
          enrolledMembersCount: 19,
          accentColor: Color(0xFF06B6D4),
        ),
      ];
}
