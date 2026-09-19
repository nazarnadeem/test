import 'package:intl/intl.dart';

/// Check-in log model for live gym check-in stream, scanner activity, and attendance history.
class GymCheckInLog {
  final String id;
  final String? tenantId;
  final String memberId;
  final String memberName;
  final String planName;
  final DateTime timestamp;
  final String method; // 'QR Scan', 'Manual Pass', 'NFC Tag', 'Face ID'
  final String? notes;

  const GymCheckInLog({
    this.id = '',
    this.tenantId,
    this.memberId = '',
    required this.memberName,
    required this.planName,
    required this.timestamp,
    this.method = 'QR Scan',
    this.notes,
  });

  String get formattedTime => DateFormat('hh:mm a').format(timestamp);
  String get formattedDate => DateFormat('dd MMM yyyy').format(timestamp);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'memberId': memberId,
      'memberName': memberName,
      'planName': planName,
      'timestamp': timestamp.toIso8601String(),
      'method': method,
      'notes': notes,
    };
  }

  factory GymCheckInLog.fromJson(Map<String, dynamic> json, [String? docId]) {
    DateTime parsedTimestamp = DateTime.now();
    if (json['timestamp'] != null) {
      if (json['timestamp'] is String) {
        parsedTimestamp = DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now();
      } else {
        try {
          parsedTimestamp = (json['timestamp'] as dynamic).toDate();
        } catch (_) {
          parsedTimestamp = DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now();
        }
      }
    }

    return GymCheckInLog(
      id: docId ?? (json['id'] as String? ?? ''),
      tenantId: json['tenantId'] as String?,
      memberId: json['memberId'] as String? ?? '',
      memberName: json['memberName'] as String? ?? 'Member',
      planName: json['planName'] as String? ?? 'General Plan',
      timestamp: parsedTimestamp,
      method: json['method'] as String? ?? 'QR Scan',
      notes: json['notes'] as String?,
    );
  }

  GymCheckInLog copyWith({
    String? id,
    String? tenantId,
    String? memberId,
    String? memberName,
    String? planName,
    DateTime? timestamp,
    String? method,
    String? notes,
  }) {
    return GymCheckInLog(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      planName: planName ?? this.planName,
      timestamp: timestamp ?? this.timestamp,
      method: method ?? this.method,
      notes: notes ?? this.notes,
    );
  }
}
