import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/constants/app_assets.dart';
import 'package:gcrm_one/core/widgets/gcrm_logo_widget.dart';

void main() {
  group('GcrmLogoWidget Asset Tests', () {
    testWidgets('GcrmLogoWidget renders logo asset in full mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GcrmLogoWidget(
              size: 120,
              showText: true,
              showTagline: true,
              animateGlow: true,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, equals(AppAssets.logo));
      expect(assetImage.assetName, equals('assets/images/logo.png'));
    });

    testWidgets('GcrmLogoWidget renders logo asset in compact icon mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GcrmLogoWidget(
              size: 32,
              showText: false,
              showTagline: false,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, equals(AppAssets.logo));
    });
  });
}
