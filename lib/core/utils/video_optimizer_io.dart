import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

import 'image_optimizer.dart';

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

/// Compresses gallery videos, then builds a JPEG cover on Android only.
class VideoOptimizer {
  static bool get thumbnailsEnabled => Platform.isAndroid;

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

  /// Cover image URL for a video tile. Only Android receives a thumbnail.
  static String? androidCoverUrl(String? thumbnailUrl) {
    if (!thumbnailsEnabled || !isImageCover(thumbnailUrl)) return null;
    return thumbnailUrl;
  }

  /// Compresses [sourcePath], then extracts an Android cover frame from the result.
  static Future<VideoOptimizationResult> prepareUpload({
    required String? sourcePath,
    required Uint8List originalBytes,
    void Function(String stage)? onStage,
  }) async {
    var bytes = originalBytes;
    int? durationSeconds;
    int? width;
    int? height;
    Uint8List? thumbnailBytes;
    var thumbnailSource = sourcePath;

    final canCompress = sourcePath != null &&
        sourcePath.trim().isNotEmpty &&
        (Platform.isAndroid || Platform.isIOS);

    if (canCompress) {
      onStage?.call('optimizing');
      try {
        final info = await VideoCompress.compressVideo(
          sourcePath,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );
        final compressedFile = info?.file;
        if (info != null && info.isCancel != true && compressedFile != null && await compressedFile.exists()) {
          final compressed = await compressedFile.readAsBytes();
          if (compressed.isNotEmpty && compressed.lengthInBytes <= originalBytes.lengthInBytes) {
            bytes = compressed;
            thumbnailSource = info.path ?? compressedFile.path;
          }
          if (info.duration != null && info.duration! > 0) {
            durationSeconds = (info.duration! / 1000).round();
          }
          width = info.width;
          height = info.height;
        }
      } catch (e) {
        debugPrint('Video optimization failed, uploading the original file: $e');
      }

      if (thumbnailsEnabled && thumbnailSource != null && thumbnailSource.trim().isNotEmpty) {
        onStage?.call('thumbnail');
        try {
          final rawThumb = await VideoCompress.getByteThumbnail(
            thumbnailSource,
            quality: 75,
            position: 500,
          );
          if (rawThumb != null && rawThumb.isNotEmpty) {
            final optimizedThumb = await ImageOptimizer.optimizeImage(
              rawThumb,
              maxDimension: 640,
              quality: 75,
            );
            thumbnailBytes = optimizedThumb.bytes;
            width ??= optimizedThumb.width;
            height ??= optimizedThumb.height;
          }
        } catch (e) {
          debugPrint('Android video cover thumbnail failed: $e');
        }
      }

      try {
        await VideoCompress.deleteAllCache();
      } catch (_) {}
    } else {
      onStage?.call('optimizing');
    }

    return VideoOptimizationResult(
      bytes: bytes,
      optimizedSizeBytes: bytes.lengthInBytes,
      durationSeconds: durationSeconds,
      thumbnailBytes: thumbnailBytes,
      width: width,
      height: height,
    );
  }
}
