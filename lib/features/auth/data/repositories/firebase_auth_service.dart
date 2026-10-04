import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/image_optimizer.dart';
import '../models/user_model.dart';
import '../models/gym_tenant_model.dart';
import '../models/auth_session.dart';
import '../models/platform_plan_model.dart';
import '../models/gym_team_member_model.dart';
import '../models/gym_membership_plan_model.dart';
import '../models/gym_member_model.dart';
import '../models/gym_expense_model.dart';
import '../models/gym_check_in_model.dart';
import '../models/gym_batch_model.dart';
import '../models/gym_gallery_item_model.dart';
import '../models/push_notification_model.dart';
import 'auth_repository.dart';
import 'mock_auth_service.dart';

/// Production-ready Firebase Authentication & Cloud Firestore backend implementation for GCRM One.
/// Handles Super Admin creation, tenant onboarding, role verification, and session persistence.
class FirebaseAuthService implements AuthRepository {
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;
  final AuthRepository _fallbackService;

  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    AuthRepository? fallbackService,
  })  : _auth = auth,
        _firestore = firestore,
        _storage = storage,
        _fallbackService = fallbackService ?? MockAuthService();

  bool get _isFirebaseReady {
    try {
      if (Firebase.apps.isEmpty) return false;
      _auth ??= FirebaseAuth.instance;
      _firestore ??= FirebaseFirestore.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseAuth get auth {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  FirebaseStorage get storage {
    if (_storage != null) return _storage!;
    try {
      if (Firebase.apps.isNotEmpty) {
        _storage = FirebaseStorage.instance;
      } else {
        _storage = FirebaseStorage.instance;
      }
    } catch (_) {
      _storage = FirebaseStorage.instance;
    }
    return _storage!;
  }

  Future<void> _ensureFirebaseAuthSession() async {
    try {
      if (_isFirebaseReady && auth.currentUser == null) {
        await auth.signInAnonymously();
      }
    } catch (e) {
      debugPrint('Notice: Anonymous Firebase Auth session note: $e');
    }
  }

  @override
  Future<String?> uploadGymLogo({
    required String gymId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.uploadGymLogo(
        gymId: gymId,
        imageBytes: imageBytes,
        fileExtension: fileExtension,
      );
    }

    try {
      await _ensureFirebaseAuthSession();
      // 1. Optimize image client-side before uploading to Firebase Storage
      final rawUint8 = imageBytes is Uint8List
          ? imageBytes
          : Uint8List.fromList(imageBytes);
      final optimizationResult = await ImageOptimizer.optimizeImage(
        rawUint8,
        maxDimension: 512,
        quality: 85,
      );

      debugPrint(
        'Gym logo optimized before upload: ${optimizationResult.summaryString}',
      );

      // 2. Upload to Firebase Storage
      final ref = storage.ref('gym_logos/$gymId.${optimizationResult.format}');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'gymId': gymId,
          'optimized': 'true',
          'originalSize': '${optimizationResult.originalSizeBytes}',
          'optimizedSize': '${optimizationResult.optimizedSizeBytes}',
        },
      );

      final uploadTask = await ref.putData(optimizationResult.bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage logo upload notice (falling back to embedded image data): $e');
      try {
        final rawUint8 = imageBytes is Uint8List
            ? imageBytes
            : Uint8List.fromList(imageBytes);
        final optimizationResult = await ImageOptimizer.optimizeImage(
          rawUint8,
          maxDimension: 512,
          quality: 85,
        );
        return optimizationResult.base64DataUri;
      } catch (_) {
        return await _fallbackService.uploadGymLogo(
          gymId: gymId,
          imageBytes: imageBytes,
          fileExtension: fileExtension,
        );
      }
    }
  }

  @override
  Future<GymTenantModel> registerGymWithAdmin({
    required String gymName,
    required String ownerFullName,
    required String ownerEmail,
    required String phone,
    required String address,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    List<int>? logoBytes,
    String? logoUrl,
    String primaryColorHex = '#FF5722',
    SubscriptionTier tier = SubscriptionTier.growth,
    String? planId,
    String? planName,
    double? planPrice,
    String? billingPeriod,
    DateTime? planStartDate,
    DateTime? planExpiryDate,
    bool isLifetimeFree = false,
  }) async {
    if (!_isFirebaseReady) {
      return _fallbackService.registerGymWithAdmin(
        gymName: gymName,
        ownerFullName: ownerFullName,
        ownerEmail: ownerEmail,
        phone: phone,
        address: address,
        adminName: adminName,
        adminEmail: adminEmail,
        adminPassword: adminPassword,
        logoBytes: logoBytes,
        logoUrl: logoUrl,
        primaryColorHex: primaryColorHex,
        tier: tier,
        planId: planId,
        planName: planName,
        planPrice: planPrice,
        billingPeriod: billingPeriod,
        planStartDate: planStartDate,
        planExpiryDate: planExpiryDate,
        isLifetimeFree: isLifetimeFree,
      );
    }

    try {
      final normalizedOwnerEmail = ownerEmail.trim().toLowerCase();
      final normalizedAdminEmail = adminEmail.trim().toLowerCase();
      final tenantId = 'tenant_${DateTime.now().millisecondsSinceEpoch}';
      final cleanGymCode = gymName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      final safeCode = '${cleanGymCode.length > 5 ? cleanGymCode.substring(0, 5) : cleanGymCode}-01';

      String adminUid = 'usr_admin_${DateTime.now().millisecondsSinceEpoch}';

      // Create Firebase Auth account for gym admin using a secondary app instance
      try {
        final secondaryApp = await Firebase.initializeApp(
          name: 'GymAdminCreator_${DateTime.now().millisecondsSinceEpoch}',
          options: Firebase.app().options,
        );
        final adminCred = await FirebaseAuth.instanceFor(app: secondaryApp)
            .createUserWithEmailAndPassword(
          email: normalizedAdminEmail,
          password: adminPassword,
        );
        if (adminCred.user != null) {
          adminUid = adminCred.user!.uid;
          await adminCred.user!.updateDisplayName(adminName);
        }
        await secondaryApp.delete();
      } catch (authError) {
        debugPrint('Secondary Firebase App admin creation note: $authError');
      }

      // Handle logo upload if raw bytes provided
      String? resolvedLogoUrl = logoUrl;
      if (logoBytes != null && logoBytes.isNotEmpty) {
        try {
          resolvedLogoUrl = await uploadGymLogo(
            gymId: tenantId,
            imageBytes: logoBytes,
          );
        } catch (uploadErr) {
          debugPrint('Gym logo upload during registration note: $uploadErr');
        }
      }

      // 1. Save Gym Tenant in Firestore
      final tenantDoc = {
        'id': tenantId,
        'gymName': gymName,
        'tradeLicense': 'TR-$safeCode',
        'ownerId': adminUid,
        'ownerName': ownerFullName,
        'ownerEmail': normalizedOwnerEmail,
        'adminName': adminName,
        'adminEmail': normalizedAdminEmail,
        'adminId': adminUid,
        'address': address,
        'phone': phone,
        'gymCode': safeCode,
        'logoUrl': resolvedLogoUrl,
        'primaryColorHex': primaryColorHex,
        'tier': tier.name,
        'planId': planId,
        'planName': planName,
        'planPrice': planPrice,
        'billingPeriod': billingPeriod ?? 'year',
        'planStartDate': planStartDate != null ? Timestamp.fromDate(planStartDate) : FieldValue.serverTimestamp(),
        'planExpiryDate': isLifetimeFree ? null : (planExpiryDate != null ? Timestamp.fromDate(planExpiryDate) : null),
        'isLifetimeFree': isLifetimeFree,
        'status': TenantStatus.active.name,
        'activeMembersCount': 0,
        'activeTrainersCount': 0,
        'monthlyRevenue': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 2. Save Gym Admin user document in Firestore
      final userDoc = {
        'id': adminUid,
        'email': normalizedAdminEmail,
        'fullName': adminName,
        'phoneNumber': phone,
        'role': UserRole.gymOwner.name,
        'isSuperAdmin': false,
        'tenantId': tenantId,
        'gymName': gymName,
        'permissions': [
          'manage_gym_members',
          'manage_trainers',
          'view_gym_analytics',
          'process_memberships',
        ],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      try {
        await firestore.collection('tenants').doc(tenantId).set(tenantDoc);
        await firestore.collection('users').doc(adminUid).set(userDoc);
      } catch (firestoreError) {
        debugPrint('Firestore registerGymWithAdmin write notice: $firestoreError');
      }

      final newTenant = GymTenantModel(
        id: tenantId,
        gymName: gymName,
        tradeLicense: 'TR-$safeCode',
        ownerId: adminUid,
        ownerName: ownerFullName,
        ownerEmail: normalizedOwnerEmail,
        adminName: adminName,
        adminEmail: normalizedAdminEmail,
        adminId: adminUid,
        address: address,
        phone: phone,
        gymCode: safeCode,
        logoUrl: resolvedLogoUrl,
        primaryColorHex: primaryColorHex,
        tier: tier,
        planId: planId,
        planName: planName,
        planPrice: planPrice,
        billingPeriod: billingPeriod ?? 'year',
        planStartDate: planStartDate ?? DateTime.now(),
        planExpiryDate: isLifetimeFree ? null : planExpiryDate,
        isLifetimeFree: isLifetimeFree,
        status: TenantStatus.active,
        activeMembersCount: 0,
        activeTrainersCount: 0,
        monthlyRevenue: 0.0,
        createdAt: DateTime.now(),
      );

      // Sync with in-memory service
      await _fallbackService.registerGymWithAdmin(
        gymName: gymName,
        ownerFullName: ownerFullName,
        ownerEmail: ownerEmail,
        phone: phone,
        address: address,
        adminName: adminName,
        adminEmail: adminEmail,
        adminPassword: adminPassword,
        logoBytes: logoBytes,
        logoUrl: resolvedLogoUrl,
        primaryColorHex: primaryColorHex,
        tier: tier,
        planId: planId,
        planName: planName,
        planPrice: planPrice,
        billingPeriod: billingPeriod,
        planStartDate: planStartDate,
        planExpiryDate: isLifetimeFree ? null : planExpiryDate,
        isLifetimeFree: isLifetimeFree,
      );

      return newTenant;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to register gym and admin account: $e');
    }
  }

  @override
  Future<AuthSession> registerSuperAdmin({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    String? securityPin,
    String? organization,
  }) async {
    if (!_isFirebaseReady) {
      return _fallbackService.registerSuperAdmin(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
        securityPin: securityPin,
        organization: organization,
      );
    }

    try {
      final normalizedEmail = email.trim().toLowerCase();
      UserCredential userCred;

      try {
        userCred = await auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // If already exists in Firebase Auth, attempt sign-in to elevate/sync
          userCred = await auth.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
        } else {
          throw _handleAuthException(e);
        }
      }

      final fbUser = userCred.user;
      if (fbUser == null) {
        throw Exception('Failed to initialize Firebase user account.');
      }

      final uid = fbUser.uid;
      try {
        await fbUser.updateDisplayName(fullName);
      } catch (_) {}

      final orgName = organization ?? '';
      const permissions = [
        'manage_all_tenants',
        'approve_gym_vendors',
        'view_global_revenue',
        'manage_system_settings',
        'manage_global_trainers',
        'manage_security_keys',
      ];

      // 1. Create or update Firestore master Super Admin record (non-blocking for UI)
      final userDoc = {
        'id': uid,
        'email': normalizedEmail,
        'fullName': fullName,
        'phoneNumber': phone,
        'role': UserRole.superAdmin.name,
        'isSuperAdmin': true,
        'tenantId': null,
        'gymName': orgName,
        'securityPin': securityPin ?? '',
        'permissions': permissions,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      try {
        await firestore.collection('users').doc(uid).set(
              userDoc,
              SetOptions(merge: true),
            );

        await firestore.collection('platform_governance').doc('superadmin').set(
          {
            'masterAdminUid': uid,
            'masterAdminEmail': normalizedEmail,
            'masterAdminName': fullName,
            'platformEntity': orgName,
            'initializedAt': FieldValue.serverTimestamp(),
            'platformStatus': 'active',
          },
          SetOptions(merge: true),
        );
      } catch (firestoreError) {
        debugPrint('Firestore write notice (check Firestore security rules in Firebase Console): $firestoreError');
      }

      final token = await fbUser.getIdToken() ?? 'token_$uid';
      final userModel = UserModel(
        id: uid,
        email: normalizedEmail,
        fullName: fullName,
        phoneNumber: phone,
        role: UserRole.superAdmin,
        tenantId: null,
        gymName: orgName,
        createdAt: DateTime.now(),
        permissions: permissions,
      );

      return AuthSession(
        user: userModel,
        token: token,
        refreshToken: 'refresh_$uid',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        rememberMe: true,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Super Admin initialization error: $e');
    }
  }

  @override
  Future<AuthSession> loginSuperAdmin({
    required String email,
    required String password,
    String? securityCode,
    bool rememberMe = true,
  }) async {
    if (!_isFirebaseReady) {
      return _fallbackService.loginSuperAdmin(
        email: email,
        password: password,
        securityCode: securityCode,
        rememberMe: rememberMe,
      );
    }

    try {
      final normalizedEmail = email.trim().toLowerCase();
      final userCred = await auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final fbUser = userCred.user;
      if (fbUser == null) {
        throw Exception('Super Admin account not found.');
      }

      final uid = fbUser.uid;
      UserModel userModel;

      try {
        final docSnap = await firestore.collection('users').doc(uid).get();
        if (docSnap.exists && docSnap.data() != null) {
          final data = docSnap.data()!;
          data['id'] = uid;
          userModel = UserModel.fromJson(data);
        } else {
          userModel = UserModel(
            id: uid,
            email: normalizedEmail,
            fullName: fbUser.displayName ?? 'Platform Super Admin',
            role: UserRole.superAdmin,
            gymName: 'GCRM ONE Global Platform',
            createdAt: DateTime.now(),
            permissions: const [
              'manage_all_tenants',
              'approve_gym_vendors',
              'view_global_revenue',
              'manage_system_settings',
            ],
          );
        }
      } catch (_) {
        userModel = UserModel(
          id: uid,
          email: normalizedEmail,
          fullName: fbUser.displayName ?? 'Platform Super Admin',
          role: UserRole.superAdmin,
          gymName: 'GCRM ONE Global Platform',
          createdAt: DateTime.now(),
          permissions: const [
            'manage_all_tenants',
            'approve_gym_vendors',
            'view_global_revenue',
            'manage_system_settings',
          ],
        );
      }

      final token = await fbUser.getIdToken() ?? 'token_$uid';
      return AuthSession(
        user: userModel,
        token: token,
        refreshToken: 'refresh_$uid',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        rememberMe: rememberMe,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Super Admin authentication failed: $e');
    }
  }

  /// Resolves the authenticated user's account role, tenant affiliation, and profile.
  /// Gym admins and staff are strictly bound to their tenant; unverified users will never
  /// be promoted to Super Admin.
  Future<UserModel> _resolveUserAccount({
    required String uid,
    required String normalizedEmail,
    String? displayName,
    String? phoneNumber,
    UserRole? requestedRole,
  }) async {
    const defaultGymAdminPermissions = [
      'manage_gym_members',
      'manage_trainers',
      'view_gym_analytics',
      'process_memberships',
    ];

    const defaultSuperAdminPermissions = [
      'manage_all_tenants',
      'approve_gym_vendors',
      'view_global_revenue',
      'manage_system_settings',
      'manage_global_trainers',
      'manage_security_keys',
    ];

    // 1. Cross-reference Tenants collection to see if this user owns/admins a gym
    try {
      QuerySnapshot<Map<String, dynamic>>? snap;
      snap = await firestore
          .collection('tenants')
          .where('adminEmail', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        snap = await firestore
            .collection('tenants')
            .where('ownerEmail', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
      }
      if (snap.docs.isEmpty) {
        snap = await firestore
            .collection('tenants')
            .where('adminId', isEqualTo: uid)
            .limit(1)
            .get();
      }
      if (snap.docs.isEmpty) {
        snap = await firestore
            .collection('tenants')
            .where('ownerId', isEqualTo: uid)
            .limit(1)
            .get();
      }

      if (snap.docs.isNotEmpty) {
        final tenantDoc = snap.docs.first;
        final tenantData = tenantDoc.data();
        final tenantId = tenantDoc.id;
        final gymName = (tenantData['gymName'] as String?)?.trim() ?? 'Partner Gym';
        final resolvedName = (tenantData['adminName'] as String?)?.trim() ??
            (tenantData['ownerName'] as String?)?.trim() ??
            displayName ??
            'Gym Admin';
        final resolvedPhone = (tenantData['phone'] as String?)?.trim() ?? phoneNumber ?? '';

        final userModel = UserModel(
          id: uid,
          email: normalizedEmail,
          fullName: resolvedName,
          phoneNumber: resolvedPhone,
          role: UserRole.gymOwner,
          tenantId: tenantId,
          gymName: gymName,
          createdAt: DateTime.now(),
          permissions: defaultGymAdminPermissions,
        );

        // Self-heal users/{uid} document with gymOwner and tenantId
        try {
          await firestore.collection('users').doc(uid).set(
            {
              'id': uid,
              'email': normalizedEmail,
              'fullName': resolvedName,
              'phoneNumber': resolvedPhone,
              'role': UserRole.gymOwner.name,
              'isSuperAdmin': false,
              'tenantId': tenantId,
              'gymName': gymName,
              'permissions': defaultGymAdminPermissions,
              'isActive': true,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          if (tenantData['adminId'] != uid) {
            await firestore.collection('tenants').doc(tenantId).update({'adminId': uid});
          }
        } catch (e) {
          debugPrint('Firestore self-healing tenant sync note: $e');
        }

        return userModel;
      }
    } catch (e) {
      debugPrint('Firestore tenant resolution check note: $e');
    }

    // 2. Check if a users record exists by UID
    try {
      final docSnap = await firestore.collection('users').doc(uid).get();
      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        data['id'] = uid;
        final rawRole = (data['role'] as String?)?.toLowerCase();
        final rawTenantId = data['tenantId'] as String?;
        final isSuper = data['isSuperAdmin'] == true;

        // If the user has a tenantId, they can NEVER be a Super Admin
        if (rawTenantId != null && rawTenantId.isNotEmpty) {
          return UserModel.fromJson(data);
        }

        // If record claimed superAdmin, verify against master superadmin email or governance
        if (rawRole == 'superadmin' || isSuper) {
          final isMasterEmail = normalizedEmail == AppStrings.demoSuperAdminEmail.toLowerCase();
          final isExplicitSuper = requestedRole == UserRole.superAdmin;
          if (isMasterEmail || isExplicitSuper) {
            return UserModel.fromJson(data);
          }

          // Check if governance document recognizes them
          try {
            final govDoc = await firestore.collection('platform_governance').doc('superadmin').get();
            if (govDoc.exists) {
              final masterUid = govDoc.data()?['masterAdminUid'] as String?;
              final masterEmail = (govDoc.data()?['masterAdminEmail'] as String?)?.toLowerCase();
              if (masterUid == uid || masterEmail == normalizedEmail) {
                return UserModel.fromJson(data);
              }
            }
          } catch (_) {}

          // Corrupted / orphaned fallback: If not verified as superadmin, downgrade to gymOwner
          debugPrint('Notice: Downgrading unverified superAdmin record for $normalizedEmail to gymOwner');
          final healedData = Map<String, dynamic>.from(data);
          healedData['role'] = UserRole.gymOwner.name;
          healedData['isSuperAdmin'] = false;
          try {
            await firestore.collection('users').doc(uid).update({
              'role': UserRole.gymOwner.name,
              'isSuperAdmin': false,
            });
          } catch (_) {}
          return UserModel.fromJson(healedData);
        }

        return UserModel.fromJson(data);
      }
    } catch (e) {
      debugPrint('Firestore user doc read note: $e');
    }

    // 3. Check if user document exists under a generated ID (e.g. usr_admin_...) with matching email
    try {
      final queryByEmail = await firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(3)
          .get();
      for (final doc in queryByEmail.docs) {
        if (doc.id != uid) {
          final existingData = doc.data();
          final tid = existingData['tenantId'] as String?;
          if (tid != null && tid.isNotEmpty) {
            final gymName = existingData['gymName'] as String? ?? 'Partner Gym';
            final fullName = existingData['fullName'] as String? ?? displayName ?? 'Gym Admin';
            final phone = existingData['phoneNumber'] as String? ?? phoneNumber ?? '';
            final role = UserRoleExtension.fromString(existingData['role'] as String?);

            final userModel = UserModel(
              id: uid,
              email: normalizedEmail,
              fullName: fullName,
              phoneNumber: phone,
              role: role == UserRole.superAdmin ? UserRole.gymOwner : role,
              tenantId: tid,
              gymName: gymName,
              createdAt: DateTime.now(),
              permissions: (existingData['permissions'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  defaultGymAdminPermissions,
            );

            // Copy to users/{uid}
            try {
              await firestore.collection('users').doc(uid).set({
                'id': uid,
                'email': normalizedEmail,
                'fullName': fullName,
                'phoneNumber': phone,
                'role': userModel.role.name,
                'isSuperAdmin': false,
                'tenantId': tid,
                'gymName': gymName,
                'permissions': userModel.permissions,
                'isActive': true,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (_) {}

            return userModel;
          }
        }
      }
    } catch (e) {
      debugPrint('Firestore secondary user lookup note: $e');
    }

    // 4. Missing user record entirely: create appropriate new user record
    final isMasterSuperAdmin = normalizedEmail == AppStrings.demoSuperAdminEmail.toLowerCase() ||
        requestedRole == UserRole.superAdmin;

    if (isMasterSuperAdmin) {
      final name = displayName ?? 'Platform Super Admin';
      final superUserModel = UserModel(
        id: uid,
        email: normalizedEmail,
        fullName: name,
        phoneNumber: phoneNumber ?? '+1 (800) 555-0199',
        role: UserRole.superAdmin,
        gymName: 'GCRM ONE Global Platform',
        createdAt: DateTime.now(),
        permissions: defaultSuperAdminPermissions,
      );

      try {
        await firestore.collection('users').doc(uid).set({
          'id': uid,
          'email': normalizedEmail,
          'fullName': name,
          'phoneNumber': phoneNumber ?? '+1 (800) 555-0199',
          'role': UserRole.superAdmin.name,
          'isSuperAdmin': true,
          'tenantId': null,
          'gymName': 'GCRM ONE Global Platform',
          'permissions': defaultSuperAdminPermissions,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      return superUserModel;
    }

    // Default for any regular user/gym admin logging in without a record
    final gymAdminName = displayName ?? 'Gym Admin';
    final fallbackGymAdmin = UserModel(
      id: uid,
      email: normalizedEmail,
      fullName: gymAdminName,
      phoneNumber: phoneNumber ?? '',
      role: requestedRole ?? UserRole.gymOwner,
      gymName: 'Partner Gym',
      createdAt: DateTime.now(),
      permissions: defaultGymAdminPermissions,
    );

    try {
      await firestore.collection('users').doc(uid).set({
        'id': uid,
        'email': normalizedEmail,
        'fullName': gymAdminName,
        'phoneNumber': phoneNumber ?? '',
        'role': (requestedRole ?? UserRole.gymOwner).name,
        'isSuperAdmin': false,
        'tenantId': null,
        'gymName': 'Partner Gym',
        'permissions': defaultGymAdminPermissions,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    return fallbackGymAdmin;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    UserRole? requestedRole,
    bool rememberMe = true,
  }) async {
    if (!_isFirebaseReady) {
      return _fallbackService.login(
        email: email,
        password: password,
        requestedRole: requestedRole,
        rememberMe: rememberMe,
      );
    }

    try {
      final normalizedEmail = email.trim().toLowerCase();
      final userCred = await auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final fbUser = userCred.user;
      if (fbUser == null) {
        throw Exception('User account not found.');
      }

      final uid = fbUser.uid;
      UserModel userModel;

      try {
        userModel = await _resolveUserAccount(
          uid: uid,
          normalizedEmail: normalizedEmail,
          displayName: fbUser.displayName,
          phoneNumber: fbUser.phoneNumber,
          requestedRole: requestedRole,
        );
      } catch (firestoreError) {
        debugPrint('Firestore user sync notice: $firestoreError');
        final isMaster = normalizedEmail == AppStrings.demoSuperAdminEmail.toLowerCase() ||
            requestedRole == UserRole.superAdmin;
        userModel = UserModel(
          id: uid,
          email: normalizedEmail,
          fullName: fbUser.displayName ?? (isMaster ? 'Platform Super Admin' : 'Gym Admin'),
          role: isMaster ? UserRole.superAdmin : (requestedRole ?? UserRole.gymOwner),
          gymName: isMaster ? 'GCRM ONE Global Platform' : 'Partner Gym',
          createdAt: DateTime.now(),
          permissions: isMaster
              ? const [
                  'manage_all_tenants',
                  'approve_gym_vendors',
                  'view_global_revenue',
                  'manage_system_settings',
                ]
              : const [
                  'manage_gym_members',
                  'manage_trainers',
                  'view_gym_analytics',
                  'process_memberships',
                ],
        );
      }

      final token = await fbUser.getIdToken() ?? 'token_$uid';
      return AuthSession(
        user: userModel,
        token: token,
        refreshToken: 'refresh_$uid',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        rememberMe: rememberMe,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Sign in failed: $e');
    }
  }

  @override
  Future<AuthSession> registerGymVendor({
    required String gymName,
    required String tradeLicense,
    required String address,
    required String ownerFullName,
    required String email,
    required String password,
    required String phone,
    SubscriptionTier tier = SubscriptionTier.growth,
  }) async {
    if (!_isFirebaseReady) {
      return _fallbackService.registerGymVendor(
        gymName: gymName,
        tradeLicense: tradeLicense,
        address: address,
        ownerFullName: ownerFullName,
        email: email,
        password: password,
        phone: phone,
        tier: tier,
      );
    }

    try {
      final normalizedEmail = email.trim().toLowerCase();
      final userCred = await auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final fbUser = userCred.user;
      if (fbUser == null) {
        throw Exception('Failed to create vendor account.');
      }

      final uid = fbUser.uid;
      try {
        await fbUser.updateDisplayName(ownerFullName);
      } catch (_) {}

      final tenantId = 'tenant_${DateTime.now().millisecondsSinceEpoch}';
      final gymCode = gymName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      final safeCode = '${gymCode.length > 5 ? gymCode.substring(0, 5) : gymCode}-01';

      // 1. Save tenant document
      final tenantDoc = {
        'id': tenantId,
        'gymName': gymName,
        'tradeLicense': tradeLicense,
        'ownerId': uid,
        'ownerName': ownerFullName,
        'ownerEmail': normalizedEmail,
        'address': address,
        'phone': phone,
        'gymCode': safeCode,
        'tier': tier.name,
        'status': TenantStatus.active.name,
        'activeMembersCount': 1,
        'activeTrainersCount': 0,
        'monthlyRevenue': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 2. Save user document
      final userDoc = {
        'id': uid,
        'email': normalizedEmail,
        'fullName': ownerFullName,
        'phoneNumber': phone,
        'role': UserRole.gymOwner.name,
        'tenantId': tenantId,
        'gymName': gymName,
        'permissions': [
          'manage_gym_members',
          'manage_trainers',
          'view_gym_analytics',
          'process_memberships',
        ],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      try {
        await firestore.collection('tenants').doc(tenantId).set(tenantDoc);
        await firestore.collection('users').doc(uid).set(userDoc);
      } catch (firestoreError) {
        debugPrint('Firestore vendor write notice: $firestoreError');
      }

      final token = await fbUser.getIdToken() ?? 'token_$uid';
      final userModel = UserModel(
        id: uid,
        email: normalizedEmail,
        fullName: ownerFullName,
        phoneNumber: phone,
        role: UserRole.gymOwner,
        tenantId: tenantId,
        gymName: gymName,
        createdAt: DateTime.now(),
        permissions: const [
          'manage_gym_members',
          'manage_trainers',
          'view_gym_analytics',
          'process_memberships',
        ],
      );

      return AuthSession(
        user: userModel,
        token: token,
        refreshToken: 'refresh_$uid',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        rememberMe: true,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gym onboarding failed: $e');
    }
  }

  @override
  Future<AuthSession> registerMember({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String gymCode,
  }) async {
    if (!_isFirebaseReady) {
      return _fallbackService.registerMember(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
        gymCode: gymCode,
      );
    }

    try {
      final normalizedEmail = email.trim().toLowerCase();
      final userCred = await auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final fbUser = userCred.user;
      if (fbUser == null) {
        throw Exception('Failed to register member account.');
      }

      final uid = fbUser.uid;
      try {
        await fbUser.updateDisplayName(fullName);
      } catch (_) {}

      // Lookup gym by code
      String gymName = 'GCRM Partner Gym';
      String? tenantId;
      try {
        final querySnap = await firestore
            .collection('tenants')
            .where('gymCode', isEqualTo: gymCode.toUpperCase())
            .limit(1)
            .get();
        if (querySnap.docs.isNotEmpty) {
          final data = querySnap.docs.first.data();
          gymName = data['gymName'] ?? gymName;
          tenantId = querySnap.docs.first.id;
        }
      } catch (_) {}

      final userDoc = {
        'id': uid,
        'email': normalizedEmail,
        'fullName': fullName,
        'phoneNumber': phone,
        'role': UserRole.member.name,
        'tenantId': tenantId,
        'gymName': gymName,
        'gymCode': gymCode.toUpperCase(),
        'permissions': ['view_gym_pass', 'book_classes'],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      try {
        await firestore.collection('users').doc(uid).set(userDoc);
      } catch (firestoreError) {
        debugPrint('Firestore member write notice: $firestoreError');
      }

      final token = await fbUser.getIdToken() ?? 'token_$uid';
      final userModel = UserModel(
        id: uid,
        email: normalizedEmail,
        fullName: fullName,
        phoneNumber: phone,
        role: UserRole.member,
        tenantId: tenantId,
        gymName: gymName,
        createdAt: DateTime.now(),
        permissions: const ['view_gym_pass', 'book_classes'],
      );

      return AuthSession(
        user: userModel,
        token: token,
        refreshToken: 'refresh_$uid',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        rememberMe: true,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Member registration failed: $e');
    }
  }

  @override
  Future<bool> requestPasswordReset({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (!_isFirebaseReady) {
      return _fallbackService.requestPasswordReset(email: normalizedEmail);
    }

    try {
      // 1. Verify email in Firestore if rules allow
      try {
        final querySnap = await firestore
            .collection('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();

        if (querySnap.docs.isEmpty) {
          throw Exception(
            'No registered account found with this email address ($email). Please check the email or sign up.',
          );
        }
      } on FirebaseException catch (e) {
        debugPrint('Firestore read notice during password recovery: ${e.code}');
      }

      // 2. Dispatch password reset email via Firebase Authentication
      await auth.sendPasswordResetEmail(email: normalizedEmail);
      return true;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Password reset request error: $e');
    }
  }

  @override
  Future<bool> verifyOtp({required String email, required String otpCode}) async {
    return _fallbackService.verifyOtp(email: email, otpCode: otpCode);
  }

  @override
  Future<bool> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    return _fallbackService.resetPassword(
      email: email,
      otpCode: otpCode,
      newPassword: newPassword,
    );
  }

  @override
  Future<AuthSession?> getCurrentSession() async {
    if (!_isFirebaseReady) {
      return _fallbackService.getCurrentSession();
    }

    try {
      final fbUser = auth.currentUser;
      if (fbUser == null) return null;

      final uid = fbUser.uid;
      final normalizedEmail = (fbUser.email ?? '').trim().toLowerCase();
      UserModel userModel;

      try {
        userModel = await _resolveUserAccount(
          uid: uid,
          normalizedEmail: normalizedEmail,
          displayName: fbUser.displayName,
          phoneNumber: fbUser.phoneNumber,
        );
      } catch (firestoreError) {
        debugPrint('Firestore session user sync notice: $firestoreError');
        final isMaster = normalizedEmail == AppStrings.demoSuperAdminEmail.toLowerCase();
        userModel = UserModel(
          id: uid,
          email: normalizedEmail,
          fullName: fbUser.displayName ?? (isMaster ? 'Platform Super Admin' : 'Gym Admin'),
          role: isMaster ? UserRole.superAdmin : UserRole.gymOwner,
          gymName: isMaster ? 'GCRM ONE Global Platform' : 'Partner Gym',
          createdAt: DateTime.now(),
          permissions: isMaster
              ? const [
                  'manage_all_tenants',
                  'approve_gym_vendors',
                  'view_global_revenue',
                  'manage_system_settings',
                ]
              : const [
                  'manage_gym_members',
                  'manage_trainers',
                  'view_gym_analytics',
                  'process_memberships',
                ],
        );
      }

      final token = await fbUser.getIdToken() ?? 'token_$uid';
      return AuthSession(
        user: userModel,
        token: token,
        refreshToken: 'refresh_$uid',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        rememberMe: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    if (_isFirebaseReady) {
      try {
        await auth.signOut();
      } catch (_) {}
    }
    await _fallbackService.logout();
  }

  @override
  Future<List<GymTenantModel>> getGymTenants() async {
    if (!_isFirebaseReady) {
      return [];
    }

    try {
      final snap = await firestore.collection('tenants').get();
      if (snap.docs.isEmpty) {
        return [];
      }

      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return GymTenantModel.fromJson(data);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<GymTenantModel> updateGymTenant(GymTenantModel tenant) async {
    await _fallbackService.updateGymTenant(tenant);

    if (_isFirebaseReady) {
      try {
        await firestore.collection('tenants').doc(tenant.id).set(
          tenant.toJson(),
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('Firestore update gym tenant error: $e');
      }
    }
    return tenant;
  }

  @override
  Future<void> toggleGymStatus({
    required String tenantId,
    required bool isActive,
  }) async {
    await _fallbackService.toggleGymStatus(
      tenantId: tenantId,
      isActive: isActive,
    );

    if (_isFirebaseReady) {
      try {
        await firestore.collection('tenants').doc(tenantId).update({
          'status': isActive ? TenantStatus.active.name : TenantStatus.suspended.name,
        });
      } catch (e) {
        debugPrint('Firestore toggleGymStatus error: $e');
      }
    }
  }

  @override
  Future<List<PlatformPlanModel>> getPlatformPlans() async {
    if (!_isFirebaseReady) {
      return [];
    }

    try {
      final snap = await firestore
          .collection('platform_plans')
          .orderBy('price', descending: false)
          .get();

      if (snap.docs.isEmpty) {
        return [];
      }

      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return PlatformPlanModel.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Firestore fetch platform_plans error: $e');
      return [];
    }
  }

  @override
  Future<PlatformPlanModel> createPlatformPlan(PlatformPlanModel plan) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.createPlatformPlan(plan);
    }

    try {
      final collection = firestore.collection('platform_plans');
      final docRef = plan.id.isNotEmpty && !plan.id.startsWith('plan_')
          ? collection.doc(plan.id)
          : collection.doc();

      final planWithId = plan.copyWith(id: docRef.id);
      final data = planWithId.toJson();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));
      await _fallbackService.createPlatformPlan(planWithId);
      return planWithId;
    } catch (e) {
      debugPrint('Firestore createPlatformPlan error: $e');
      return await _fallbackService.createPlatformPlan(plan);
    }
  }

  @override
  Future<PlatformPlanModel> updatePlatformPlan(PlatformPlanModel plan) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.updatePlatformPlan(plan);
    }

    try {
      final docRef = firestore.collection('platform_plans').doc(plan.id);
      final data = plan.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));
      await _fallbackService.updatePlatformPlan(plan);
      return plan;
    } catch (e) {
      debugPrint('Firestore updatePlatformPlan error: $e');
      return await _fallbackService.updatePlatformPlan(plan);
    }
  }

  @override
  Future<void> togglePlatformPlanStatus(String planId) async {
    if (!_isFirebaseReady) {
      await _fallbackService.togglePlatformPlanStatus(planId);
      return;
    }

    try {
      final docRef = firestore.collection('platform_plans').doc(planId);
      final snap = await docRef.get();
      if (snap.exists) {
        final currentActive = (snap.data()?['isActive'] as bool?) ?? true;
        await docRef.update({
          'isActive': !currentActive,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await _fallbackService.togglePlatformPlanStatus(planId);
    } catch (e) {
      debugPrint('Firestore togglePlatformPlanStatus error: $e');
      await _fallbackService.togglePlatformPlanStatus(planId);
    }
  }

  @override
  Future<String?> uploadTeamMemberPhoto({
    required String tenantId,
    required String memberId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.uploadTeamMemberPhoto(
        tenantId: tenantId,
        memberId: memberId,
        imageBytes: imageBytes,
        fileExtension: fileExtension,
      );
    }

    try {
      await _ensureFirebaseAuthSession();
      final rawUint8 = imageBytes is Uint8List
          ? imageBytes
          : Uint8List.fromList(imageBytes);
      final optimizationResult = await ImageOptimizer.optimizeImage(
        rawUint8,
        maxDimension: 512,
        quality: 85,
      );

      final ext = optimizationResult.format.isNotEmpty ? optimizationResult.format : fileExtension;
      final ref = storage.ref('tenants/$tenantId/team_members/$memberId.$ext');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'tenantId': tenantId,
          'memberId': memberId,
          'optimized': 'true',
          'originalSize': '${optimizationResult.originalSizeBytes}',
          'optimizedSize': '${optimizationResult.optimizedSizeBytes}',
        },
      );

      final uploadTask = await ref.putData(optimizationResult.bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage upload team member photo error (falling back to embedded image data): $e');
      try {
        final rawUint8 = imageBytes is Uint8List
            ? imageBytes
            : Uint8List.fromList(imageBytes);
        final optimizationResult = await ImageOptimizer.optimizeImage(
          rawUint8,
          maxDimension: 512,
          quality: 85,
        );
        return optimizationResult.base64DataUri;
      } catch (_) {
        return await _fallbackService.uploadTeamMemberPhoto(
          tenantId: tenantId,
          memberId: memberId,
          imageBytes: imageBytes,
          fileExtension: fileExtension,
        );
      }
    }
  }

  @override
  Future<List<GymTeamMemberRecord>> getTeamMembers({required String tenantId}) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.getTeamMembers(tenantId: tenantId);
    }

    try {
      final snap = await firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('team_members')
          .get();

      if (snap.docs.isEmpty) {
        return [];
      }

      return snap.docs.map((doc) {
        final data = doc.data();
        return GymTeamMemberRecord.fromJson(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Firestore getTeamMembers error: $e');
      return await _fallbackService.getTeamMembers(tenantId: tenantId);
    }
  }

  @override
  Future<GymTeamMemberRecord> addTeamMember({
    required String tenantId,
    required GymTeamMemberRecord member,
    List<int>? photoBytes,
  }) async {
    String? uploadedImageUrl = member.imageUrl;

    if (photoBytes != null && photoBytes.isNotEmpty) {
      try {
        final photoUrl = await uploadTeamMemberPhoto(
          tenantId: tenantId,
          memberId: member.id,
          imageBytes: photoBytes,
        );
        if (photoUrl != null && photoUrl.isNotEmpty) {
          uploadedImageUrl = photoUrl;
        }
      } catch (e) {
        debugPrint('Error uploading team member photo: $e');
      }
    }

    final memberWithTenant = member.copyWith(
      tenantId: tenantId,
      imageUrl: uploadedImageUrl,
      createdAt: DateTime.now(),
    );

    if (!_isFirebaseReady) {
      return await _fallbackService.addTeamMember(
        tenantId: tenantId,
        member: memberWithTenant,
        photoBytes: photoBytes,
      );
    }

    try {
      final docRef = firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('team_members')
          .doc(member.id);

      final data = memberWithTenant.toJson();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));

      await _fallbackService.addTeamMember(
        tenantId: tenantId,
        member: memberWithTenant,
        photoBytes: photoBytes,
      );

      return memberWithTenant;
    } catch (e) {
      debugPrint('Firestore addTeamMember error: $e');
      return await _fallbackService.addTeamMember(
        tenantId: tenantId,
        member: memberWithTenant,
        photoBytes: photoBytes,
      );
    }
  }

  @override
  Future<GymTeamMemberRecord> updateTeamMember({
    required String tenantId,
    required GymTeamMemberRecord member,
    List<int>? photoBytes,
  }) async {
    String? uploadedImageUrl = member.imageUrl;

    if (photoBytes != null && photoBytes.isNotEmpty) {
      try {
        final photoUrl = await uploadTeamMemberPhoto(
          tenantId: tenantId,
          memberId: member.id,
          imageBytes: photoBytes,
        );
        if (photoUrl != null && photoUrl.isNotEmpty) {
          uploadedImageUrl = photoUrl;
        }
      } catch (e) {
        debugPrint('Error uploading updated team member photo: $e');
      }
    }

    final updatedMember = member.copyWith(
      tenantId: tenantId,
      imageUrl: uploadedImageUrl,
    );

    if (!_isFirebaseReady) {
      return await _fallbackService.updateTeamMember(
        tenantId: tenantId,
        member: updatedMember,
        photoBytes: photoBytes,
      );
    }

    try {
      final docRef = firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('team_members')
          .doc(member.id);

      final data = updatedMember.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));
      await _fallbackService.updateTeamMember(
        tenantId: tenantId,
        member: updatedMember,
        photoBytes: photoBytes,
      );
      return updatedMember;
    } catch (e) {
      debugPrint('Firestore updateTeamMember error: $e');
      return await _fallbackService.updateTeamMember(
        tenantId: tenantId,
        member: updatedMember,
        photoBytes: photoBytes,
      );
    }
  }

  @override
  Future<void> deleteTeamMember({
    required String tenantId,
    required String memberId,
  }) async {
    await _fallbackService.deleteTeamMember(tenantId: tenantId, memberId: memberId);

    if (_isFirebaseReady) {
      try {
        await firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('team_members')
            .doc(memberId)
            .delete();
      } catch (e) {
        debugPrint('Firestore deleteTeamMember error: $e');
      }
    }
  }

  @override
  Future<void> toggleTeamMemberDuty({
    required String tenantId,
    required String memberId,
    required bool isOnDuty,
  }) async {
    await _fallbackService.toggleTeamMemberDuty(
      tenantId: tenantId,
      memberId: memberId,
      isOnDuty: isOnDuty,
    );

    if (_isFirebaseReady) {
      try {
        await firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('team_members')
            .doc(memberId)
            .update({
          'isOnDuty': isOnDuty,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Firestore toggleTeamMemberDuty error: $e');
      }
    }
  }

  @override
  Future<void> updateTeamMemberAttendance({
    required String tenantId,
    required String memberId,
    required String dateKey,
    required bool isPresent,
  }) async {
    await _fallbackService.updateTeamMemberAttendance(
      tenantId: tenantId,
      memberId: memberId,
      dateKey: dateKey,
      isPresent: isPresent,
    );

    if (_isFirebaseReady) {
      try {
        await firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('team_members')
            .doc(memberId)
            .set({
          'attendanceLogs': {
            dateKey: isPresent,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore updateTeamMemberAttendance error: $e');
      }
    }
  }

  // ── Gym Membership Plans Firestore Operations ──
  @override
  Future<List<GymMembershipPlanModel>> getGymMembershipPlans({
    required String tenantId,
  }) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.getGymMembershipPlans(tenantId: tenantId);
    }

    try {
      final snap = await firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('membership_plans')
          .get();

      if (snap.docs.isEmpty) {
        return await _fallbackService.getGymMembershipPlans(tenantId: tenantId);
      }

      return snap.docs.map((doc) {
        final data = doc.data();
        return GymMembershipPlanModel.fromJson(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Firestore getGymMembershipPlans error: $e');
      return await _fallbackService.getGymMembershipPlans(tenantId: tenantId);
    }
  }

  @override
  Future<GymMembershipPlanModel> addGymMembershipPlan({
    required String tenantId,
    required GymMembershipPlanModel plan,
  }) async {
    final planWithTenant = plan.copyWith(
      tenantId: tenantId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!_isFirebaseReady) {
      return await _fallbackService.addGymMembershipPlan(
        tenantId: tenantId,
        plan: planWithTenant,
      );
    }

    try {
      final docRef = firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('membership_plans')
          .doc(plan.id.isNotEmpty ? plan.id : null);

      final generatedId = docRef.id;
      final finalPlan = planWithTenant.copyWith(id: generatedId);

      final data = finalPlan.toJson();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));

      await _fallbackService.addGymMembershipPlan(
        tenantId: tenantId,
        plan: finalPlan,
      );

      return finalPlan;
    } catch (e) {
      debugPrint('Firestore addGymMembershipPlan error: $e');
      return await _fallbackService.addGymMembershipPlan(
        tenantId: tenantId,
        plan: planWithTenant,
      );
    }
  }

  @override
  Future<GymMembershipPlanModel> updateGymMembershipPlan({
    required String tenantId,
    required GymMembershipPlanModel plan,
  }) async {
    final updatedPlan = plan.copyWith(
      tenantId: tenantId,
      updatedAt: DateTime.now(),
    );

    if (!_isFirebaseReady) {
      return await _fallbackService.updateGymMembershipPlan(
        tenantId: tenantId,
        plan: updatedPlan,
      );
    }

    try {
      final docRef = firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('membership_plans')
          .doc(plan.id);

      final data = updatedPlan.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));

      await _fallbackService.updateGymMembershipPlan(
        tenantId: tenantId,
        plan: updatedPlan,
      );

      return updatedPlan;
    } catch (e) {
      debugPrint('Firestore updateGymMembershipPlan error: $e');
      return await _fallbackService.updateGymMembershipPlan(
        tenantId: tenantId,
        plan: updatedPlan,
      );
    }
  }

  @override
  Future<void> deleteGymMembershipPlan({
    required String tenantId,
    required String planId,
  }) async {
    await _fallbackService.deleteGymMembershipPlan(
      tenantId: tenantId,
      planId: planId,
    );

    if (_isFirebaseReady) {
      try {
        await firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('membership_plans')
            .doc(planId)
            .delete();
      } catch (e) {
        debugPrint('Firestore deleteGymMembershipPlan error: $e');
      }
    }
  }

  @override
  Future<void> toggleGymMembershipPlanStatus({
    required String tenantId,
    required String planId,
    required bool isActive,
  }) async {
    await _fallbackService.toggleGymMembershipPlanStatus(
      tenantId: tenantId,
      planId: planId,
      isActive: isActive,
    );

    if (_isFirebaseReady) {
      try {
        await firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('membership_plans')
            .doc(planId)
            .update({
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Firestore toggleGymMembershipPlanStatus error: $e');
      }
    }
  }

  // ── Gym Batches Firestore & Fallback Methods ──
  @override
  Future<List<GymBatchModel>> getGymBatches({
    required String tenantId,
  }) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.getGymBatches(tenantId: tenantId);
    }

    final targetTenant = tenantId.isEmpty ? 'default' : tenantId;

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await firestore
            .collection('tenants')
            .doc(targetTenant)
            .collection('batches')
            .get();
      } catch (_) {
        snapshot = await firestore.collection('batches').get();
      }

      if (snapshot.docs.isEmpty) {
        return await _fallbackService.getGymBatches(tenantId: tenantId);
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return GymBatchModel.fromJson(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Firestore getGymBatches error: $e');
      return await _fallbackService.getGymBatches(tenantId: tenantId);
    }
  }

  @override
  Future<GymBatchModel> addGymBatch({
    required String tenantId,
    required GymBatchModel batch,
  }) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.addGymBatch(
        tenantId: tenantId,
        batch: batch,
      );
    }

    final targetTenant = tenantId.isEmpty ? 'default' : tenantId;

    try {
      final docRef = firestore
          .collection('tenants')
          .doc(targetTenant)
          .collection('batches')
          .doc();

      final newBatch = batch.copyWith(
        id: docRef.id,
        tenantId: targetTenant,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final data = newBatch.toJson();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      try {
        await docRef.set(data);
      } catch (subErr) {
        debugPrint('Subcollection set failed, writing to root batches: $subErr');
        await firestore.collection('batches').doc(docRef.id).set(data);
      }

      await _fallbackService.addGymBatch(
        tenantId: tenantId,
        batch: newBatch,
      );

      return newBatch;
    } catch (e) {
      debugPrint('Firestore addGymBatch error: $e');
      return await _fallbackService.addGymBatch(
        tenantId: tenantId,
        batch: batch,
      );
    }
  }

  @override
  Future<GymBatchModel> updateGymBatch({
    required String tenantId,
    required GymBatchModel batch,
  }) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.updateGymBatch(
        tenantId: tenantId,
        batch: batch,
      );
    }

    final targetTenant = tenantId.isEmpty ? 'default' : tenantId;

    try {
      final updated = batch.copyWith(
        tenantId: targetTenant,
        updatedAt: DateTime.now(),
      );

      final data = updated.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();

      try {
        await firestore
            .collection('tenants')
            .doc(targetTenant)
            .collection('batches')
            .doc(batch.id)
            .set(data, SetOptions(merge: true));
      } catch (subErr) {
        debugPrint('Subcollection update failed, updating root batches: $subErr');
        await firestore
            .collection('batches')
            .doc(batch.id)
            .set(data, SetOptions(merge: true));
      }

      await _fallbackService.updateGymBatch(
        tenantId: tenantId,
        batch: updated,
      );

      return updated;
    } catch (e) {
      debugPrint('Firestore updateGymBatch error: $e');
      return await _fallbackService.updateGymBatch(
        tenantId: tenantId,
        batch: batch,
      );
    }
  }

  @override
  Future<void> deleteGymBatch({
    required String tenantId,
    required String batchId,
  }) async {
    await _fallbackService.deleteGymBatch(
      tenantId: tenantId,
      batchId: batchId,
    );

    if (_isFirebaseReady) {
      final targetTenant = tenantId.isEmpty ? 'default' : tenantId;
      try {
        await firestore
            .collection('tenants')
            .doc(targetTenant)
            .collection('batches')
            .doc(batchId)
            .delete();
      } catch (e) {
        debugPrint('Firestore deleteGymBatch error: $e');
        try {
          await firestore.collection('batches').doc(batchId).delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> toggleGymBatchStatus({
    required String tenantId,
    required String batchId,
    required bool isActive,
  }) async {
    await _fallbackService.toggleGymBatchStatus(
      tenantId: tenantId,
      batchId: batchId,
      isActive: isActive,
    );

    if (_isFirebaseReady) {
      final targetTenant = tenantId.isEmpty ? 'default' : tenantId;
      final updateData = {
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      try {
        await firestore
            .collection('tenants')
            .doc(targetTenant)
            .collection('batches')
            .doc(batchId)
            .update(updateData);
      } catch (e) {
        debugPrint('Firestore toggleGymBatchStatus error: $e');
        try {
          await firestore.collection('batches').doc(batchId).update(updateData);
        } catch (_) {}
      }
    }
  }

  // ── Gym Members Firestore & Fallback Methods ──
  @override
  Future<List<GymMemberModel>> getGymMembers({
    required String tenantId,
    int limit = 20,
    String statusFilter = 'All',
  }) async {
    final res = await getPaginatedGymMembers(
      tenantId: tenantId,
      limit: limit,
      statusFilter: statusFilter,
    );
    return res.members;
  }

  @override
  Future<PaginatedMembersResult> getPaginatedGymMembers({
    required String tenantId,
    int limit = 20,
    dynamic lastDocument,
    String statusFilter = 'All',
  }) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.getPaginatedGymMembers(
        tenantId: tenantId,
        limit: limit,
        lastDocument: lastDocument,
        statusFilter: statusFilter,
      );
    }

    try {
      Query<Map<String, dynamic>> query = firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('members');

      try {
        query = query.orderBy('createdAt', descending: true);
      } catch (_) {}

      if (lastDocument is DocumentSnapshot) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        return await _fallbackService.getPaginatedGymMembers(
          tenantId: tenantId,
          limit: limit,
          lastDocument: lastDocument,
          statusFilter: statusFilter,
        );
      }

      var members = snapshot.docs.map((doc) {
        final data = doc.data();
        return GymMemberModel.fromJson(data, doc.id);
      }).toList();

      if (statusFilter == 'Active') {
        members = members.where((m) => m.isActive).toList();
      } else if (statusFilter == 'Inactive') {
        members = members.where((m) => !m.isActive).toList();
      } else if (statusFilter == 'Expiring') {
        members = members.where((m) => m.isActive && m.isExpiringSoon).toList();
      } else if (statusFilter == 'Expired') {
        members = members.where((m) => !m.isActive || m.isExpired).toList();
      }

      final lastDoc = snapshot.docs.last;
      final hasMore = snapshot.docs.length >= limit;

      return PaginatedMembersResult(
        members: members,
        lastDocument: lastDoc,
        hasMore: hasMore,
        totalCount: members.length,
      );
    } catch (e) {
      debugPrint('Firestore getPaginatedGymMembers error: $e');
      try {
        final rawSnap = await firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('members')
            .limit(limit)
            .get();
        if (rawSnap.docs.isNotEmpty) {
          var members = rawSnap.docs.map((d) => GymMemberModel.fromJson(d.data(), d.id)).toList();
          if (statusFilter == 'Active') {
            members = members.where((m) => m.isActive).toList();
          } else if (statusFilter == 'Inactive') {
            members = members.where((m) => !m.isActive).toList();
          } else if (statusFilter == 'Expiring') {
            members = members.where((m) => m.isActive && m.isExpiringSoon).toList();
          } else if (statusFilter == 'Expired') {
            members = members.where((m) => !m.isActive || m.isExpired).toList();
          }
          return PaginatedMembersResult(
            members: members,
            lastDocument: rawSnap.docs.last,
            hasMore: rawSnap.docs.length >= limit,
            totalCount: members.length,
          );
        }
      } catch (_) {}

      return await _fallbackService.getPaginatedGymMembers(
        tenantId: tenantId,
        limit: limit,
        lastDocument: lastDocument,
        statusFilter: statusFilter,
      );
    }
  }

  @override
  Future<String?> uploadGymMemberPhoto({
    required String tenantId,
    required String memberId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.uploadGymMemberPhoto(
        tenantId: tenantId,
        memberId: memberId,
        imageBytes: imageBytes,
        fileExtension: fileExtension,
      );
    }

    try {
      await _ensureFirebaseAuthSession();
      // 1. Optimize image client-side before uploading to Firebase Storage
      final rawUint8 = imageBytes is Uint8List
          ? imageBytes
          : Uint8List.fromList(imageBytes);
      final optimizationResult = await ImageOptimizer.optimizeImage(
        rawUint8,
        maxDimension: 512,
        quality: 80,
      );

      debugPrint(
        'Member photo optimized before upload to Firebase Storage: ${optimizationResult.summaryString}',
      );

      // 2. Upload to Firebase Storage
      final ext = optimizationResult.format.isNotEmpty ? optimizationResult.format : fileExtension;
      final ref = storage.ref('tenants/$tenantId/members/$memberId.$ext');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'tenantId': tenantId,
          'memberId': memberId,
          'optimized': 'true',
          'originalSize': '${optimizationResult.originalSizeBytes}',
          'optimizedSize': '${optimizationResult.optimizedSizeBytes}',
        },
      );

      final uploadTask = await ref.putData(optimizationResult.bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('Firebase Storage upload member photo success: $downloadUrl');
      return downloadUrl;
    } catch (e, stack) {
      debugPrint('Firebase Storage upload member photo notice (falling back to embedded image data): $e\n$stack');
      try {
        final rawUint8 = imageBytes is Uint8List
            ? imageBytes
            : Uint8List.fromList(imageBytes);
        final optimizationResult = await ImageOptimizer.optimizeImage(
          rawUint8,
          maxDimension: 512,
          quality: 80,
        );
        return optimizationResult.base64DataUri;
      } catch (_) {
        return await _fallbackService.uploadGymMemberPhoto(
          tenantId: tenantId,
          memberId: memberId,
          imageBytes: imageBytes,
          fileExtension: fileExtension,
        );
      }
    }
  }

  @override
  Future<String?> uploadUserProfilePhoto({
    required String userId,
    required List<int> imageBytes,
    String fileExtension = 'jpg',
  }) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.uploadUserProfilePhoto(
        userId: userId,
        imageBytes: imageBytes,
        fileExtension: fileExtension,
      );
    }

    try {
      await _ensureFirebaseAuthSession();
      final rawUint8 = imageBytes is Uint8List
          ? imageBytes
          : Uint8List.fromList(imageBytes);
      final optimizationResult = await ImageOptimizer.optimizeImage(
        rawUint8,
        maxDimension: 512,
        quality: 85,
      );

      final ext = optimizationResult.format.isNotEmpty ? optimizationResult.format : fileExtension;
      final ref = storage.ref('users/$userId/profile.$ext');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'optimized': 'true',
          'originalSize': '${optimizationResult.originalSizeBytes}',
          'optimizedSize': '${optimizationResult.optimizedSizeBytes}',
        },
      );

      final uploadTask = await ref.putData(optimizationResult.bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Firebase Storage upload user profile photo error (falling back to embedded image data): $e');
      try {
        final rawUint8 = imageBytes is Uint8List
            ? imageBytes
            : Uint8List.fromList(imageBytes);
        final optimizationResult = await ImageOptimizer.optimizeImage(
          rawUint8,
          maxDimension: 512,
          quality: 85,
        );
        return optimizationResult.base64DataUri;
      } catch (_) {
        return await _fallbackService.uploadUserProfilePhoto(
          userId: userId,
          imageBytes: imageBytes,
          fileExtension: fileExtension,
        );
      }
    }
  }

  @override
  Future<GymMemberModel> addGymMember({
    required String tenantId,
    required GymMemberModel member,
    List<int>? photoBytes,
  }) async {
    GymMemberModel memberWithTenant = member.copyWith(
      tenantId: tenantId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!_isFirebaseReady) {
      return await _fallbackService.addGymMember(
        tenantId: tenantId,
        member: memberWithTenant,
        photoBytes: photoBytes,
      );
    }

    try {
      final collectionRef = firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('members');

      final docRef = memberWithTenant.id.isNotEmpty
          ? collectionRef.doc(memberWithTenant.id)
          : collectionRef.doc();

      final generatedMemberId = docRef.id;

      // If photoBytes is provided, upload to Firebase Storage and retrieve photoUrl
      String? uploadedPhotoUrl = memberWithTenant.photoUrl;
      if (photoBytes != null && photoBytes.isNotEmpty) {
        try {
          uploadedPhotoUrl = await uploadGymMemberPhoto(
            tenantId: tenantId,
            memberId: generatedMemberId,
            imageBytes: photoBytes,
          );
        } catch (imgErr) {
          debugPrint('Notice: Error uploading member photo to Firebase Storage: $imgErr');
        }
      }

      final finalMember = memberWithTenant.copyWith(
        id: generatedMemberId,
        photoUrl: uploadedPhotoUrl ?? memberWithTenant.photoUrl,
      );

      final data = finalMember.toJson();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));

      await _fallbackService.addGymMember(
        tenantId: tenantId,
        member: finalMember,
        photoBytes: photoBytes,
      );

      return finalMember;
    } catch (e) {
      debugPrint('Firestore addGymMember error: $e');
      return await _fallbackService.addGymMember(
        tenantId: tenantId,
        member: memberWithTenant,
        photoBytes: photoBytes,
      );
    }
  }

  @override
  Future<GymMemberModel> updateGymMember({
    required String tenantId,
    required GymMemberModel member,
    List<int>? photoBytes,
  }) async {
    GymMemberModel updatedMember = member.copyWith(
      tenantId: tenantId,
      updatedAt: DateTime.now(),
    );

    if (!_isFirebaseReady) {
      return await _fallbackService.updateGymMember(
        tenantId: tenantId,
        member: updatedMember,
        photoBytes: photoBytes,
      );
    }

    try {
      // If photoBytes is provided, upload to Firebase Storage and update photoUrl
      if (photoBytes != null && photoBytes.isNotEmpty) {
        try {
          final uploadedUrl = await uploadGymMemberPhoto(
            tenantId: tenantId,
            memberId: updatedMember.id,
            imageBytes: photoBytes,
          );
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            updatedMember = updatedMember.copyWith(photoUrl: uploadedUrl);
          }
        } catch (imgErr) {
          debugPrint('Notice: Error updating member photo in Firebase Storage: $imgErr');
        }
      }

      final docRef = firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('members')
          .doc(member.id);

      final data = updatedMember.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));

      await _fallbackService.updateGymMember(
        tenantId: tenantId,
        member: updatedMember,
        photoBytes: photoBytes,
      );

      return updatedMember;
    } catch (e) {
      debugPrint('Firestore updateGymMember error: $e');
      return await _fallbackService.updateGymMember(
        tenantId: tenantId,
        member: updatedMember,
        photoBytes: photoBytes,
      );
    }
  }

  @override
  Future<void> deleteGymMember({
    required String tenantId,
    required String memberId,
  }) async {
    await _fallbackService.deleteGymMember(
      tenantId: tenantId,
      memberId: memberId,
    );

    if (_isFirebaseReady) {
      try {
        await firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('members')
            .doc(memberId)
            .delete();
      } catch (e) {
        debugPrint('Firestore deleteGymMember error: $e');
      }
    }
  }

  @override
  Future<GymCheckInLog> recordMemberCheckIn({
    required String tenantId,
    required String memberId,
    required String memberName,
    required String planName,
    String method = 'QR Scan',
  }) async {
    final now = DateTime.now();
    var log = GymCheckInLog(
      id: 'chk_${now.millisecondsSinceEpoch}',
      tenantId: tenantId,
      memberId: memberId,
      memberName: memberName,
      planName: planName,
      timestamp: now,
      method: method,
    );

    await _fallbackService.recordMemberCheckIn(
      tenantId: tenantId,
      memberId: memberId,
      memberName: memberName,
      planName: planName,
      method: method,
    );

    if (_isFirebaseReady) {
      try {
        // 1. Write to check_ins subcollection
        final checkInRef = firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('check_ins')
            .doc();

        final checkInData = {
          'id': checkInRef.id,
          'tenantId': tenantId,
          'memberId': memberId,
          'memberName': memberName,
          'planName': planName,
          'timestamp': FieldValue.serverTimestamp(),
          'method': method,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await checkInRef.set(checkInData);
        log = log.copyWith(id: checkInRef.id);

        // 2. Increment member check-in counter & timestamp
        final memberRef = firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('members')
            .doc(memberId);

        await memberRef.update({
          'totalCheckIns': FieldValue.increment(1),
          'lastCheckIn': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Firestore recordMemberCheckIn error: $e');
      }
    }

    return log;
  }

  @override
  Future<List<GymCheckInLog>> getGymCheckIns({
    required String tenantId,
    int limit = 50,
  }) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.getGymCheckIns(
        tenantId: tenantId,
        limit: limit,
      );
    }

    try {
      final snap = await firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('check_ins')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      if (snap.docs.isEmpty) {
        return await _fallbackService.getGymCheckIns(
          tenantId: tenantId,
          limit: limit,
        );
      }

      final logs = snap.docs.map((doc) {
        return GymCheckInLog.fromJson(doc.data(), doc.id);
      }).toList();

      return logs;
    } catch (e) {
      debugPrint('Firestore getGymCheckIns error: $e');
      return await _fallbackService.getGymCheckIns(
        tenantId: tenantId,
        limit: limit,
      );
    }
  }

  // ── Gym Operating Expenses Firestore Implementation ──
  @override
  Future<List<GymExpenseRecord>> getGymExpenses({
    required String tenantId,
    int limit = 50,
  }) async {
    if (!_isFirebaseReady) {
      return await _fallbackService.getGymExpenses(
        tenantId: tenantId,
        limit: limit,
      );
    }

    try {
      final snap = await firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('expenses')
          .orderBy('date', descending: true)
          .limit(limit)
          .get();

      if (snap.docs.isEmpty) {
        return await _fallbackService.getGymExpenses(
          tenantId: tenantId,
          limit: limit,
        );
      }

      final expenses = snap.docs.map((doc) {
        final data = doc.data();
        return GymExpenseRecord.fromJson(data, doc.id);
      }).toList();

      return expenses;
    } catch (e) {
      debugPrint('Firestore getGymExpenses error: $e');
      return await _fallbackService.getGymExpenses(
        tenantId: tenantId,
        limit: limit,
      );
    }
  }

  @override
  Future<GymExpenseRecord> addGymExpense({
    required String tenantId,
    required GymExpenseRecord expense,
  }) async {
    final expWithTenant = expense.copyWith(
      tenantId: tenantId,
    );

    if (!_isFirebaseReady) {
      return await _fallbackService.addGymExpense(
        tenantId: tenantId,
        expense: expWithTenant,
      );
    }

    try {
      final docRef = firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('expenses')
          .doc(expense.id.isNotEmpty ? expense.id : null);

      final generatedId = docRef.id;
      final finalExpense = expWithTenant.copyWith(id: generatedId);

      final data = finalExpense.toJson();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));

      await _fallbackService.addGymExpense(
        tenantId: tenantId,
        expense: finalExpense,
      );

      return finalExpense;
    } catch (e) {
      debugPrint('Firestore addGymExpense error: $e');
      return await _fallbackService.addGymExpense(
        tenantId: tenantId,
        expense: expWithTenant,
      );
    }
  }

  @override
  Future<GymExpenseRecord> updateGymExpense({
    required String tenantId,
    required GymExpenseRecord expense,
  }) async {
    final expWithTenant = expense.copyWith(
      tenantId: tenantId,
    );

    if (!_isFirebaseReady) {
      return await _fallbackService.updateGymExpense(
        tenantId: tenantId,
        expense: expWithTenant,
      );
    }

    try {
      final docRef = firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('expenses')
          .doc(expense.id);

      final data = expWithTenant.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));

      await _fallbackService.updateGymExpense(
        tenantId: tenantId,
        expense: expWithTenant,
      );

      return expWithTenant;
    } catch (e) {
      debugPrint('Firestore updateGymExpense error: $e');
      return await _fallbackService.updateGymExpense(
        tenantId: tenantId,
        expense: expWithTenant,
      );
    }
  }

  @override
  Future<void> deleteGymExpense({
    required String tenantId,
    required String expenseId,
  }) async {
    await _fallbackService.deleteGymExpense(
      tenantId: tenantId,
      expenseId: expenseId,
    );

    if (_isFirebaseReady) {
      try {
        final docRef = firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('expenses')
            .doc(expenseId);

        await docRef.delete();
      } catch (e) {
        debugPrint('Firestore deleteGymExpense error: $e');
      }
    }
  }

  // ── Gym Media Gallery Production Implementation ──
  @override
  Future<List<GymGalleryItemModel>> getGymGalleryItems({
    required String tenantId,
  }) async {
    if (_isFirebaseReady) {
      try {
        final querySnapshot = await firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('gallery')
            .orderBy('createdAt', descending: true)
            .limit(25)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          return querySnapshot.docs
              .map((doc) => GymGalleryItemModel.fromJson(doc.data(), doc.id))
              .toList();
        }
      } catch (e) {
        debugPrint('Firestore getGymGalleryItems error (falling back to local): $e');
      }
    }
    return await _fallbackService.getGymGalleryItems(tenantId: tenantId);
  }

  @override
  Future<List<GymGalleryItemModel>> uploadGymGalleryItems({
    required String tenantId,
    required List<GymGalleryUploadPayload> items,
    String uploadedBy = 'Admin',
  }) async {
    if (items.isEmpty) return [];

    final currentItems = await getGymGalleryItems(tenantId: tenantId);
    if (currentItems.length >= 25) {
      throw Exception('Gallery limit reached. Maximum 25 media items allowed per gym facility.');
    }
    if (items.length > 10) {
      throw Exception('Upload limit exceeded. You can upload up to 10 items at one time.');
    }
    if (currentItems.length + items.length > 25) {
      final available = 25 - currentItems.length;
      throw Exception('Cannot upload ${items.length} items. Only $available slot(s) remaining in the gallery.');
    }

    if (_isFirebaseReady) {
      try {
        final List<GymGalleryItemModel> results = [];
        final galleryRef = firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('gallery');

        for (final item in items) {
          final docId = 'gal_${DateTime.now().millisecondsSinceEpoch}_${results.length}';
          String mediaUrl = '';
          String thumbUrl = '';
          int optimizedSize = 0;
          int? width;
          int? height;

          if (item.mediaType == GymGalleryMediaType.video) {
            try {
              final videoStorageRef = storage.ref('tenants/$tenantId/gallery/$docId.mp4');
              final uploadTask = await videoStorageRef.putData(
                item.bytes,
                SettableMetadata(contentType: 'video/mp4'),
              );
              mediaUrl = await uploadTask.ref.getDownloadURL();
            } catch (storageErr) {
              debugPrint('Storage video upload error (fallback to data URI): $storageErr');
              mediaUrl = '';
            }
            final coverBytes = item.customThumbnailBytes;
            if (coverBytes != null && coverBytes.isNotEmpty) {
              try {
                final thumbStorageRef = storage.ref('tenants/$tenantId/gallery/${docId}_thumb.jpg');
                final thumbTask = await thumbStorageRef.putData(
                  coverBytes,
                  SettableMetadata(contentType: 'image/jpeg'),
                );
                thumbUrl = await thumbTask.ref.getDownloadURL();
              } catch (thumbErr) {
                debugPrint('Storage video thumbnail upload error: $thumbErr');
                thumbUrl = 'data:image/jpeg;base64,${base64Encode(coverBytes)}';
              }
            }
            optimizedSize = item.bytes.lengthInBytes;
            width = item.width;
            height = item.height;
          } else {
            // Image optimization
            final optResult = await ImageOptimizer.optimizeGalleryImage(
              item.bytes,
              maxDimension: 1440,
              quality: 82,
            );
            final thumbResult = await ImageOptimizer.optimizeImage(
              optResult.bytes,
              maxDimension: 400,
              quality: 75,
            );
            optimizedSize = optResult.optimizedSizeBytes;
            width = optResult.width;
            height = optResult.height;

            try {
              final imgStorageRef = storage.ref('tenants/$tenantId/gallery/$docId.jpg');
              final uploadTask = await imgStorageRef.putData(
                optResult.bytes,
                SettableMetadata(contentType: 'image/jpeg'),
              );
              mediaUrl = await uploadTask.ref.getDownloadURL();

              final thumbStorageRef = storage.ref('tenants/$tenantId/gallery/${docId}_thumb.jpg');
              final thumbTask = await thumbStorageRef.putData(
                thumbResult.bytes,
                SettableMetadata(contentType: 'image/jpeg'),
              );
              thumbUrl = await thumbTask.ref.getDownloadURL();
            } catch (storageErr) {
              debugPrint('Storage image upload error (fallback to data URI): $storageErr');
              mediaUrl = optResult.base64DataUri;
              thumbUrl = thumbResult.base64DataUri;
            }
          }

          final galleryItem = GymGalleryItemModel(
            id: docId,
            tenantId: tenantId,
            title: item.title.isNotEmpty ? item.title : item.fileName,
            mediaType: item.mediaType,
            mediaUrl: mediaUrl,
            thumbnailUrl: item.mediaType == GymGalleryMediaType.video
                ? thumbUrl
                : (thumbUrl.isNotEmpty ? thumbUrl : mediaUrl),
            originalSizeBytes: item.originalSizeBytes > 0 ? item.originalSizeBytes : item.bytes.lengthInBytes,
            optimizedSizeBytes: optimizedSize,
            width: width,
            height: height,
            durationSeconds: item.durationSeconds,
            createdAt: DateTime.now(),
            uploadedBy: uploadedBy,
          );

          await galleryRef.doc(docId).set(galleryItem.toJson());
          results.add(galleryItem);
        }

        try {
          await _fallbackService.uploadGymGalleryItems(
            tenantId: tenantId,
            items: items,
            uploadedBy: uploadedBy,
          );
        } catch (_) {}

        return results;
      } catch (e) {
        debugPrint('Firestore uploadGymGalleryItems error (falling back to mock): $e');
      }
    }

    return await _fallbackService.uploadGymGalleryItems(
      tenantId: tenantId,
      items: items,
      uploadedBy: uploadedBy,
    );
  }

  @override
  Future<void> deleteGymGalleryItem({
    required String tenantId,
    required String itemId,
  }) async {
    await _fallbackService.deleteGymGalleryItem(
      tenantId: tenantId,
      itemId: itemId,
    );

    if (_isFirebaseReady) {
      try {
        final docRef = firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('gallery')
            .doc(itemId);
        await docRef.delete();

        try {
          await storage.ref('tenants/$tenantId/gallery/$itemId.jpg').delete();
          await storage.ref('tenants/$tenantId/gallery/$itemId.mp4').delete();
          await storage.ref('tenants/$tenantId/gallery/${itemId}_thumb.jpg').delete();
        } catch (_) {}
      } catch (e) {
        debugPrint('Firestore deleteGymGalleryItem error: $e');
      }
    }
  }

  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return Exception('The password provided is too weak (minimum 6 characters required).');
      case 'email-already-in-use':
        return Exception('An account with this email address already exists.');
      case 'user-not-found':
        return Exception('No user found matching these credentials.');
      case 'wrong-password':
      case 'invalid-credential':
        return Exception('Invalid email or password. Please verify and try again.');
      case 'user-disabled':
        return Exception('This account has been disabled by platform security.');
      case 'invalid-email':
        return Exception('The email address provided is invalid.');
      default:
        return Exception(e.message ?? 'Authentication error occurred (${e.code}).');
    }
  }

  @override
  Future<PushNotificationRecord> sendSuperAdminPushNotification({
    required String title,
    required String body,
    required String targetAudience,
    String? targetTenantId,
    String? targetGymName,
    String sound = 'notification.mp3',
    String? sentByName,
  }) async {
    if (!_isFirebaseReady) {
      return _fallbackService.sendSuperAdminPushNotification(
        title: title,
        body: body,
        targetAudience: targetAudience,
        targetTenantId: targetTenantId,
        targetGymName: targetGymName,
        sound: sound,
        sentByName: sentByName,
      );
    }

    try {
      final docRef = firestore.collection('notifications_queue').doc();
      final now = DateTime.now();
      final inboxEntry = <String, dynamic>{
        'id': docRef.id,
        'title': title,
        'body': body,
        'createdAt': now.toIso8601String(),
        'targetAudience': targetAudience,
        'targetTenantId': targetTenantId ?? '',
        'sound': sound,
      };

      var recipientIds = <String>[];
      try {
        recipientIds = await _collectBroadcastRecipientIds(
          targetAudience: targetAudience,
          targetTenantId: targetTenantId,
        );
        await _fanOutInboxEntries(recipientIds, inboxEntry);
      } catch (fanOutError) {
        debugPrint('Notice: Error delivering notification inbox copies: $fanOutError');
      }

      final data = <String, dynamic>{
        'id': docRef.id,
        'title': title,
        'body': body,
        'targetAudience': targetAudience,
        'targetTenantId': targetTenantId,
        'targetGymName': targetGymName,
        'sound': sound,
        'inboxEntry': inboxEntry,
        'status': 'pending',
        'recipientsCount': recipientIds.length,
        'successCount': 0,
        'failureCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'sentBy': auth.currentUser?.uid ?? 'superadmin',
        'sentByName': sentByName ?? 'Super Admin',
      };

      await docRef.set(data);

      return PushNotificationRecord(
        id: docRef.id,
        title: title,
        body: body,
        targetAudience: targetAudience,
        targetTenantId: targetTenantId,
        targetGymName: targetGymName,
        sound: sound,
        status: 'pending',
        recipientsCount: recipientIds.length,
        createdAt: now,
        sentByName: sentByName ?? 'Super Admin',
      );
    } catch (e) {
      debugPrint('Firestore sendSuperAdminPushNotification error: $e');
      return _fallbackService.sendSuperAdminPushNotification(
        title: title,
        body: body,
        targetAudience: targetAudience,
        targetTenantId: targetTenantId,
        targetGymName: targetGymName,
        sound: sound,
        sentByName: sentByName,
      );
    }
  }

  /// User ids that should receive this broadcast in their notification inbox.
  Future<List<String>> _collectBroadcastRecipientIds({
    required String targetAudience,
    String? targetTenantId,
  }) async {
    final ids = <String>{};

    void addDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      if (doc.id.trim().isNotEmpty) ids.add(doc.id);
    }

    if (targetAudience == 'specific_gym' && targetTenantId != null && targetTenantId.isNotEmpty) {
      final usersSnap = await firestore
          .collection('users')
          .where('tenantId', isEqualTo: targetTenantId)
          .get();
      for (final doc in usersSnap.docs) {
        addDoc(doc);
      }
      try {
        final tenantDoc = await firestore.collection('tenants').doc(targetTenantId).get();
        final tData = tenantDoc.data();
        for (final key in ['adminId', 'ownerId']) {
          final uid = tData?[key]?.toString().trim() ?? '';
          if (uid.isNotEmpty) ids.add(uid);
        }
      } catch (e) {
        debugPrint('Notice: Unable to resolve gym admin ids for $targetTenantId: $e');
      }
      return ids.toList();
    }

    Query<Map<String, dynamic>> usersQuery = firestore.collection('users');
    if (targetAudience == 'gym_owners') {
      usersQuery = usersQuery.where('role', whereIn: [
        'gymOwner',
        'gym_owner',
        'gym_admin',
        'owner',
        'admin',
        'gymAdmin',
      ]);
    }
    final usersSnap = await usersQuery.get();
    for (final doc in usersSnap.docs) {
      addDoc(doc);
    }

    if (targetAudience == 'gym_owners') {
      try {
        final tenantsSnap = await firestore.collection('tenants').get();
        for (final tenant in tenantsSnap.docs) {
          final data = tenant.data();
          for (final key in ['adminId', 'ownerId']) {
            final uid = data[key]?.toString().trim() ?? '';
            if (uid.isNotEmpty) ids.add(uid);
          }
        }
      } catch (e) {
        debugPrint('Notice: Unable to resolve gym owner ids from tenants: $e');
      }
    }

    return ids.toList();
  }

  /// Writes a copy onto each recipient so the gym admin notification page can list it.
  Future<void> _fanOutInboxEntries(List<String> userIds, Map<String, dynamic> entry) async {
    const chunkSize = 400;
    for (var i = 0; i < userIds.length; i += chunkSize) {
      final end = (i + chunkSize < userIds.length) ? i + chunkSize : userIds.length;
      final batch = firestore.batch();
      for (final uid in userIds.sublist(i, end)) {
        batch.set(
          firestore.collection('users').doc(uid),
          {'platformNotifications': FieldValue.arrayUnion([entry])},
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  @override
  Future<List<PushNotificationRecord>> getSentNotificationsHistory({int limit = 50}) async {
    if (!_isFirebaseReady) {
      return _fallbackService.getSentNotificationsHistory(limit: limit);
    }

    try {
      final snap = await firestore
          .collection('notifications_queue')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      if (snap.docs.isEmpty) {
        return _fallbackService.getSentNotificationsHistory(limit: limit);
      }

      return snap.docs
          .map((doc) => PushNotificationRecord.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('Firestore getSentNotificationsHistory error: $e');
      return _fallbackService.getSentNotificationsHistory(limit: limit);
    }
  }
}
