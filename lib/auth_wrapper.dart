import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/splash_screen.dart'; // ✅ Added

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Waiting for connection or initial state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // 2. State is active, check user
        User? user = snapshot.data;
        
        if (user == null) {
          return const AdminLoginScreen();
        } else {
          return const AdminDashboardScreen();
        }
      },
    );
  }
}
