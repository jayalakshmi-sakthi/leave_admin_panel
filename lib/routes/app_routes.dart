import 'package:flutter/material.dart';

// Admin screens
import '../screens/admin_login_screen.dart';
import '../screens/admin_signup_screen.dart'; // ✅ Added
import '../screens/admin_dashboard_screen.dart';
import '../auth_wrapper.dart';

// Dashboard sections
import '../screens/dashboard/dashboard_home.dart';

// Requests
import '../screens/requests/leave_requests_screen.dart';
import '../screens/requests/comp_off_requests_screen.dart'; // ✅ Added
import '../screens/requests/admin_comp_off_detail_screen.dart';
import '../screens/requests/admin_leave_detail_screen.dart'; // ✅ Restored
// import '../models/leave_request_model.dart'; // 🔴 Removed to fix build

// Employees
import '../screens/employees/employees_screen.dart';
import '../screens/employees/employee_details_screen.dart';
import '../screens/employees/year_employees_screen.dart'; // ✅ Added

// Settings
import '../screens/settings/settings_screen.dart';

// Users
import '../screens/users/pending_users_screen.dart';
import '../screens/settings/academic_years_screen.dart';
import '../screens/notifications/admin_notifications_screen.dart';
import '../screens/settings/department_admins_screen.dart'; // ✅ Added

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(); // ✅ Added for global navigation

  // 🔐 AUTH
  static const String root = '/';
  static const String adminLogin = '/admin-login';
  static const String adminSignup = '/admin-signup'; // ✅ Added

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
  static const String yearEmployees = '/year-employees'; // ✅ Added
  static const String notifications = '/notifications'; 
  static const String leaveRequestDetails = '/requests/detail'; // ✅ Added
  static const String adminCompOffDetails = '/admin/comp-off-details';
  static const String departmentAdmins = '/department-admins'; // ✅ Added

  /// ✅ CENTRAL ROUTE HANDLER
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      // ---------- ROOT (AUTH CHECK) ----------
      case root:
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
      case adminLogin:
        return MaterialPageRoute(builder: (_) => const AdminLoginScreen());
      case adminSignup: // ✅ Added
        return MaterialPageRoute(builder: (_) => const AdminSignupScreen());
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());

      // ---------- HOME ----------
      case dashboardHome:
        return MaterialPageRoute(
          builder: (_) => const DashboardHome(),
        );

      // ---------- REQUESTS ----------
      case leaveRequests:
        return MaterialPageRoute(builder: (_) => const LeaveRequestsScreen());

      case employees:
        return MaterialPageRoute(builder: (_) => const EmployeesScreen());

      case yearEmployees: // ✅ Added
        final yearId = routeSettings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => YearEmployeesScreen(academicYearId: yearId),
        );

      case employeeDetails:
        // Handle Map args (from YearEmployees) or String args (from Legacy)
        final args = routeSettings.arguments;
        String userId = '';
        String? yearId;
        String dept = 'CSE';

        if (args is String) {
          userId = args;
        } else if (args is Map) {
          userId = args['userId'] ?? '';
          yearId = args['yearId'];
          dept = args['adminDepartment'] ?? 'CSE';
        }

        return MaterialPageRoute(
          builder: (_) => EmployeeDetailsScreen(
            userId: userId,
            academicYearId: yearId,
            adminDepartment: dept,
          ),
        );

      // ---------- SETTINGS ----------
      case settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(adminDepartment: 'All'),
        );

      // ---------- USER MANAGEMENT ----------
      case pendingUsers:
        final args = routeSettings.arguments;
        String? dept = (args is Map) ? args['departmentFilter'] : null;
        return MaterialPageRoute(
          builder: (_) => PendingUsersScreen(departmentFilter: dept),
        );

      case academicYears:
        return MaterialPageRoute(
          builder: (_) => const AcademicYearsScreen(),
        );

      case notifications:
        final args = routeSettings.arguments;
        String? dept = (args is Map) ? args['departmentFilter'] : (args is String ? args : null);
        return MaterialPageRoute(
          builder: (_) => AdminNotificationsScreen(departmentFilter: dept),
        );

      case adminCompOffDetails:
        final args = routeSettings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => AdminCompOffDetailScreen(
            docId: args['docId'],
            data: args['data'],
          ),
        );

      case departmentAdmins: // ✅ Added
        return MaterialPageRoute(
          builder: (_) => const DepartmentAdminsScreen(),
        );

      case leaveRequestDetails: // ✅ Added
        final args = routeSettings.arguments;
        // Supports only Map for now to avoid build issues
        if (args is Map) {
             return MaterialPageRoute(
              builder: (_) => LeaveRequestDetailScreen(requestId: args['id']),
            );
        }
        return _errorRoute("Invalid Arguments for Leave Detail");

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
