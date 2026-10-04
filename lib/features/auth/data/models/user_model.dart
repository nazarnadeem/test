import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// User Role definitions for GCRM One multi-vendor platform.
enum UserRole {
  superAdmin,
  gymOwner,
  trainer,
  member,
}

extension UserRoleExtension on UserRole {
  static UserRole fromString(String? value) {
    if (value == null) return UserRole.member;
    final clean = value.toLowerCase().trim();
    if (clean == 'superadmin' || clean == 'super_admin') return UserRole.superAdmin;
    if (clean == 'gymowner' ||
        clean == 'gym_owner' ||
        clean == 'admin' ||
        clean == 'gym_admin' ||
        clean == 'owner') {
      return UserRole.gymOwner;
    }
    if (clean == 'trainer' || clean == 'staff' || clean == 'coach') return UserRole.trainer;
    if (clean == 'member' || clean == 'gym_member') return UserRole.member;
    return UserRole.values.firstWhere(
      (role) => role.name.toLowerCase() == clean,
      orElse: () => UserRole.member,
    );
  }

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.gymOwner:
        return 'Gym Owner';
      case UserRole.trainer:
        return 'Trainer / Staff';
      case UserRole.member:
        return 'Gym Member';
    }
  }

  String get shortLabel {
    switch (this) {
      case UserRole.superAdmin:
        return 'PLATFORM ADMIN';
      case UserRole.gymOwner:
        return 'GYM OWNER';
      case UserRole.trainer:
        return 'TRAINER';
      case UserRole.member:
        return 'MEMBER';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.superAdmin:
        return AppColors.roleSuperAdmin;
      case UserRole.gymOwner:
        return AppColors.roleGymOwner;
      case UserRole.trainer:
        return AppColors.roleTrainer;
      case UserRole.member:
        return AppColors.roleMember;
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.superAdmin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.gymOwner:
        return Icons.store_rounded;
      case UserRole.trainer:
        return Icons.fitness_center_rounded;
      case UserRole.member:
        return Icons.person_rounded;
    }
  }
}

/// User entity representation in GCRM One.
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final UserRole role;
  final String? tenantId; // Gym Tenant identifier
  final String? gymName;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;
  final List<String> permissions;
  final String? fcmToken;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.role,
    this.tenantId,
    this.gymName,
    this.avatarUrl,
    this.isActive = true,
    required this.createdAt,
    this.permissions = const [],
    this.fcmToken,
  });

  bool get isSuperAdmin =>
      role == UserRole.superAdmin &&
      (tenantId == null || tenantId!.trim().isEmpty);

  bool get isGymOwner =>
      role == UserRole.gymOwner ||
      (tenantId != null &&
          tenantId!.trim().isNotEmpty &&
          role != UserRole.trainer &&
          role != UserRole.member);

  bool get isTrainer => role == UserRole.trainer;
  bool get isMember => role == UserRole.member;

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    UserRole? role,
    String? tenantId,
    String? gymName,
    String? avatarUrl,
    bool? isActive,
    DateTime? createdAt,
    List<String>? permissions,
    String? fcmToken,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      tenantId: tenantId ?? this.tenantId,
      gymName: gymName ?? this.gymName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      permissions: permissions ?? this.permissions,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'tenantId': tenantId,
      'gymName': gymName,
      'avatarUrl': avatarUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'permissions': permissions,
      'fcmToken': fcmToken,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      role: () {
        final r = json['role']?.toString().toLowerCase().trim();
        final rawTenantId = json['tenantId']?.toString().trim();
        final hasTenant = rawTenantId != null && rawTenantId.isNotEmpty;
        final isSuper = json['isSuperAdmin'] == true;

        if (hasTenant) {
          if (r == 'trainer' || r == 'staff' || r == 'coach') {
            return UserRole.trainer;
          }
          if (r == 'member' || r == 'gym_member') {
            return UserRole.member;
          }
          return UserRole.gymOwner;
        }

        if (r == 'superadmin' || r == 'super_admin' || isSuper) {
          return UserRole.superAdmin;
        }
        if (r == 'gymowner' ||
            r == 'gym_admin' ||
            r == 'gymadmin' ||
            r == 'owner' ||
            r == 'admin') {
          return UserRole.gymOwner;
        }
        if (r == 'trainer') {
          return UserRole.trainer;
        }
        return UserRole.values.firstWhere(
          (role) => role.name.toLowerCase() == r,
          orElse: () => UserRole.member,
        );
      }(),
      tenantId: json['tenantId'] as String?,
      gymName: json['gymName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: () {
        final raw = json['createdAt'];
        if (raw is String) {
          return DateTime.tryParse(raw) ?? DateTime.now();
        } else if (raw is DateTime) {
          return raw;
        } else if (raw != null) {
          try {
            // Support cloud_firestore Timestamp
            return (raw as dynamic).toDate() as DateTime;
          } catch (_) {
            return DateTime.now();
          }
        }
        return DateTime.now();
      }(),
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      fcmToken: json['fcmToken'] as String?,
    );
  }
}
