import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Supported media types in the Gym Gallery
enum GymGalleryMediaType {
  image,
  video;

  String get displayName {
    switch (this) {
      case GymGalleryMediaType.image:
        return 'Photo';
      case GymGalleryMediaType.video:
        return 'Video';
    }
  }

  static GymGalleryMediaType fromString(String? val) {
    if (val != null && val.toLowerCase().trim() == 'video') {
      return GymGalleryMediaType.video;
    }
    return GymGalleryMediaType.image;
  }
}

/// Gallery media item model for Gym Facility showcases
class GymGalleryItemModel {
  final String id;
  final String tenantId;
  final String title;
  final GymGalleryMediaType mediaType;
  final String mediaUrl;
  final String thumbnailUrl;
  final int originalSizeBytes;
  final int optimizedSizeBytes;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final DateTime createdAt;
  final String uploadedBy;

  const GymGalleryItemModel({
    required this.id,
    required this.tenantId,
    this.title = '',
    required this.mediaType,
    required this.mediaUrl,
    required this.thumbnailUrl,
    this.originalSizeBytes = 0,
    this.optimizedSizeBytes = 0,
    this.width,
    this.height,
    this.durationSeconds,
    required this.createdAt,
    this.uploadedBy = 'Admin',
  });

  bool get isVideo => mediaType == GymGalleryMediaType.video;
  bool get isImage => mediaType == GymGalleryMediaType.image;

  /// Percentage size reduction achieved by optimization
  double get compressionPercentage {
    if (originalSizeBytes <= 0 || optimizedSizeBytes <= 0) return 0.0;
    if (originalSizeBytes <= optimizedSizeBytes) return 0.0;
    final diff = originalSizeBytes - optimizedSizeBytes;
    return (diff / originalSizeBytes * 100).clamp(0.0, 100.0);
  }

  /// Formatted size string (e.g. "1.2 MB" or "450 KB")
  String get formattedSize {
    final size = optimizedSizeBytes > 0 ? optimizedSizeBytes : originalSizeBytes;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Savings summary string
  String get savingsLabel {
    if (compressionPercentage <= 0) return formattedSize;
    final orig = _formatBytes(originalSizeBytes);
    final opt = _formatBytes(optimizedSizeBytes);
    return '$orig ➔ $opt (-${compressionPercentage.toStringAsFixed(0)}%)';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  GymGalleryItemModel copyWith({
    String? id,
    String? tenantId,
    String? title,
    GymGalleryMediaType? mediaType,
    String? mediaUrl,
    String? thumbnailUrl,
    int? originalSizeBytes,
    int? optimizedSizeBytes,
    int? width,
    int? height,
    int? durationSeconds,
    DateTime? createdAt,
    String? uploadedBy,
  }) {
    return GymGalleryItemModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      originalSizeBytes: originalSizeBytes ?? this.originalSizeBytes,
      optimizedSizeBytes: optimizedSizeBytes ?? this.optimizedSizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'title': title,
      'mediaType': mediaType.name,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'originalSizeBytes': originalSizeBytes,
      'optimizedSizeBytes': optimizedSizeBytes,
      'width': width,
      'height': height,
      'durationSeconds': durationSeconds,
      'createdAt': Timestamp.fromDate(createdAt),
      'uploadedBy': uploadedBy,
    };
  }

  factory GymGalleryItemModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return GymGalleryItemModel(
      id: docId ?? json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      mediaType: GymGalleryMediaType.fromString(json['mediaType']?.toString()),
      mediaUrl: json['mediaUrl']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? json['mediaUrl']?.toString() ?? '',
      originalSizeBytes: (json['originalSizeBytes'] as num?)?.toInt() ?? 0,
      optimizedSizeBytes: (json['optimizedSizeBytes'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      createdAt: parseDate(json['createdAt']),
      uploadedBy: json['uploadedBy']?.toString() ?? 'Admin',
    );
  }
}

/// Payload prepared for uploading an optimized gallery media item
class GymGalleryUploadPayload {
  final Uint8List bytes;
  final String fileName;
  final GymGalleryMediaType mediaType;
  final String title;
  final int originalSizeBytes;
  final int? durationSeconds;
  final Uint8List? customThumbnailBytes;
  final int? width;
  final int? height;

  const GymGalleryUploadPayload({
    required this.bytes,
    required this.fileName,
    required this.mediaType,
    this.title = '',
    required this.originalSizeBytes,
    this.durationSeconds,
    this.customThumbnailBytes,
    this.width,
    this.height,
  });
}
