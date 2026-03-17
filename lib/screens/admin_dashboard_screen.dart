import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added for Deep Linking
import 'package:intl/intl.dart';
import 'dart:async'; // ✅ Added
import '../../models/leave_request_model.dart';
import '../../models/user_model.dart'; // ✅ Added
import '../../services/firestore_service.dart';
import '../routes/app_routes.dart';
import '../utils/admin_helpers.dart'; // ✅ Added
import 'requests/admin_leave_detail_screen.dart'; // ✅ Added
import 'requests/comp_off_requests_screen.dart'; // ✅ Added
import 'requests/admin_comp_off_detail_screen.dart'; // ✅ Added for Deep Linking
import 'employees/employees_screen.dart'; // ✅ Added
import 'settings/settings_screen.dart'; // ✅ Added
import 'notifications/admin_notifications_screen.dart'; // ✅ Added
import 'requests/on_duty_requests_screen.dart'; // ✅ Added
import 'calendar/department_calendar_screen.dart'; // ✅ Added
import '../../services/notification_service.dart';
import '../utils/theme_controller.dart';
import '../widgets/dashboard/dark_sidebar.dart'; // ✅ Added
import '../widgets/dashboard/summary_card.dart'; // ✅ Added
import '../widgets/dashboard/request_list_tile.dart'; // ✅ Added
import '../widgets/floating_notification.dart'; // ✅ Added

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  // 🎨 Sidebar Theme (Premium Blue)
  static const Color sidebarColor = Colors.white;
  static final Color activeBg = AdminHelpers.secondaryColor.withOpacity(0.08); 
  static const Color activeText = AdminHelpers.secondaryColor;
  static final Color inactiveText = AdminHelpers.textMuted;

  String _selectedAcademicYear = 'All';
  List<String> _academicYears = ['All'];
  String _adminDepartment = 'General'; // Default
  String? _adminProfilePic;
  bool _isSuperAdmin = false;
  bool _isLoading = true; // ✅ New: Loading State
  String? _accessError; // ✅ New: Error State
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription? _navSubscription;

  @override
  void initState() {
    super.initState();
    _loadData(); // Load first
    
    // Auth Integration (for Token registration)
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        NotificationService().setUserId(user.uid);
      }
    });
    
    // Initialize Notifications
    final notifService = NotificationService();
    notifService.init();
    
    // 🧭 Unified Navigation Listener (FCM & Local)
    _navSubscription = notifService.navigationStream.listen((data) async {
      if (!mounted) return;
      debugPrint("🧭 Notification Navigation Triggered: $data");
      
      final type = data['type'] as String?;
      final relatedId = data['relatedId'] as String?;
      final leaveType = data['leaveType'] as String? ?? '';
      final academicYearId = data['academicYearId'] as String? ?? '2024-2025';

      // 1. Handle "New User" or Registration notifications
      if (type == 'new_user' || (data['title']?.toString().toLowerCase().contains('registration') ?? false)) {
         setState(() => _selectedIndex = 4); 
         Navigator.pushNamed(context, '/pending-users'); // Adjust route as needed
         return;
      }

      // 2. Determine Sidebar Index based on leave type
      setState(() {
        if (leaveType == 'COMP' || leaveType == 'Comp-Off Earn') {
          _selectedIndex = 3; // Comp-Off
        } else if (leaveType == 'OD' || leaveType == 'On Duty') {
          _selectedIndex = 2; // On-Duty
        } else {
          _selectedIndex = 0; // Dashboard / General Leave
        }
      });

      // 3. Deep Link to Detail Screen
      if (relatedId != null && relatedId.isNotEmpty) {
        if (type == 'leave_request' || (leaveType != 'COMP' && leaveType != 'Comp-Off Earn')) {
          Navigator.pushNamed(
            context,
            AppRoutes.leaveRequestDetails,
            arguments: {'id': relatedId, 'academicYearId': academicYearId},
          );
        } else if (type == 'comp_off_request' || leaveType == 'COMP' || leaveType == 'Comp-Off Earn') {
          // Fetch fresh data for detailed view (using isolated department path)
          final String? targetDept = data['targetDepartment'];
          DocumentSnapshot? doc;

          if (targetDept != null && targetDept.isNotEmpty) {
             doc = await FirebaseFirestore.instance
                 .collection('compOffRequests')
                 .doc(targetDept)
                 .collection('records')
                 .doc(relatedId)
                 .get();
          }

          if (doc == null || !doc.exists) {
             // Search across all groups if path is ambiguous
             final search = await FirebaseFirestore.instance
                  .collectionGroup('records')
                  .where('applicationId', isEqualTo: relatedId)
                  .get();
             if (search.docs.isNotEmpty) doc = search.docs.first;
          }

          if (doc != null && doc.exists && mounted) {
            Navigator.pushNamed(
              context,
              AppRoutes.adminCompOffDetails,
              arguments: {'docId': doc.id, 'data': doc.data()!},
            );
          }
        }
      }
    });
    
    if (FirebaseAuth.instance.currentUser != null) {
       final uid = FirebaseAuth.instance.currentUser!.uid;
       notifService.listenForNewNotifications(uid);
       
        // 🔔 Real-time UI Alerts (Floating)
        notifService.uiNotificationStream.listen((data) {
          if (!mounted) return;
          
          // 🛡️ Filter by Department (Isolation)
          final target = data['targetDepartment']?.toString();
          if (_adminDepartment != 'All' && target != null && target != _adminDepartment) {
            debugPrint("🔇 Muting dashboard alert for $target (Selected: $_adminDepartment)");
            return;
          }

          FloatingNotification.show(
            context,
            title: AdminHelpers.sanitizeLabel(data['title'] ?? 'New Alert'),
            body: AdminHelpers.sanitizeLabel(data['body'] ?? ''),
          );
        });
    }
  }

  @override
  void dispose() {
    _navSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _handleAccessDenied("Not Authenticated");
        return;
      }

      // 1. Load User Profile (CRITICAL: Must exist for Rules to work)
      try {
        final userDoc = await _firestoreService.getUserStream(user.uid).first;
        if (mounted) {
           setState(() {
             if (userDoc.role == 'super_admin') {
               _isSuperAdmin = true;
               _adminDepartment = 'All'; 
             } else {
               _isSuperAdmin = false;
               _adminDepartment = userDoc.department; 
             }
             _adminProfilePic = userDoc.profilePicUrl;
           });
        }
      } catch (e) {
        // 🚨 CRITICAL: User Document Missing or Permission Denied
        _handleAccessDenied("Account Setup Incomplete.\n\nReason: Your admin account exists in Auth but has no profile data.\nError: ${e.toString().contains('permission-denied') ? 'Permission Denied' : 'User profile not found.'}");
        return;
      }

      // 2. Load Academic Years (Dependencies)
      try {
        final years = await _firestoreService.getAcademicYears(department: _adminDepartment);
        final activeYearSettings = await _firestoreService.getAcademicYearSettings(department: _adminDepartment);
        final activeYear = activeYearSettings['label'] as String;

        if (mounted) {
          setState(() {
            final Set<String> uniqueYears = {'All', activeYear, ...years};
            _academicYears = uniqueYears.toList();
            _academicYears.sort((a, b) {
              if (a == 'All') return -1;
              if (b == 'All') return 1;
              return b.compareTo(a);
            });
            if (_selectedAcademicYear == 'All' || _selectedAcademicYear.isEmpty) {
               _selectedAcademicYear = activeYear;
            }
          });
        }
      } catch (e) {
         debugPrint("Error loading academic years: $e");
         // Recoverable, proceed.
      }

      if (mounted) setState(() => _isLoading = false);

    } catch (e) {
      debugPrint("Error loading data: $e");
      _handleAccessDenied("Unexpected Error: $e");
    }
  }

  void _handleAccessDenied(String error) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _accessError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🛑 ACCESS DENIED / ERROR SCREEN
    if (_accessError != null) {
      return Scaffold(
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_rounded, size: 60, color: Colors.amber),
                const SizedBox(height: 24),
                const Text("Access Restricted", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(_accessError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text("Logout & Retry"),
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(backgroundColor:  Colors.redAccent.withOpacity(0.1), foregroundColor: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 12),
                 const Text("Please contact the Super Admin to fix your account permissions.", style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }
    
    // ⏳ LOADING SCREEN
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: AdminHelpers.scaffoldBg, // Light Blue-Grey
          appBar: !isDesktop
              ? AppBar(
                  backgroundColor: AdminHelpers.primaryColor,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const Text("LeaveX", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  actions: [
                     _buildNotificationIcon(),
                     const SizedBox(width: 4),
                     _buildAdminAvatar(),
                     const SizedBox(width: 16),
                  ],
                )
              : null,
          drawer: !isDesktop
              ? Drawer(
                  width: 260,
                  child: DarkSidebar(
                    selectedIndex: _selectedIndex,
                    isDesktop: false,
                    profilePicUrl: _adminProfilePic, // ✅ Added
                    onItemSelected: (index) {
                      if (index == -1) {
                         _logout();
                      } else {
                        setState(() => _selectedIndex = index);
                        Navigator.pop(context);
                      }
                    },
                  ),
                )
              : null,
          body: Row(
            children: [
              // ▐ SIDEBAR (Desktop)
              if (isDesktop)
                DarkSidebar(
                  selectedIndex: _selectedIndex,
                  isDesktop: true,
                  profilePicUrl: _adminProfilePic, // ✅ Added
                  onItemSelected: (index) {
                    if (index == -1) {
                       _logout();
                    } else {
                       setState(() => _selectedIndex = index);
                    }
                  },
                ),

              // 📄 MAIN CONTENT
              Expanded(
                child: Column(
                  children: [
                    // 🔍 TOP BAR (Search & Profile) - Desktop Only
                    if (isDesktop)
                      Container(
                        height: 80,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                        ),
                        child: Row(
                          children: [
                             // User Greeting
                             Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   "Hello, ${_isSuperAdmin ? 'Super Admin' : '$_adminDepartment Admin'}",
                                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminHelpers.primaryColor),
                                 ),
                                 Text(
                                   "Here's what's happening today.",
                                   style: const TextStyle(fontSize: 12, color: AdminHelpers.textMuted),
                                 ),
                               ],
                             ),
                             const Spacer(),
                             
                             // Department Dropdown (Super Admin Only)
                             if (_isSuperAdmin) ...[
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                 decoration: BoxDecoration(
                                   color: AdminHelpers.scaffoldBg,
                                   borderRadius: BorderRadius.circular(10),
                                 ),
                                 child: DropdownButtonHideUnderline(
                                   child: DropdownButton<String>(
                                     value: AdminHelpers.departments.contains(_adminDepartment) ? _adminDepartment : 'All',
                                     icon: const Icon(Icons.business_rounded, color: AdminHelpers.textMuted, size: 18),
                                     style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminHelpers.textMain),
                                     items: AdminHelpers.departments.map((d) {
                                       final color = AdminHelpers.getDeptColor(d);
                                       final icon = AdminHelpers.getDeptIcon(d);
                                       return DropdownMenuItem(
                                         value: d, 
                                         child: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             Container(
                                               padding: const EdgeInsets.all(4),
                                               decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                                               child: Icon(icon, color: color, size: 10),
                                             ),
                                             const SizedBox(width: 8),
                                             Text(d),
                                           ],
                                         )
                                       );
                                     }).toList(),
                                     onChanged: (val) {
                                       if (val != null) setState(() => _adminDepartment = val);
                                     },
                                   ),
                                 ),
                               ),
                               const SizedBox(width: 12),
                             ],
                             
                             // Academic Year Dropdown
                             if (_selectedIndex != 4 && _selectedIndex != 6)
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                 decoration: BoxDecoration(
                                   color: AdminHelpers.scaffoldBg,
                                   borderRadius: BorderRadius.circular(10),
                                 ),
                                 child: DropdownButtonHideUnderline(
                                   child: DropdownButton<String>(
                                     value: _selectedAcademicYear,
                                     icon: const Icon(Icons.arrow_drop_down, color: AdminHelpers.textMuted),
                                     style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminHelpers.textMain),
                                     items: _academicYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                                     onChanged: (val) {
                                       if (val != null) setState(() => _selectedAcademicYear = val);
                                     },
                                   ),
                                 ),
                               ),
                             const SizedBox(width: 20),
                             
                             // Notifications
                             _buildNotificationIcon(),
                             
                             const SizedBox(width: 12),
                             const VerticalDivider(width: 1, indent: 25, endIndent: 25),
                             const SizedBox(width: 12),

                             // Profile Pic
                             _buildAdminAvatar(),
                          ],
                        ),
                      ),
                    
                    // CONTENT BODY
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isDesktop ? 32 : 16),
                        child: _pageWithDependencies(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pageWithDependencies() {
    switch (_selectedIndex) {
      case 0:
        return DashboardContent(selectedYear: _selectedAcademicYear, adminDepartment: _adminDepartment);
      case 1:
        return EmployeesScreen(adminDepartment: _adminDepartment);
      case 2:
        return OnDutyRequestsScreen(selectedYear: _selectedAcademicYear, adminDepartment: _adminDepartment); // ✅ Fixed Index
      case 3:
        return CompOffRequestsScreen(selectedYear: _selectedAcademicYear, adminDepartment: _adminDepartment); // ✅ Fixed Index
      case 4:
        return AdminNotificationsScreen(departmentFilter: _adminDepartment); 
      case 5:
        return DepartmentCalendarScreen(); // ✅ Reverted name
      case 6:
        return SettingsScreen(adminDepartment: _adminDepartment);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.adminLogin,
      (_) => false,
    );
  }

  Widget _buildAdminAvatar() {
    final hasPic = _adminProfilePic != null && _adminProfilePic!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AdminHelpers.primaryColor.withOpacity(0.1), width: 2),
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        backgroundImage: hasPic ? NetworkImage(_adminProfilePic!) : null,
        child: !hasPic 
            ? const Icon(Icons.person_rounded, color: AdminHelpers.primaryColor, size: 20)
            : null,
      ),
    );
  }


  Widget _buildNotificationIcon() {
    return StreamBuilder<int>(
      stream: NotificationService().getUnreadCount(FirebaseAuth.instance.currentUser?.uid ?? ''),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: AdminHelpers.textMuted, size: 26),
              onPressed: () => setState(() => _selectedIndex = 4),
            ),
            if (count > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    "$count", 
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      }
    );
  }
}

