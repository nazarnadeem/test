import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/utils/image_optimizer.dart';
import 'package:gcrm_one/core/widgets/gradient_linear_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GradientLinearLoader Widget Tests', () {
    testWidgets('Renders indeterminate gradient linear loader smoothly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 120,
              child: GradientLinearLoader(
                primaryColor: Color(0xFF8B5CF6),
                forceAnimate: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GradientLinearLoader), findsOneWidget);
      expect(find.byType(ClipRRect), findsWidgets);

      // Verify animation frames pump without error
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('Renders determinate gradient linear loader with progress factor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: GradientLinearLoader(
                progress: 0.65,
                primaryColor: Color(0xFFFF5500),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GradientLinearLoader), findsOneWidget);
      final fractionallySizedBox = tester.widget<FractionallySizedBox>(
        find.descendant(
          of: find.byType(GradientLinearLoader),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(fractionallySizedBox.widthFactor, closeTo(0.65, 0.01));
    });

    testWidgets('Adapts to compact avatar dimensions gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 36,
              height: 36,
              child: GradientLinearLoader(
                primaryColor: Colors.cyan,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(GradientLinearLoader), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });
  });

  group('ImageOptimizer.buildImageWidget Cached Network & Linear Loader Tests', () {
    testWidgets('Returns placeholder immediately when source is null or empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageOptimizer.buildImageWidget(
              null,
              placeholder: const Text('EMPTY_PLACEHOLDER'),
            ),
          ),
        ),
      );

      expect(find.text('EMPTY_PLACEHOLDER'), findsOneWidget);
    });

    testWidgets('Decodes base64 data URI and renders Image.memory directly', (tester) async {
      final sampleBytes = ImageOptimizer.createSampleAvatarBytes(size: 32);
      final dataUri = ImageOptimizer.toDataUri(sampleBytes);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageOptimizer.buildImageWidget(
              dataUri,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('Uses CachedNetworkImage with GradientLinearLoader progress indicator for network URLs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 150,
              child: ImageOptimizer.buildImageWidget(
                'https://firebasestorage.googleapis.com/v0/b/gcrm-one.appspot.com/o/demo.jpg',
                primaryColor: const Color(0xFF8B5CF6),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      );

      // Verify that while downloading, the GradientLinearLoader is displayed
      expect(find.byType(GradientLinearLoader), findsOneWidget);
    });

    test('buildImageProvider returns null for empty or provider for valid source', () {
      expect(ImageOptimizer.buildImageProvider(null), isNull);
      expect(ImageOptimizer.buildImageProvider(''), isNull);

      final sampleBytes = ImageOptimizer.createSampleAvatarBytes(size: 16);
      final dataUri = ImageOptimizer.toDataUri(sampleBytes);
      final memProvider = ImageOptimizer.buildImageProvider(dataUri);
      expect(memProvider, isA<MemoryImage>());

      final networkProvider = ImageOptimizer.buildImageProvider('https://example.com/image.jpg');
      expect(networkProvider, isNotNull);
    });
  });
}
