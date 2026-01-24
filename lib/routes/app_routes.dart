import 'package:flutter/material.dart';

// Admin screens
import '../screens/admin_login_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../auth_wrapper.dart';

// Dashboard sections
import '../screens/dashboard/dashboard_home.dart';

// Requests
import '../screens/requests/leave_requests_screen.dart';
import '../screens/requests/comp_off_requests_screen.dart'; // ✅ Added

// Employees
import '../screens/employees/employees_screen.dart';
import '../screens/employees/employee_details_screen.dart';

// Settings
import '../screens/settings/settings_screen.dart';

// Users
import '../screens/users/pending_users_screen.dart';
import '../screens/settings/academic_years_screen.dart';

class AppRoutes {
  // 🔐 AUTH
  static const String root = '/';
  static const String adminLogin = '/admin-login';

  // 🖥 DASHBOARD
  static const String adminDashboard = '/dashboard';

  // 📊 SECTIONS
  static const String dashboardHome = '/dashboard/home';
  static const String leaveRequests = '/requests'; // Matches Dashboard
  static const String compOffs = '/comp-offs';     // ✅ Matches Dashboard
  static const String employees = '/employees';    // Matches Dashboard
  static const String employeeDetails = '/dashboard/employee-details';
  static const String settings = '/settings';      // Matches Dashboard
  static const String pendingUsers = '/pending-users'; // User approval
  static const String academicYears = '/academic-years'; // Year management

  /// ✅ CENTRAL ROUTE HANDLER
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      // ---------- ROOT (AUTH CHECK) ----------
      case root:
        return MaterialPageRoute(
          builder: (_) => const AuthWrapper(),
        );

      // ---------- AUTH ----------
      case adminLogin:
        return MaterialPageRoute(
          builder: (_) => const AdminLoginScreen(),
        );

      // ---------- DASHBOARD ----------
      case adminDashboard:
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(),
        );

      // ---------- HOME ----------
      case dashboardHome:
        return MaterialPageRoute(
          builder: (_) => const DashboardHome(),
        );

      // ---------- REQUESTS ----------
      case leaveRequests:
        return MaterialPageRoute(builder: (_) => const LeaveRequestsScreen());

      case compOffs: // ✅ Added
        return MaterialPageRoute(builder: (_) => const CompOffRequestsScreen(selectedYear: 'All'));

      // ---------- EMPLOYEES ----------
      case employees:
        return MaterialPageRoute(builder: (_) => const EmployeesScreen());

      case employeeDetails:
        return MaterialPageRoute(builder: (_) => const EmployeesScreen()); // Placeholder

      // ---------- SETTINGS ----------
      case settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );

      // ---------- USER MANAGEMENT ----------
      case pendingUsers:
        return MaterialPageRoute(
          builder: (_) => const PendingUsersScreen(),
        );

      case academicYears:
        return MaterialPageRoute(
          builder: (_) => const AcademicYearsScreen(),
        );

      // ---------- FALLBACK ----------
      default:
        return _errorRoute('404 – Page Not Found');
    }
  }

  /// ❌ ERROR SCREEN
  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text(
            message,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