// =============================================================================
// 📊 DASHBOARD CONTENT (Requests & Stats)
// =============================================================================

class DashboardContent extends StatefulWidget {
  final String selectedYear;
  final String adminDepartment; // ✅ Added
  const DashboardContent({super.key, required this.selectedYear, required this.adminDepartment});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> with TickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaveRequestModel>>(
      stream: _firestoreService.getLeaveRequestsStream(department: widget.adminDepartment ?? 'CSE', academicYearId: widget.selectedYear),
      builder: (context, snapshot) {
        final allRequests = snapshot.data ?? [];
        // FILTER OUT 'OD' REQUESTS (Handled in separate tab)
        final requests = allRequests.where((r) => r.leaveType != 'OD').toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildStatsRow(requests),
            const SizedBox(height: 24),
            Container(
              decoration: AdminHelpers.cardDecoration(context),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: AdminHelpers.primaryColor,
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorColor: AdminHelpers.secondaryColor,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: "ALL"),
                      Tab(text: "PENDING"),
                      Tab(text: "APPROVED"),
                      Tab(text: "REJECTED"),
                    ],
                  ),
                  // Removed fixed height SizedBox
                  _buildTabContent(requests),
                ],
              ),
            ),
            const SizedBox(height: 40), // Bottom spacer for safe area
          ],
        );
      },
    );
  }

  Widget _buildTabContent(List<LeaveRequestModel> requests) {
    return [
      _RequestsList(requests: requests, year: widget.selectedYear, dept: widget.adminDepartment),
      _RequestsList(requests: requests, filter: 'Pending', year: widget.selectedYear, dept: widget.adminDepartment),
      _RequestsList(requests: requests, filter: 'Approved', year: widget.selectedYear, dept: widget.adminDepartment),
      _RequestsList(requests: requests, filter: 'Rejected', year: widget.selectedYear, dept: widget.adminDepartment),
    ][_tabController.index];
  }

  Widget _buildStatsRow(List<LeaveRequestModel> requests) {
    int total = requests.length;
    int pending = requests.where((r) => r.status == 'Pending').length;
    int approved = requests.where((r) => r.status == 'Approved').length;
    int rejected = requests.where((r) => r.status == 'Rejected').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamic Spacing based on width
        final double spacing = constraints.maxWidth < 600 ? 12 : 24;
        
        if (constraints.maxWidth < 700) {
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              _statCard(total, "Total", Icons.folder_copy_rounded, AdminHelpers.primaryColor, width: (constraints.maxWidth - spacing - 2) / 2),
              _statCard(pending, "Pending", Icons.hourglass_top_rounded, AdminHelpers.warning, width: (constraints.maxWidth - spacing - 2) / 2),
              _statCard(approved, "Approved", Icons.verified_user_rounded, AdminHelpers.success, width: (constraints.maxWidth - spacing - 2) / 2),
              _statCard(rejected, "Rejected", Icons.cancel_presentation_rounded, AdminHelpers.danger, width: (constraints.maxWidth - spacing - 2) / 2),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _statCard(total, "Total Records", Icons.folder_copy_rounded, AdminHelpers.primaryColor)),
             const SizedBox(width: 24),
            Expanded(child: _statCard(pending, "Pending Approval", Icons.hourglass_top_rounded, AdminHelpers.warning)),
             const SizedBox(width: 24),
            Expanded(child: _statCard(approved, "Approved Requests", Icons.verified_user_rounded, AdminHelpers.success)),
             const SizedBox(width: 24),
            Expanded(child: _statCard(rejected, "Rejected / Cancelled", Icons.cancel_presentation_rounded, AdminHelpers.danger)),
          ],
        );
      }
    );
  }

  Widget _statCard(int value, String label, IconData icon, Color color, {double? width}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AdminHelpers.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AdminHelpers.darkBorder : color.withOpacity(0.12), width: 1.5),
        boxShadow: isDark ? [] : [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 20),
          Text(
            value.toString(), 
            style: TextStyle(
              fontSize: 32, 
              fontWeight: FontWeight.w900, 
              letterSpacing: -1.0, 
              color: isDark ? Colors.white : AdminHelpers.textMain
            )
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(), 
            style: TextStyle(
              fontSize: 11, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.grey[400] : AdminHelpers.textMuted, 
              letterSpacing: 0.8
            )
          ),
        ],
      ),
    );
  }
}


