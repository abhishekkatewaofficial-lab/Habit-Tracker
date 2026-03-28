import 'dart:async';
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

Future<void> main() async {
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

  // ── Hive ──────────────────────────────────────────────────────────────────
  await HiveService.init();

  // ── Notifications ─────────────────────────────────────────────────────────
  await NotificationService.init();

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
      title: 'Habit Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: materialThemeMode,
      home: const HomeScreen(),
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

