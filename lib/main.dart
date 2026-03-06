import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Performance
import 'utils/theme_controller.dart';

import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ⚡ Enable Firestore offline cache (10 MB) — faster repeat opens
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 🔔 Init notifications in background — don’t block app launch
  Future.microtask(() => NotificationService().init());

  runApp(const LeaveAdminApp());
}

/// ------------------------------------------------------------
/// 🖥 LEAVEX – ADMIN APPLICATION
/// ------------------------------------------------------------
class LeaveAdminApp extends StatelessWidget {
  const LeaveAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController(),
      builder: (context, mode, child) {
        return MaterialApp(
          title: 'LeaveX Admin Panel',
      debugShowCheckedModeBanner: false,

      /// 🎨 ADMIN THEME (Soulful & Premium)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED), // Violet 600 (Matches User App)
          primary: const Color(0xFF7C3AED),
          secondary: const Color(0xFF6366F1), // Indigo 500
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.white, // Cleaner look
          foregroundColor: Color(0xFF1E293B), // Dark Slate Text
          iconTheme: IconThemeData(color: Color(0xFF64748B)),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Premium Radius
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1), // Slate 200
          ),
          color: Colors.white,
        ),
        // 🅰️ Global Typography Polish
        // 🅰️ Global Typography Polish
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.0),
          displayMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          headlineMedium: TextStyle(fontWeight: FontWeight.w700),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          bodyLarge: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          bodyMedium: TextStyle(fontWeight: FontWeight.w400, fontSize: 14), 
          labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF7C3AED),
        scaffoldBackgroundColor: const Color(0xFF0F172A), 
        cardColor: const Color(0xFF1E293B),
        canvasColor: const Color(0xFF0F172A), 
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
        ),
        fontFamily: 'Roboto',
        // 🅰️ Global Typography Polish (Dark)
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.0, color: Colors.white),
          displayMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
          headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
          bodyLarge: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Color(0xFFE2E8F0)),
          bodyMedium: TextStyle(fontWeight: FontWeight.w400, fontSize: 14, color: Color(0xFFCBD5E1)),
          labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      themeMode: mode,

      /// ✅ STARTING SCREEN
      initialRoute: AppRoutes.root,

      /// ✅ CENTRALIZED ROUTING SYSTEM
      onGenerateRoute: AppRoutes.generateRoute,

      /// 🛡 SAFETY FALLBACK (VERY IMPORTANT)
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(
            child: Text(
              '404 – Page Not Found',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
      },
    );
  }
}
