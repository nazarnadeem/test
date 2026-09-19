import 'package:intl/intl.dart';

/// Gym Member Model representing enrolled gym members.
/// Contains personal profile information, contact info,
/// optional emergency contact info, and active membership terms.
class GymMemberModel {
  final String id;
  final String? tenantId;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String gender; // 'Male', 'Female', 'Other'
  final DateTime? dateOfBirth;
  final String phone;
  final String email;
  final String address;
  final double? weight; // in kg (e.g. 75.5)
  final double? height; // in cm (e.g. 178.0)
  final String? goal; // Fitness goal e.g. 'Weight Loss', 'Muscle Building', etc.
  final String? emergencyContactName;
  final String? emergencyPhone;
  final String? emergencyContactRelation; // 'Parent', 'Spouse', 'Sibling', 'Friend', 'Guardian', 'Other'
  final String? membershipPlanId;
  final String membershipPlan;
  final String? batchId;
  final String? batchName;
  final bool isLifetimeFree;
  final DateTime startDate;
  final DateTime expiryDate;
  final bool isActive;
  final int totalCheckIns;
  final DateTime? lastCheckIn;
  final String? discountType; // 'Fixed' or 'Percentage'
  final double? discountValue; // Fixed amount (₹) or percentage value (%)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GymMemberModel({
    required this.id,
    this.tenantId,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    this.gender = 'Male',
    this.dateOfBirth,
    required this.phone,
    this.email = '',
    this.address = '',
    this.weight,
    this.height,
    this.goal,
    this.emergencyContactName,
    this.emergencyPhone,
    this.emergencyContactRelation,
    this.membershipPlanId,
    required this.membershipPlan,
    this.batchId,
    this.batchName,
    this.isLifetimeFree = false,
    required this.startDate,
    required this.expiryDate,
    this.isActive = true,
    this.totalCheckIns = 0,
    this.lastCheckIn,
    this.discountType,
    this.discountValue,
    this.createdAt,
    this.updatedAt,
  });

  /// Computed Full Name
  String get fullName => '$firstName $lastName'.trim();

  /// Alias for membershipPlan
  String get planName => membershipPlan;

  /// Computed Age from Date of Birth
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int calculatedAge = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      calculatedAge--;
    }
    return calculatedAge >= 0 ? calculatedAge : 0;
  }

  /// Formatted Date of Birth string in DD/MM/YYYY (e.g. 15/06/1996)
  String get formattedDob {
    if (dateOfBirth == null) return 'Not Provided';
    return DateFormat('dd/MM/yyyy').format(dateOfBirth!);
  }

  /// Formatted Weight string (e.g. 75 kg or Not set)
  String get formattedWeight {
    if (weight == null) return 'Not set';
    return '${weight!.toStringAsFixed(weight! % 1 == 0 ? 0 : 1)} kg';
  }

  /// Formatted Height string (e.g. 178 cm or Not set)
  String get formattedHeight {
    if (height == null) return 'Not set';
    return '${height!.toStringAsFixed(height! % 1 == 0 ? 0 : 1)} cm';
  }

  /// Formatted Fitness Goal (e.g. Muscle Building or General Fitness)
  String get formattedGoal {
    if (goal == null || goal!.trim().isEmpty) return 'General Fitness';
    return goal!;
  }

  /// Computed Body Mass Index (BMI)
  double? get bmi {
    if (weight == null || height == null || height! <= 0) return null;
    final heightInMeters = height! / 100.0;
    return weight! / (heightInMeters * heightInMeters);
  }

  /// Formatted BMI string
  String get formattedBmi {
    if (bmi == null) return 'N/A';
    return bmi!.toStringAsFixed(1);
  }

  /// Check if a discount is applied
  bool get hasDiscount => discountValue != null && discountValue! > 0;

  /// Formatted Discount label (e.g. '₹500 OFF' or '10% OFF')
  String get formattedDiscount {
    if (!hasDiscount) return 'No Discount';
    if (discountType == 'Percentage') {
      final isInt = discountValue! % 1 == 0;
      return '${isInt ? discountValue!.toInt() : discountValue}% OFF';
    } else {
      final isInt = discountValue! % 1 == 0;
      return '₹${isInt ? discountValue!.toInt() : discountValue!.toStringAsFixed(2)} OFF';
    }
  }

  /// Calculate discount amount in ₹ given a base package price
  double calculateDiscountAmount(double basePrice) {
    if (!hasDiscount || basePrice <= 0) return 0.0;
    if (discountType == 'Percentage') {
      return (basePrice * (discountValue! / 100.0)).clamp(0.0, basePrice);
    } else {
      return discountValue!.clamp(0.0, basePrice);
    }
  }

  /// Calculate final payable price in ₹ after discount
  double calculateFinalPrice(double basePrice) {
    final discount = calculateDiscountAmount(basePrice);
    return (basePrice - discount).clamp(0.0, double.infinity);
  }

  /// Formatted Expiry Date string (e.g. 25 Dec 2026 or Never (Lifetime Free))
  String get formattedExpiry {
    if (isLifetimeFree) return 'Never (Lifetime Free)';
    return DateFormat('dd MMM yyyy').format(expiryDate);
  }

  /// Formatted Start Date string
  String get formattedStart {
    return DateFormat('dd MMM yyyy').format(startDate);
  }

  /// Expiry status helpers
  bool get isExpiringSoon {
    if (isLifetimeFree) return false;
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 7;
  }

  bool get isExpired {
    if (isLifetimeFree) return false;
    return expiryDate.isBefore(DateTime.now());
  }

  int get daysRemaining {
    if (isLifetimeFree) return 99999;
    final diff = expiryDate.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Check if emergency contact details are provided
  bool get hasEmergencyContact =>
      (emergencyContactName != null && emergencyContactName!.trim().isNotEmpty) ||
      (emergencyPhone != null && emergencyPhone!.trim().isNotEmpty);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'firstName': firstName,
      'lastName': lastName,
      'photoUrl': photoUrl,
      'gender': gender,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'phone': phone,
      'email': email,
      'address': address,
      'weight': weight,
      'height': height,
      'goal': goal,
      'emergencyContactName': emergencyContactName,
      'emergencyPhone': emergencyPhone,
      'emergencyContactRelation': emergencyContactRelation,
      'membershipPlanId': membershipPlanId,
      'membershipPlan': membershipPlan,
      'batchId': batchId,
      'batchName': batchName,
      'isLifetimeFree': isLifetimeFree,
      'startDate': startDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'isActive': isActive,
      'totalCheckIns': totalCheckIns,
      'lastCheckIn': lastCheckIn?.toIso8601String(),
      'discountType': discountType,
      'discountValue': discountValue,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory GymMemberModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    // Split fullName if firstName/lastName were not stored separately
    String fName = json['firstName'] as String? ?? '';
    String lName = json['lastName'] as String? ?? '';
    if (fName.isEmpty && json['fullName'] != null) {
      final parts = (json['fullName'] as String).trim().split(' ');
      fName = parts.first;
      if (parts.length > 1) {
        lName = parts.sublist(1).join(' ');
      }
    }

    final isLifetime = json['isLifetimeFree'] as bool? ?? false;
    final parsedStart = parseDate(json['startDate']) ?? DateTime.now();
    final parsedExpiry = parseDate(json['expiryDate']) ??
        (isLifetime
            ? DateTime(2099, 12, 31)
            : parsedStart.add(const Duration(days: 30)));

    return GymMemberModel(
      id: docId ?? (json['id'] as String? ?? ''),
      tenantId: json['tenantId'] as String?,
      firstName: fName.isNotEmpty ? fName : 'Member',
      lastName: lName,
      photoUrl: json['photoUrl'] as String?,
      gender: json['gender'] as String? ?? 'Male',
      dateOfBirth: parseDate(json['dateOfBirth']),
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      weight: parseDouble(json['weight']),
      height: parseDouble(json['height']),
      goal: json['goal'] as String?,
      emergencyContactName: json['emergencyContactName'] as String?,
      emergencyPhone: json['emergencyPhone'] as String?,
      emergencyContactRelation: json['emergencyContactRelation'] as String?,
      membershipPlanId: json['membershipPlanId'] as String?,
      membershipPlan: json['membershipPlan'] as String? ??
          (isLifetime ? 'Lifetime Free' : 'Standard Pass'),
      batchId: json['batchId'] as String?,
      batchName: json['batchName'] as String?,
      isLifetimeFree: isLifetime,
      startDate: parsedStart,
      expiryDate: parsedExpiry,
      isActive: json['isActive'] as bool? ?? true,
      totalCheckIns: (json['totalCheckIns'] as num?)?.toInt() ?? 0,
      lastCheckIn: parseDate(json['lastCheckIn']),
      discountType: json['discountType'] as String?,
      discountValue: parseDouble(json['discountValue']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  GymMemberModel copyWith({
    String? id,
    String? tenantId,
    String? firstName,
    String? lastName,
    String? photoUrl,
    String? gender,
    DateTime? dateOfBirth,
    String? phone,
    String? email,
    String? address,
    double? weight,
    double? height,
    String? goal,
    String? emergencyContactName,
    String? emergencyPhone,
    String? emergencyContactRelation,
    String? membershipPlanId,
    String? membershipPlan,
    String? batchId,
    String? batchName,
    bool? isLifetimeFree,
    DateTime? startDate,
    DateTime? expiryDate,
    bool? isActive,
    int? totalCheckIns,
    DateTime? lastCheckIn,
    String? discountType,
    double? discountValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GymMemberModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      photoUrl: photoUrl ?? this.photoUrl,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      goal: goal ?? this.goal,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      membershipPlanId: membershipPlanId ?? this.membershipPlanId,
      membershipPlan: membershipPlan ?? this.membershipPlan,
      batchId: batchId ?? this.batchId,
      batchName: batchName ?? this.batchName,
      isLifetimeFree: isLifetimeFree ?? this.isLifetimeFree,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
      totalCheckIns: totalCheckIns ?? this.totalCheckIns,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Paginated Result wrapper for Gym Members server-side pagination & filtering
class PaginatedMembersResult {
  final List<GymMemberModel> members;
  final dynamic lastDocument;
  final bool hasMore;
  final int totalCount;

  const PaginatedMembersResult({
    required this.members,
    this.lastDocument,
    required this.hasMore,
    required this.totalCount,
  });
}
