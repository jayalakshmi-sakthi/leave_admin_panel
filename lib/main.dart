import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'routes/app_routes.dart';

/// ------------------------------------------------------------
/// 🚀 APPLICATION ENTRY POINT
/// ------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// 🔥 Initialize Firebase (Admin App)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const LeaveAdminApp());
}

/// ------------------------------------------------------------
/// 🖥 LEAVEX – ADMIN APPLICATION
/// ------------------------------------------------------------
class LeaveAdminApp extends StatelessWidget {
  const LeaveAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeaveX Admin Panel',
      debugShowCheckedModeBanner: false,

      /// 🎨 ADMIN THEME
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // Premium Blue
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFF2563EB),
          foregroundColor: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),

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
  }
}
