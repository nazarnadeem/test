import 'package:flutter/material.dart';

/// Gym Batch Model for gym facilities / tenants.
/// Used by Gym Admins to define scheduled training/workout batches,
/// batch operational hours/time, max member limit/capacity,
/// and assigned gym members.
class GymBatchModel {
  final String id;
  final String? tenantId;
  final String name; // Batch Name e.g. "Morning Fitness Elite", "Evening HIIT"
  final String time; // Batch Time e.g. "06:00 AM - 07:30 AM"
  final int limit; // Max Member Limit / Capacity e.g. 20
  final List<String> memberIds; // Enrolled Gym Member IDs
  final List<String> memberNames; // Cached / display member names
  final bool isActive;
  final Color accentColor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const GymBatchModel({
    required this.id,
    this.tenantId,
    required this.name,
    required this.time,
    this.limit = 20,
    this.memberIds = const [],
    this.memberNames = const [],
    this.isActive = true,
    this.accentColor = const Color(0xFF00E676),
    this.createdAt,
    this.updatedAt,
  });

  /// Total enrolled members count
  int get enrolledCount => memberIds.length;

  /// Check if batch capacity has reached max limit
  bool get isFull => limit > 0 && enrolledCount >= limit;

  /// Remaining available slots in batch
  int get availableSlots => (limit - enrolledCount).clamp(0, limit);

  /// Capacity ratio helper (0.0 to 1.0)
  double get occupancyRatio {
    if (limit <= 0) return 0.0;
    return (enrolledCount / limit).clamp(0.0, 1.0);
  }

  /// Label formatted e.g. "12 / 20 Members"
  String get capacityLabel => '$enrolledCount / $limit Members';

  /// Returns a copy of the batch with modified properties
  GymBatchModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? time,
    int? limit,
    List<String>? memberIds,
    List<String>? memberNames,
    bool? isActive,
    Color? accentColor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GymBatchModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      time: time ?? this.time,
      limit: limit ?? this.limit,
      memberIds: memberIds ?? List.from(this.memberIds),
      memberNames: memberNames ?? List.from(this.memberNames),
      isActive: isActive ?? this.isActive,
      accentColor: accentColor ?? this.accentColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serialization to JSON / Firestore map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'name': name,
      'time': time,
      'limit': limit,
      'memberIds': memberIds,
      'memberNames': memberNames,
      'isActive': isActive,
      'accentColor': accentColor.value,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Deserialization from JSON / Firestore document
  factory GymBatchModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val);
      if (val is DateTime) return val;
      try {
        return (val as dynamic).toDate() as DateTime?;
      } catch (_) {
        return null;
      }
    }

    Color parseColor(dynamic val) {
      if (val is int) return Color(val);
      if (val is String) {
        final hex = val.replaceAll('#', '');
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
          return Color(int.parse(hex, radix: 16));
        }
      }
      return const Color(0xFF00E676);
    }

    return GymBatchModel(
      id: docId ?? json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String?,
      name: json['name'] as String? ?? 'Default Batch',
      time: json['time'] as String? ?? '06:00 AM - 07:00 AM',
      limit: json['limit'] is int ? json['limit'] as int : int.tryParse(json['limit']?.toString() ?? '20') ?? 20,
      memberIds: json['memberIds'] != null
          ? List<String>.from(json['memberIds'] as List)
          : <String>[],
      memberNames: json['memberNames'] != null
          ? List<String>.from(json['memberNames'] as List)
          : <String>[],
      isActive: json['isActive'] as bool? ?? true,
      accentColor: parseColor(json['accentColor']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