class _RequestsList extends StatelessWidget {
  final List<LeaveRequestModel> requests;
  final String? filter;
  final String year;
  final String dept;

  const _RequestsList({required this.requests, this.filter, required this.year, required this.dept});

  @override
  Widget build(BuildContext context) {
    final filtered = filter == null
        ? requests
        : requests.where((r) => r.status == filter).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "No $filter requests found",
              style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold),
            ),
             const SizedBox(height: 8),
            Text(
              "(Filter: Year=$year, Dept=$dept)", 
              style: TextStyle(color: Colors.grey[300], fontSize: 12),
            ),
          ],
        ),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return _buildMobileList(filtered, context, isDark);
        }
        return _buildDesktopTable(filtered, context, isDark, constraints);
      },
    );
  }

  Widget _buildDesktopTable(List<LeaveRequestModel> filtered, BuildContext context, bool isDark, BoxConstraints constraints) {
    final auth = FirebaseAuth.instance;
    final firestoreService = FirestoreService();
    final notificationService = NotificationService();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AdminHelpers.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AdminHelpers.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(isDark ? AdminHelpers.primaryColor.withOpacity(0.8) : const Color(0xFF001C3D)),
              headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              dataRowHeight: 70,
              columnSpacing: (constraints.maxWidth - 640) / 6 > 24 ? (constraints.maxWidth - 640) / 6 : 24,
              horizontalMargin: 20,
              columns: const [
                DataColumn(label: Text("STAFF NAME")),
                DataColumn(label: Text("DATE")),
                DataColumn(label: Text("TYPE")),
                DataColumn(label: Text("DAYS")),
                DataColumn(label: Text("REASON")),
                DataColumn(label: Text("STATUS")),
                DataColumn(label: Text("ACTIONS")),
              ],
              rows: filtered.map((req) {
                final textColor = isDark ? Colors.white : AdminHelpers.textMain;
                final subColor = isDark ? Colors.grey[400] : const Color(0xFF64748B);
                return DataRow(
                  cells: [
                    DataCell(
                      StreamBuilder<UserModel>(
                        stream: firestoreService.getUserStream(req.userId),
                        builder: (context, snapshot) {
                          final profilePic = snapshot.data?.profilePicUrl;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AdminHelpers.getAvatarColor(req.userName).withOpacity(0.1),
                                backgroundImage: profilePic?.isNotEmpty == true ? NetworkImage(profilePic!) : null,
                                child: profilePic?.isNotEmpty == true ? null : Text(req.userName.isNotEmpty ? req.userName[0] : '?',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminHelpers.getAvatarColor(req.userName))),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(req.userName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                                      if (dept == 'All' && req.department != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: AdminHelpers.getDeptColor(req.department!).withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            AdminHelpers.getDeptIcon(req.department!),
                                            size: 10,
                                            color: AdminHelpers.getDeptColor(req.department!),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(req.employeeId ?? 'N/A', style: TextStyle(fontSize: 11, color: subColor)),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.fromDate == req.toDate 
                              ? DateFormat('dd MMM yyyy').format(req.fromDate)
                              : "${DateFormat('dd MMM').format(req.fromDate)} - ${DateFormat('dd MMM yyyy').format(req.toDate)}",
                            style: TextStyle(fontSize: 13, color: textColor)
                          ),
                          if (req.isHalfDay)
                            Text("(${req.halfDaySession})", style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ),
                    DataCell(_typeBadge(req.leaveType)),
                    DataCell(Text("${req.numberOfDays}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor))),
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Text(
                          req.reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: subColor),
                        ),
                      ),
                    ),
                    DataCell(_statusBadge(req.status)),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (req.status == 'Pending') ...[
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Color(0xFF00A389), size: 20),
                              onPressed: () async {
                                final adminId = auth.currentUser?.uid ?? '';
                                await firestoreService.updateLeaveStatus(req.id, 'Approved', adminId, department: dept);
                                notificationService.sendLeaveStatusNotification(
                                  userId: req.userId,
                                  status: 'Approved',
                                  leaveType: req.leaveType,
                                  fromDate: req.fromDate,
                                );
                              },
                              tooltip: 'Approve',
                            ),
                            IconButton(
                              icon: const Icon(Icons.highlight_off_rounded, color: Colors.red, size: 20),
                              onPressed: () async {
                                final adminId = auth.currentUser?.uid ?? '';
                                await firestoreService.updateLeaveStatus(req.id, 'Rejected', adminId, department: dept);
                                notificationService.sendLeaveStatusNotification(
                                  userId: req.userId,
                                  status: 'Rejected',
                                  leaveType: req.leaveType,
                                  fromDate: req.fromDate,
                                );
                              },
                              tooltip: 'Reject',
                            ),
                          ],
                          IconButton(
                            icon: Icon(Icons.visibility_outlined, color: isDark ? Colors.blue[300] : const Color(0xFF001C3D), size: 20),
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.leaveRequestDetails,
                              arguments: {'id': req.id, 'academicYearId': year},
                            ),
                            tooltip: 'View Details',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<LeaveRequestModel> filtered, BuildContext context, bool isDark) {
    final firestoreService = FirestoreService();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final req = filtered[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? AdminHelpers.darkBorder : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    StreamBuilder<UserModel>(
                      stream: firestoreService.getUserStream(req.userId),
                      builder: (context, snapshot) {
                        final profilePic = snapshot.data?.profilePicUrl;
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: AdminHelpers.getAvatarColor(req.userName).withOpacity(0.1),
                          backgroundImage: profilePic?.isNotEmpty == true ? NetworkImage(profilePic!) : null,
                          child: profilePic?.isNotEmpty == true ? null : Text(req.userName.isNotEmpty ? req.userName[0] : '?',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AdminHelpers.getAvatarColor(req.userName))),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("${req.leaveType} • ${req.numberOfDays} Days", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    _statusBadge(req.status),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("PERIOD", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text(
                          req.fromDate == req.toDate 
                            ? DateFormat('dd MMM yyyy').format(req.fromDate)
                            : "${DateFormat('dd MMM').format(req.fromDate)} - ${DateFormat('dd MMM yyyy').format(req.toDate)}",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.leaveRequestDetails,
                        arguments: {'id': req.id, 'academicYearId': year},
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text("View"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(String status) {
    final color = AdminHelpers.getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _typeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        type,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
      ),
    );
  }
}
