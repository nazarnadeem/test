import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/utils/image_optimizer.dart';
import 'package:image/image.dart' as img;

void main() {
  group('ImageOptimizer Tests', () {
    test('ImageOptimizer compresses and resizes oversized image', () async {
      // Create a test 1000x800 raw image in memory
      final testImage = img.Image(width: 1000, height: 800);
      // Fill with sample color pixels
      for (var y = 0; y < 800; y++) {
        for (var x = 0; x < 1000; x++) {
          testImage.setPixelRgba(x, y, (x % 255), (y % 255), 200, 255);
        }
      }

      final rawBytes = Uint8List.fromList(img.encodePng(testImage));
      expect(rawBytes.length, greaterThan(0));

      // Optimize to max 512x512
      final result = await ImageOptimizer.optimizeImage(
        rawBytes,
        maxDimension: 512,
        quality: 80,
      );

      expect(result.width, equals(512));
      expect(result.height, equals((800 * 512 / 1000).round()));
      expect(result.optimizedSizeBytes, greaterThan(0));
      expect(result.format, equals('jpg'));
      expect(result.summaryString, isNotEmpty);
      expect(result.originalSizeKb, greaterThan(0));
      expect(result.optimizedSizeKb, greaterThan(0));
    });

    test('ImageOptimizer handles already small image gracefully', () async {
      final smallImage = img.Image(width: 100, height: 100);
      final rawBytes = Uint8List.fromList(img.encodeJpg(smallImage, quality: 90));

      final result = await ImageOptimizer.optimizeImage(
        rawBytes,
        maxDimension: 512,
        quality: 85,
      );

      expect(result.width, equals(100));
      expect(result.height, equals(100));
      expect(result.optimizedSizeBytes, greaterThan(0));
    });
  });
}
