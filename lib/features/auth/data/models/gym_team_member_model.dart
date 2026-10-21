import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Role designations for Gym Team members.
enum GymTeamRole {
  owner,
  manager,
  trainer;

  String get displayName {
    switch (this) {
      case GymTeamRole.owner:
        return 'Owner';
      case GymTeamRole.manager:
        return 'Manager';
      case GymTeamRole.trainer:
        return 'Trainer';
    }
  }

  String get badgeLabel {
    switch (this) {
      case GymTeamRole.owner:
        return 'OWNER';
      case GymTeamRole.manager:
        return 'MANAGER';
      case GymTeamRole.trainer:
        return 'TRAINER';
    }
  }

  Color get color {
    switch (this) {
      case GymTeamRole.owner:
        return const Color(0xFFA855F7);
      case GymTeamRole.manager:
        return const Color(0xFF06B6D4);
      case GymTeamRole.trainer:
        return const Color(0xFFF59E0B);
    }
  }

  IconData get icon {
    switch (this) {
      case GymTeamRole.owner:
        return Icons.workspace_premium_rounded;
      case GymTeamRole.manager:
        return Icons.manage_accounts_rounded;
      case GymTeamRole.trainer:
        return Icons.fitness_center_rounded;
    }
  }

  static GymTeamRole fromString(String? val) {
    if (val == null) return GymTeamRole.trainer;
    final clean = val.toLowerCase().trim();
    if (clean == 'owner') return GymTeamRole.owner;
    if (clean == 'manager') return GymTeamRole.manager;
    return GymTeamRole.trainer;
  }
}

/// Team member record model for Gym Admin staff & leadership management.
class GymTeamMemberRecord {
  final String id;
  final String? tenantId;
  final String fullName;
  final GymTeamRole role;
  final String? gender; // Specifically for Trainer / Team member ('Male', 'Female', 'Other')
  final String? experience; // Specifically for Trainer (e.g. '5 Years Exp')
  final String specialty;
  final String phone;
  final String email;
  final int activeClientsCount;
  final double rating;
  final bool isOnDuty;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final DateTime? createdAt;
  final Map<String, bool> attendanceLogs;

  const GymTeamMemberRecord({
    required this.id,
    this.tenantId,
    required this.fullName,
    required this.role,
    this.gender,
    this.experience,
    required this.specialty,
    required this.phone,
    this.email = '',
    this.activeClientsCount = 0,
    this.rating = 0,
    this.isOnDuty = true,
    this.imageBytes,
    this.imageUrl,
    this.createdAt,
    this.attendanceLogs = const {},
  });

  bool get isTrainer => role == GymTeamRole.trainer;
  bool get isOwner => role == GymTeamRole.owner;
  bool get isManager => role == GymTeamRole.manager;

  /// Returns dynamic attendance status for a given date based on registration date and logs
  bool isPresentOnDate(DateTime d) {
    final normD = DateTime(d.year, d.month, d.day);
    final reg = createdAt ?? DateTime(2026, 1, 15);
    final normReg = DateTime(reg.year, reg.month, reg.day);
    final now = DateTime.now();
    final normToday = DateTime(now.year, now.month, now.day);

    if (normD.isBefore(normReg) || normD.isAfter(normToday)) {
      return false; // Pre-registration or future date
    }

    final key = '${normD.year}-${normD.month.toString().padLeft(2, '0')}-${normD.day.toString().padLeft(2, '0')}';
    if (attendanceLogs.containsKey(key)) {
      return attendanceLogs[key]!;
    }

    if (normD.year == normToday.year && normD.month == normToday.month && normD.day == normToday.day) {
      return isOnDuty;
    }

    // Dynamic attendance: From the registration date onwards, all past days are marked as present/attended
    return true;
  }

  GymTeamMemberRecord copyWith({
    String? id,
    String? tenantId,
    String? fullName,
    GymTeamRole? role,
    String? gender,
    String? experience,
    String? specialty,
    String? phone,
    String? email,
    int? activeClientsCount,
    double? rating,
    bool? isOnDuty,
    Uint8List? imageBytes,
    String? imageUrl,
    DateTime? createdAt,
    Map<String, bool>? attendanceLogs,
  }) {
    return GymTeamMemberRecord(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      gender: gender ?? this.gender,
      experience: experience ?? this.experience,
      specialty: specialty ?? this.specialty,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      activeClientsCount: activeClientsCount ?? this.activeClientsCount,
      rating: rating ?? this.rating,
      isOnDuty: isOnDuty ?? this.isOnDuty,
      imageBytes: imageBytes ?? this.imageBytes,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      attendanceLogs: attendanceLogs ?? this.attendanceLogs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'fullName': fullName,
      'role': role.name,
      'gender': gender,
      'experience': experience,
      'specialty': specialty,
      'phone': phone,
      'email': email,
      'activeClientsCount': activeClientsCount,
      'rating': rating,
      'isOnDuty': isOnDuty,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.toIso8601String(),
      'attendanceLogs': attendanceLogs,
    };
  }

  factory GymTeamMemberRecord.fromJson(Map<String, dynamic> json, [String? docId]) {
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is String) {
        parsedCreatedAt = DateTime.tryParse(json['createdAt'] as String);
      } else {
        try {
          parsedCreatedAt = (json['createdAt'] as dynamic).toDate();
        } catch (_) {
          parsedCreatedAt = DateTime.tryParse(json['createdAt'].toString());
        }
      }
    }

    final Map<String, bool> parsedAttendance = {};
    if (json['attendanceLogs'] != null && json['attendanceLogs'] is Map) {
      final map = json['attendanceLogs'] as Map;
      map.forEach((k, v) {
        parsedAttendance[k.toString()] = v == true;
      });
    }

    return GymTeamMemberRecord(
      id: docId ?? (json['id'] as String? ?? ''),
      tenantId: json['tenantId'] as String?,
      fullName: json['fullName'] as String? ?? 'Team Member',
      role: GymTeamRole.fromString(json['role'] as String?),
      gender: json['gender'] as String?,
      experience: json['experience'] as String?,
      specialty: json['specialty'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      activeClientsCount: (json['activeClientsCount'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      isOnDuty: (json['isOnDuty'] as bool?) ?? true,
      imageUrl: json['imageUrl'] as String?,
      createdAt: parsedCreatedAt,
      attendanceLogs: parsedAttendance,
    );
  }
}
