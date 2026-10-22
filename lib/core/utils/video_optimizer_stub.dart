import 'dart:typed_data';

/// Result of preparing a gallery video for upload.
class VideoOptimizationResult {
  final Uint8List bytes;
  final int optimizedSizeBytes;
  final int? durationSeconds;
  final Uint8List? thumbnailBytes;
  final int? width;
  final int? height;

  const VideoOptimizationResult({
    required this.bytes,
    required this.optimizedSizeBytes,
    this.durationSeconds,
    this.thumbnailBytes,
    this.width,
    this.height,
  });
}

/// Web fallback. Video compression and cover thumbnails are not available.
class VideoOptimizer {
  static bool get thumbnailsEnabled => false;

  /// True when [url] points at an image that can be drawn as a video cover.
  static bool isImageCover(String? url) {
    if (url == null) return false;
    final value = url.trim().toLowerCase();
    if (value.isEmpty) return false;
    if (value.startsWith('data:video') || value.contains('.mp4') || value.contains('.mov') || value.contains('.webm')) {
      return false;
    }
    return value.startsWith('data:image') ||
        value.startsWith('http://') ||
        value.startsWith('https://');
  }

  /// Cover image URL for a video. Always empty off Android.
  static String? androidCoverUrl(String? thumbnailUrl) => null;

  static Future<VideoOptimizationResult> prepareUpload({
    required String? sourcePath,
    required Uint8List originalBytes,
    void Function(String stage)? onStage,
  }) async {
    onStage?.call('optimizing');
    return VideoOptimizationResult(
      bytes: originalBytes,
      optimizedSizeBytes: originalBytes.lengthInBytes,
    );
  }
}
