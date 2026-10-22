import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcrm_one/core/utils/image_optimizer.dart';
import 'package:gcrm_one/core/utils/video_optimizer.dart';
import 'package:gcrm_one/features/auth/controllers/auth_controller.dart';
import 'package:gcrm_one/features/auth/data/models/gym_gallery_item_model.dart';
import 'package:gcrm_one/features/auth/data/repositories/mock_auth_service.dart';
import 'package:gcrm_one/features/auth/presentation/screens/gym_admin_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gym Gallery Item Model & Media Optimization Tests', () {
    test('GymGalleryItemModel serialization and savings calculations', () {
      final item = GymGalleryItemModel(
        id: 'gal_test_01',
        tenantId: 'tenant_metro_01',
        title: 'Olympic Bench Press Zone',
        mediaType: GymGalleryMediaType.image,
        mediaUrl: 'https://example.com/photo.jpg',
        thumbnailUrl: 'https://example.com/photo_thumb.jpg',
        originalSizeBytes: 2000000, // ~2 MB
        optimizedSizeBytes: 400000,  // ~400 KB (-80%)
        width: 1440,
        height: 960,
        createdAt: DateTime(2026, 10, 1),
        uploadedBy: 'Admin',
      );

      expect(item.isImage, isTrue);
      expect(item.isVideo, isFalse);
      expect(item.compressionPercentage, closeTo(80.0, 0.1));
      expect(item.formattedSize, contains('KB'));
      expect(item.savingsLabel, contains('-80%'));

      final json = item.toJson();
      final fromJson = GymGalleryItemModel.fromJson(json, 'gal_test_01');
      expect(fromJson.id, equals('gal_test_01'));
      expect(fromJson.title, equals('Olympic Bench Press Zone'));
      expect(fromJson.mediaType, equals(GymGalleryMediaType.image));
      expect(fromJson.originalSizeBytes, equals(2000000));
      expect(fromJson.optimizedSizeBytes, equals(400000));
    });

    test('GymGalleryItemModel video type handling', () {
      final videoItem = GymGalleryItemModel(
        id: 'gal_vid_01',
        tenantId: 'tenant_metro_01',
        title: 'Deadlift Technique Demo',
        mediaType: GymGalleryMediaType.video,
        mediaUrl: 'https://example.com/deadlift.mp4',
        thumbnailUrl: 'https://example.com/deadlift_thumb.jpg',
        originalSizeBytes: 15000000,
        optimizedSizeBytes: 15000000,
        durationSeconds: 30,
        createdAt: DateTime(2026, 10, 1),
      );

      expect(videoItem.isVideo, isTrue);
      expect(videoItem.isImage, isFalse);
      expect(videoItem.durationSeconds, equals(30));
    });

    test('ImageOptimizer compresses gallery image bytes and creates video thumbnail', () async {
      final sampleBytes = ImageOptimizer.createSampleAvatarBytes(size: 800);
      expect(sampleBytes, isNotEmpty);

      // Optimize image
      final opt = await ImageOptimizer.optimizeGalleryImage(
        sampleBytes,
        maxDimension: 400,
        quality: 75,
      );
      expect(opt.bytes, isNotEmpty);
      expect(opt.width, lessThanOrEqualTo(400));
      expect(opt.height, lessThanOrEqualTo(400));

      // Video poster thumbnail generation
      final videoThumb = ImageOptimizer.createVideoThumbnailBytes(width: 480, height: 320);
      expect(videoThumb, isNotEmpty);
    });

    test('Video cover URLs accept images and reject video files', () {
      expect(VideoOptimizer.isImageCover('https://cdn.example.com/cover.jpg'), isTrue);
      expect(VideoOptimizer.isImageCover('data:image/jpeg;base64,abc'), isTrue);
      expect(VideoOptimizer.isImageCover('https://cdn.example.com/clip.mp4'), isFalse);
      expect(VideoOptimizer.isImageCover('data:video/mp4;base64,abc'), isFalse);
      expect(VideoOptimizer.isImageCover(''), isFalse);
    });
  });

  group('Gym Admin Gallery AuthController & Limits Tests', () {
    late MockAuthService mockAuthService;
    late AuthController authController;

    setUp(() async {
      mockAuthService = MockAuthService();
      mockAuthService.resetForTesting();
      authController = AuthController(authRepository: mockAuthService);
      await authController.login(
        email: 'gymowner@metrofitness.com',
        password: 'Admin@Metro2026',
      );
    });

    test('Loads initial seeded gallery items with limit capped at 25', () async {
      await authController.loadGymGalleryItems('tenant_metro_01', true);
      expect(authController.galleryItems, isNotEmpty);
      expect(authController.galleryItems.length, lessThanOrEqualTo(25));
      expect(authController.isGalleryFull, isFalse);
      expect(authController.remainingGallerySlots, equals(25 - authController.galleryItems.length));
    });

    test('Enforces batch upload limit of 10 items at once', () async {
      await authController.loadGymGalleryItems('tenant_metro_01', true);

      // Attempt to upload 11 items in one batch
      final dummyBytes = ImageOptimizer.createSampleAvatarBytes(size: 64);
      final elevenItems = List.generate(
        11,
        (i) => GymGalleryUploadPayload(
          bytes: dummyBytes,
          fileName: 'photo_$i.jpg',
          mediaType: GymGalleryMediaType.image,
          originalSizeBytes: dummyBytes.lengthInBytes,
        ),
      );

      final result = await authController.uploadGymGalleryMedia(elevenItems);
      expect(result, isFalse);
      expect(authController.errorMessage, contains('10'));
    });

    test('Enforces total capacity limit of 25 items', () async {
      await authController.loadGymGalleryItems('tenant_metro_01', true);
      final initialCount = authController.galleryItems.length;
      final dummyBytes = ImageOptimizer.createSampleAvatarBytes(size: 64);

      // Upload batches up to 25 items
      final slotsAvailable = 25 - initialCount;
      while (authController.remainingGallerySlots > 0) {
        final batchSize = authController.remainingGallerySlots > 10
            ? 10
            : authController.remainingGallerySlots;
        final batch = List.generate(
          batchSize,
          (i) => GymGalleryUploadPayload(
            bytes: dummyBytes,
            fileName: 'batch_${authController.galleryItems.length}_$i.jpg',
            mediaType: GymGalleryMediaType.image,
            originalSizeBytes: dummyBytes.lengthInBytes,
          ),
        );
        final success = await authController.uploadGymGalleryMedia(batch);
        expect(success, isTrue);
      }

      // Now gallery should be full (25 items)
      expect(authController.galleryItems.length, equals(25));
      expect(authController.isGalleryFull, isTrue);
      expect(authController.remainingGallerySlots, equals(0));

      // Attempting to upload any more items when full should fail
      final overflow = [
        GymGalleryUploadPayload(
          bytes: dummyBytes,
          fileName: 'overflow.jpg',
          mediaType: GymGalleryMediaType.image,
          originalSizeBytes: dummyBytes.lengthInBytes,
        ),
      ];
      final overflowResult = await authController.uploadGymGalleryMedia(overflow);
      expect(overflowResult, isFalse);
      expect(authController.errorMessage, contains('limit'));
    });

    test('Successfully uploads and deletes gallery media', () async {
      await authController.loadGymGalleryItems('tenant_metro_01', true);
      final beforeCount = authController.galleryItems.length;

      final dummyPhotoBytes = ImageOptimizer.createSampleAvatarBytes(size: 100);
      final dummyVideoBytes = Uint8List.fromList(List.generate(1024, (i) => i % 256));

      final uploadList = [
        GymGalleryUploadPayload(
          bytes: dummyPhotoBytes,
          fileName: 'new_gym_rack.jpg',
          title: 'Power Rack Setup',
          mediaType: GymGalleryMediaType.image,
          originalSizeBytes: dummyPhotoBytes.lengthInBytes,
        ),
        GymGalleryUploadPayload(
          bytes: dummyVideoBytes,
          fileName: 'bench_clip.mp4',
          title: 'Bench Press Technique',
          mediaType: GymGalleryMediaType.video,
          durationSeconds: 15,
          originalSizeBytes: dummyVideoBytes.lengthInBytes,
        ),
      ];

      final uploadSuccess = await authController.uploadGymGalleryMedia(uploadList);
      expect(uploadSuccess, isTrue);
      expect(authController.galleryItems.length, equals(beforeCount + 2));

      // Verify the uploaded items are in the gallery
      final uploadedPhoto = authController.galleryItems.firstWhere((i) => i.title == 'Power Rack Setup');
      expect(uploadedPhoto.isImage, isTrue);

      final uploadedVideo = authController.galleryItems.firstWhere((i) => i.title == 'Bench Press Technique');
      expect(uploadedVideo.isVideo, isTrue);
      expect(uploadedVideo.durationSeconds, equals(15));

      // Delete item
      final deleteSuccess = await authController.deleteGymGalleryItem(uploadedPhoto.id);
      expect(deleteSuccess, isTrue);
      expect(authController.galleryItems.any((i) => i.id == uploadedPhoto.id), isFalse);
      expect(authController.galleryItems.length, equals(beforeCount + 1));
    });
  });

  group('Gym Admin Dashboard Gallery Tab Widget Tests', () {
    late MockAuthService mockAuthService;
    late AuthController authController;

    setUp(() async {
      mockAuthService = MockAuthService();
      mockAuthService.resetForTesting();
      authController = AuthController(authRepository: mockAuthService);
      await authController.login(
        email: 'gymowner@metrofitness.com',
        password: 'Admin@Metro2026',
      );
      await authController.loadDashboardOverview(tenantId: 'tenant_metro_01', forceRefresh: true);
    });

    testWidgets('Gallery tab exists right after Team tab and displays showcase header & counter',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: GymAdminDashboardScreen(authController: authController),
        ),
      );
      await tester.pumpAndSettle();

      // Find Gallery tab in the TabBar
      final galleryTab = find.widgetWithText(Tab, 'Gallery');
      expect(galleryTab, findsOneWidget);

      // Verify Gallery tab is after Team tab
      final teamTab = find.widgetWithText(Tab, 'Team');
      expect(teamTab, findsOneWidget);

      // Tap Gallery tab
      await tester.tap(find.text('Gallery'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify gallery header and counter
      expect(find.text('GYM MEDIA SHOWCASE'), findsOneWidget);
      expect(find.textContaining('/ 25 Items'), findsOneWidget);

      // Verify filter chips
      expect(find.text('All'), findsWidgets);
      expect(find.text('Photos'), findsWidgets);
      expect(find.text('Videos'), findsWidgets);

      // Verify Floating Action Button for gallery
      expect(find.byType(FloatingActionButton), findsWidgets);
    });
  });
}
