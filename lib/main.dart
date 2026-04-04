import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/hive_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/smart_nudge_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_background.dart';
import 'core/theme/theme_provider.dart';
import 'features/habits/presentation/home_screen.dart';
import 'features/habits/presentation/controllers/habit_controller.dart';
import 'core/services/auth_service.dart';
import 'core/services/cloud_sync_service.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

Future<void> main() async {
  // Catch any uncaught async errors from the root zone
  await runZonedGuarded(_run, (error, stack) {
    debugPrint('ZONE ERROR: $error\n$stack');
  });
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientation: portrait-only on iPhone, all on iPad ────────────────────
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
  try {
    if (shortestSide < 600) {
      // iPhone — portrait lock
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      // iPad — all orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  } catch (_) {
    // Silently ignore UISceneErrorDomain orientation errors
    // (occurs in Split View / Stage Manager windowing modes)
  }

  // ── iOS status/nav bar ────────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));

  // ── Global Error Handler ─────────────────────────────────────────────────
  // Catches silent Flutter framework errors that appear as black screens on
  // Android release/profile builds.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exceptionAsString()}');
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              kDebugMode
                  ? details.exceptionAsString()
                  : 'Something went wrong. Please restart the app.',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  };

  // ── Firebase ─────────────────────────────────────────────────────────────
  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    debugPrint('FIREBASE INIT ERROR: $e\n$st');
    // Firebase failure is non-fatal — app will use local-only mode
  }

  // Hive initialization is now strictly managed by AuthService based on user UID

  // ── Notifications ────────────────────────────────────────────────────────
  // Non-fatal: the app works perfectly even if notifications fail to init.
  // On some Android devices/OEMs the permission channel can throw.
  try {
    await NotificationService.init();
  } catch (e, st) {
    debugPrint('NOTIFICATION INIT ERROR (non-fatal): $e\n$st');
  }

  debugPrint('APP STARTED — runApp reached');

  runApp(
    const ProviderScope(
      child: HabitTrackerApp(),
    ),
  );
}

class HabitTrackerApp extends ConsumerStatefulWidget {
  const HabitTrackerApp({super.key});

  @override
  ConsumerState<HabitTrackerApp> createState() => _HabitTrackerAppState();
}

class _HabitTrackerAppState extends ConsumerState<HabitTrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-evaluate and pre-schedule today's nudges each time app comes to foreground
      final habits = ref.read(habitProvider);
      SmartNudgeService.scheduleForToday(habits);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Eagerly initialise background provider
    ref.watch(globalBackgroundThemeProvider);

    final appThemeMode = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);

    // Map our custom enum → Material ThemeMode
    ThemeMode materialThemeMode;
    switch (appThemeMode) {
      case ThemeModeType.light:
        materialThemeMode = ThemeMode.light;
        break;
      case ThemeModeType.dark:
        materialThemeMode = ThemeMode.dark;
        break;
      case ThemeModeType.system:
        materialThemeMode = ThemeMode.system;
        break;
    }

    return MaterialApp(
      title: 'Habitus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: materialThemeMode,
      home: authState.isAuthenticated 
          ? const HomeScreen()
          : const OnboardingScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.3),
            ),
          ),
          // Apply the global gradient behind every page in the app
          child: AppBackground(child: child!),
        );
      },
    );
  }
}

