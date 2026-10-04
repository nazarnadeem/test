import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../widgets/gradient_linear_loader.dart';

/// Optimization Result holding the compressed image bytes, metadata, and savings statistics
class ImageOptimizationResult {
  final Uint8List bytes;
  final int width;
  final int height;
  final int originalSizeBytes;
  final int optimizedSizeBytes;
  final String format;

  const ImageOptimizationResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.originalSizeBytes,
    required this.optimizedSizeBytes,
    required this.format,
  });

  /// Alias for backward compatibility
  Uint8List get optimizedBytes => bytes;

  /// Original size in KB
  double get originalSizeKb => originalSizeBytes / 1024.0;

  /// Optimized size in KB
  double get optimizedSizeKb => optimizedSizeBytes / 1024.0;

  /// Percentage reduction achieved
  double get compressionPercentage {
    if (originalSizeBytes == 0) return 0.0;
    final diff = originalSizeBytes - optimizedSizeBytes;
    return (diff / originalSizeBytes * 100).clamp(0.0, 100.0);
  }

  /// Percentage reduction alias
  double get reductionPercentage => compressionPercentage;

  /// Human readable summary of size savings (e.g. "Original: 1.8MB ➔ Optimized: 42KB (-98%)")
  String get summaryString {
    final orig = _formatBytes(originalSizeBytes);
    final opt = _formatBytes(optimizedSizeBytes);
    final pct = compressionPercentage.toStringAsFixed(0);
    return '$orig ➔ $opt (-$pct%)';
  }

  /// Savings label alias
  String get savingsLabel => summaryString;

  /// Base64 data URI string for direct Image.network / storage / memory usage
  String get base64DataUri => 'data:image/jpeg;base64,${base64Encode(bytes)}';

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Backward compatibility alias
typedef OptimizedImageResult = ImageOptimizationResult;

/// High-efficiency client-side image optimization and compression utility
class ImageOptimizer {
  /// Converts raw bytes to base64 Data URI string
  static String toDataUri(Uint8List bytes, {String mime = 'image/jpeg'}) =>
      'data:$mime;base64,${base64Encode(bytes)}';

  /// Compresses and resizes raw image bytes before upload or storage
  static Future<ImageOptimizationResult> optimizeImage(
    Uint8List rawBytes, {
    int maxDimension = 512,
    int quality = 80,
    String format = 'jpg',
  }) async {
    final originalSize = rawBytes.lengthInBytes;

    // Decode image from raw memory bytes
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      // Return original if decoding fails
      return ImageOptimizationResult(
        bytes: rawBytes,
        width: 0,
        height: 0,
        originalSizeBytes: originalSize,
        optimizedSizeBytes: originalSize,
        format: format,
      );
    }

    // Downscale while maintaining exact aspect ratio if larger than maxDimension
    img.Image processed = decoded;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      if (decoded.width >= decoded.height) {
        processed = img.copyResize(
          decoded,
          width: maxDimension,
          interpolation: img.Interpolation.linear,
        );
      } else {
        processed = img.copyResize(
          decoded,
          height: maxDimension,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // Encode to optimized JPEG format
    final Uint8List optimizedBytes = Uint8List.fromList(
      img.encodeJpg(processed, quality: quality),
    );

    return ImageOptimizationResult(
      bytes: optimizedBytes,
      width: processed.width,
      height: processed.height,
      originalSizeBytes: originalSize,
      optimizedSizeBytes: optimizedBytes.lengthInBytes,
      format: format,
    );
  }

  /// Alias for optimizeImage
  static Future<ImageOptimizationResult?> optimizeImageBytes(
    Uint8List rawBytes, {
    int maxWidth = 512,
    int maxHeight = 512,
    int quality = 80,
  }) async {
    final maxDim = maxWidth > maxHeight ? maxWidth : maxHeight;
    return await optimizeImage(
      rawBytes,
      maxDimension: maxDim,
      quality: quality,
    );
  }

  /// Generate sample image bytes for simulation and testing
  static Uint8List createSampleAvatarBytes({int size = 128, int colorValue = 0xFFFF5722}) {
    final image = img.Image(width: size, height: size);
    img.fill(image, color: img.ColorRgba8(255, 87, 34, 255));
    return Uint8List.fromList(img.encodeJpg(image, quality: 85));
  }

  /// Generate sample video thumbnail bytes for simulation and testing
  static Uint8List createVideoThumbnailBytes({int width = 480, int height = 320}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgba8(24, 30, 42, 255));
    return Uint8List.fromList(img.encodeJpg(image, quality: 80));
  }


  /// Optimizes a gallery image: downscales to maxDimension and compresses to JPEG
  static Future<ImageOptimizationResult> optimizeGalleryImage(
    Uint8List rawBytes, {
    int maxDimension = 1440,
    int quality = 82,
  }) async {
    return optimizeImage(
      rawBytes,
      maxDimension: maxDimension,
      quality: quality,
      format: 'jpg',
    );
  }

  /// Safely renders an image widget whether the source is a http(s) URL, a base64 data URI, or null.
  /// Automatically caches network images via [CachedNetworkImage] and displays a sleek
  /// linear loader with a primary-color gradient while the image is loading.
  static Widget buildImageWidget(
    String? source, {
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? loadingWidget,
    Color? primaryColor,
    double? width,
    double? height,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    if (source == null || source.isEmpty) {
      return placeholder ?? const SizedBox.shrink();
    }
    if (source.startsWith('data:image')) {
      try {
        final commaIdx = source.indexOf(',');
        final base64Payload = commaIdx != -1 ? source.substring(commaIdx + 1) : source;
        final decodedBytes = base64Decode(base64Payload);
        return Image.memory(
          decodedBytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder ?? (_, __, ___) => placeholder ?? const SizedBox.shrink(),
        );
      } catch (_) {
        return placeholder ?? const SizedBox.shrink();
      }
    }

    return CachedNetworkImage(
      imageUrl: source,
      width: width,
      height: height,
      fit: fit,
      progressIndicatorBuilder: (context, url, downloadProgress) {
        if (loadingWidget != null) return loadingWidget;
        return GradientLinearLoader(
          progress: downloadProgress.progress,
          primaryColor: primaryColor,
        );
      },
      errorWidget: (context, url, error) {
        if (errorBuilder != null) {
          return errorBuilder(context, error, null);
        }
        return placeholder ?? const SizedBox.shrink();
      },
    );
  }

  /// Returns a cached network image provider or fallback memory provider
  static ImageProvider? buildImageProvider(String? source) {
    if (source == null || source.isEmpty) return null;
    if (source.startsWith('data:image')) {
      try {
        final commaIdx = source.indexOf(',');
        final base64Payload = commaIdx != -1 ? source.substring(commaIdx + 1) : source;
        return MemoryImage(base64Decode(base64Payload));
      } catch (_) {
        return null;
      }
    }
    return CachedNetworkImageProvider(source);
  }
}


