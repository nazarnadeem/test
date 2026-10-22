import 'package:equatable/equatable.dart';

/// Data model representing a push notification broadcast sent by Super Admin.
class PushNotificationRecord extends Equatable {
  final String id;
  final String title;
  final String body;
  final String targetAudience; // 'all', 'gym_owners', 'specific_gym'
  final String? targetTenantId;
  final String? targetGymName;
  final String sound;
  final String status; // 'pending', 'processing', 'completed', 'failed'
  final int recipientsCount;
  final int successCount;
  final int failureCount;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? sentByName;

  const PushNotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.targetAudience,
    this.targetTenantId,
    this.targetGymName,
    this.sound = 'notification.mp3',
    this.status = 'completed',
    this.recipientsCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    required this.createdAt,
    this.completedAt,
    this.sentByName,
  });

  String get audienceDisplayLabel {
    switch (targetAudience) {
      case 'gym_owners':
        return 'Gym Owners & Admins';
      case 'specific_gym':
        return targetGymName != null ? 'Gym: $targetGymName' : 'Single Gym Facility';
      case 'all':
      default:
        return 'All Platform Users';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'targetAudience': targetAudience,
      'targetTenantId': targetTenantId,
      'targetGymName': targetGymName,
      'sound': sound,
      'status': status,
      'recipientsCount': recipientsCount,
      'successCount': successCount,
      'failureCount': failureCount,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'sentByName': sentByName,
    };
  }

  factory PushNotificationRecord.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value.runtimeType.toString().contains('Timestamp')) {
        return (value as dynamic).toDate();
      }
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    return PushNotificationRecord(
      id: docId ?? map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      targetAudience: map['targetAudience']?.toString() ?? 'all',
      targetTenantId: map['targetTenantId']?.toString(),
      targetGymName: map['targetGymName']?.toString(),
      sound: map['sound']?.toString() ?? 'notification.mp3',
      status: map['status']?.toString() ?? 'pending',
      recipientsCount: (map['recipientsCount'] as num?)?.toInt() ?? 0,
      successCount: (map['successCount'] as num?)?.toInt() ?? 0,
      failureCount: (map['failureCount'] as num?)?.toInt() ?? 0,
      createdAt: parseDateTime(map['createdAt']),
      completedAt: map['completedAt'] != null ? parseDateTime(map['completedAt']) : null,
      sentByName: map['sentByName']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        targetAudience,
        targetTenantId,
        targetGymName,
        sound,
        status,
        recipientsCount,
        successCount,
        failureCount,
        createdAt,
        completedAt,
        sentByName,
      ];
}

/// One page of Super Admin sent broadcasts. Each page is at most 10 queue documents.
class SentNotificationPage {
  static const pageSize = 10;

  final List<PushNotificationRecord> records;
  final bool hasMore;

  const SentNotificationPage({
    required this.records,
    required this.hasMore,
  });
}
