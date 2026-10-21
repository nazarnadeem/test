import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/config/white_label_config.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/data/repositories/firebase_auth_service.dart';
import 'features/auth/data/repositories/tenant_scoped_auth_repository.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for seamless edge-to-edge dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0D12),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await WhiteLabelConfig.load();
  } on WhiteLabelConfigException catch (error) {
    runApp(_WhiteLabelConfigErrorApp(message: error.message));
    return;
  }

  // Initialize Firebase and Push Notification Service
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase/Notification initialization notice: $e');
  }

  final authRepository = TenantScopedAuthRepository(FirebaseAuthService());
  runApp(GcrmOneApp(authRepository: authRepository));
}

/// Shown when a white-label env file does not name two different gyms.
class _WhiteLabelConfigErrorApp extends StatelessWidget {
  final String message;

  const _WhiteLabelConfigErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              message,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Root Application Widget for GCRM One.
class GcrmOneApp extends StatefulWidget {
  final AuthRepository? authRepository;

  const GcrmOneApp({
    super.key,
    this.authRepository,
  });

  @override
  State<GcrmOneApp> createState() => _GcrmOneAppState();
}

class _GcrmOneAppState extends State<GcrmOneApp> {
  late final AuthController _authController;
  late final AuthRepository _repository;

  @override
  void initState() {
    super.initState();
    final source = widget.authRepository ?? FirebaseAuthService();
    _repository = source is TenantScopedAuthRepository
        ? source
        : TenantScopedAuthRepository(source);
    _authController = AuthController(authRepository: _repository);
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(authRepository: _repository)
        ..add(const CheckInitialSessionEvent()),
      child: MaterialApp(
        title: '${AppStrings.appName} - ${AppStrings.tagline}',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Flagship Dark Gym Theme
        home: SplashScreen(authController: _authController),
      ),
    );
  }
}
