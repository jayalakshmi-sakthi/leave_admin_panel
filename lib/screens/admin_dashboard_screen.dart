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
         setState(() => _selectedIndex = 4); // Index for Users/Settings if needed
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
          // Fetch fresh data for detailed view
          final doc = await FirebaseFirestore.instance
              .collection('compOffRequests')
              .doc(_adminDepartment)
              .collection('records')
              .doc(relatedId)
              .get();
          if (doc.exists && mounted) {
            Navigator.pushNamed(
              context,
              AppRoutes.adminCompOffDetails,
              arguments: {'docId': relatedId, 'data': doc.data()!},
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
         FloatingNotification.show(
           context, 
           title: AdminHelpers.sanitizeLabel(data['title'] ?? 'New Notification'),
           body: AdminHelpers.sanitizeLabel(data['body'] ?? ''),
           onTap: () {
             // Handle navigation logic here if needed
           },
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
        final bool isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;

        return Scaffold(
          backgroundColor: AdminHelpers.scaffoldBg, // Light Blue-Grey
          appBar: !isDesktop
              ? AppBar(
                  backgroundColor: AdminHelpers.primaryColor,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: const Text("LeaveX", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              : null,
          drawer: !isDesktop
              ? Drawer(
                  width: 260,
                  child: DarkSidebar(
                    selectedIndex: _selectedIndex,
                    isDesktop: false,
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
                    // 🔍 TOP BAR (Search & Profile)
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
                                 "Hello, ${_isSuperAdmin ? 'Super Admin' : 'Admin'}",
                                 style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AdminHelpers.primaryColor),
                               ),
                               Text(
                                 "Here's what's happening today.",
                                 style: const TextStyle(fontSize: 13, color: AdminHelpers.textMuted),
                               ),
                             ],
                           ),
                           const Spacer(),
                           
                           // Academic Year Dropdown
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             decoration: BoxDecoration(
                               color: AdminHelpers.scaffoldBg,
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: DropdownButtonHideUnderline(
                               child: DropdownButton<String>(
                                 value: _selectedAcademicYear,
                                 icon: const Icon(Icons.arrow_drop_down, color: AdminHelpers.textMuted),
                                 style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AdminHelpers.textMain),
                                 items: _academicYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                                 onChanged: (val) {
                                   if (val != null) setState(() => _selectedAcademicYear = val);
                                 },
                               ),
                             ),
                           ),
                           const SizedBox(width: 16),
                           
                           // Notifications
                           StreamBuilder<int>(
                              stream: NotificationService().getUnreadCount(FirebaseAuth.instance.currentUser?.uid ?? ''),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return Stack(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.notifications_none_rounded, color: AdminHelpers.textMuted, size: 28),
                                      onPressed: () => setState(() => _selectedIndex = 4),
                                    ),
                                    if (count > 0)
                                      Positioned(
                                        right: 8, top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: Text("$count", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ],
                                );
                              }
                           ),
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
        return const AdminNotificationsScreen(); 
      case 5:
        return DepartmentCalendarScreen(); // ✅ Reverted name
      case 6:
        return const SettingsScreen();
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
        // Switch to Wrap/Grid if width is small
        if (constraints.maxWidth < 600) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _statCard(total, "Total", Icons.people_outline, const Color(0xFF3399CC), width: (constraints.maxWidth - 36) / 2),
              _statCard(pending, "Pending", Icons.insert_chart_outlined, const Color(0xFFF59E0B), width: (constraints.maxWidth - 36) / 2),
              _statCard(approved, "Approved", Icons.task_alt, const Color(0xFF8CC63F), width: (constraints.maxWidth - 36) / 2),
              _statCard(rejected, "Rejected", Icons.close_rounded, const Color(0xFFEF4444), width: (constraints.maxWidth - 36) / 2),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _statCard(total, "Total Records", Icons.folder_open_rounded, AdminHelpers.primaryColor)),
             const SizedBox(width: 16),
            Expanded(child: _statCard(pending, "Pending Approval", Icons.hourglass_empty_rounded, const Color(0xFFF59E0B))),
             const SizedBox(width: 16),
            Expanded(child: _statCard(approved, "Approved Requests", Icons.verified_rounded, AdminHelpers.success)),
             const SizedBox(width: 16),
            Expanded(child: _statCard(rejected, "Rejected / Cancelled", Icons.block_flipped, const Color(0xFFEF4444))),
          ],
        );
      }
    );
  }

  Widget _statCard(int value, String label, IconData icon, Color color, {double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
           BoxShadow(
             color: color.withOpacity(0.05), 
             blurRadius: 10, 
             offset: const Offset(0, 4)
           )
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
          Text(value.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: color)),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.withOpacity(0.7), letterSpacing: 0.5)),
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

    final FirestoreService firestoreService = FirestoreService();
    final auth = FirebaseAuth.instance;
    final notificationService = NotificationService(); // ✅ Added

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      shrinkWrap: true, // ✅ Added
      physics: const NeverScrollableScrollPhysics(), // ✅ Added
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final req = filtered[index];
        return _LeaveCard(
          request: req,
          firestoreService: firestoreService, // Pass service
          onUpdateStatus: (status) async {
            await firestoreService.updateLeaveStatus(
              req.id,
              status,
              auth.currentUser?.uid ?? 'admin',
              department: req.department ?? 'CSE',
            );

            // 🔔 SEND NOTIFICATION TO USER
            await notificationService.sendNotification(
              toUserId: req.userId,
              title: 'Leave Request Status Updated',
              body: 'Your ${AdminHelpers.getLeaveName(req.leaveType)} from ${DateFormat('MMM dd').format(req.fromDate)} has been $status.',
              type: 'status_change',
              relatedId: req.id,
            );
          },
        );
      },
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveRequestModel request;
  final Function(String) onUpdateStatus;
  final FirestoreService firestoreService;

  const _LeaveCard({
    required this.request, 
    required this.onUpdateStatus,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    final leaveType = request.leaveType.toString();
    final statusColor = AdminHelpers.getStatusColor(request.status);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<UserModel>(
      stream: firestoreService.getUserStream(request.userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final displayName = user?.name ?? request.userName;
        final displayId = user?.manualEmployeeId ?? user?.employeeId ?? request.employeeId ?? 'N/A';
        final displayPic = user?.profilePicUrl;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1), // Slate 200
          ),
          child: Column(
            children: [
              // 1️⃣ HEADER: Clean & Spacious
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AdminHelpers.getAvatarColor(displayName).withOpacity(0.1),
                      backgroundImage: displayPic != null ? NetworkImage(displayPic) : null,
                      child: displayPic == null
                          ? Text(displayName.isNotEmpty ? displayName[0] : '?',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AdminHelpers.getAvatarColor(displayName)))
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          Text(displayId, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    _statusBadge(request.status),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)), // Subtle Divider

              // 2️⃣ INFO GRID: Clean, no heavy boxes
              // 2️⃣ INFO GRID: Differentiated Sections
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type
                        Expanded(
                          child: Container(
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: const Color(0xFFF8FAFC), // Slate 50
                               borderRadius: BorderRadius.circular(12),
                               border: Border.all(color: const Color(0xFFF1F5F9)),
                             ),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row(children: [
                                   Icon(Icons.category_outlined, size: 14, color: theme.disabledColor),
                                   const SizedBox(width: 6),
                                   Text("LEAVE TYPE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.disabledColor, letterSpacing: 0.5)),
                                 ]),
                                 const SizedBox(height: 8),
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                   decoration: BoxDecoration(
                                     color: AdminHelpers.getLeaveColor(leaveType).withOpacity(0.1),
                                     borderRadius: BorderRadius.circular(6),
                                   ),
                                   child: Text(
                                     AdminHelpers.getLeaveName(leaveType),
                                     style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminHelpers.getLeaveColor(leaveType)),
                                   ),
                                 ),
                               ],
                             ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Duration
                        Expanded(
                          child: Container(
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: const Color(0xFFF8FAFC), // Slate 50
                               borderRadius: BorderRadius.circular(12),
                               border: Border.all(color: const Color(0xFFF1F5F9)),
                             ),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row(children: [
                                   Icon(Icons.timer_outlined, size: 14, color: theme.disabledColor),
                                   const SizedBox(width: 6),
                                   Text("DURATION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.disabledColor, letterSpacing: 0.5)),
                                 ]),
                                 const SizedBox(height: 8),
                                 Text("${request.numberOfDays} Days", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                               ],
                             ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Period
                    Container(
                       width: double.infinity,
                       padding: const EdgeInsets.all(12),
                       decoration: BoxDecoration(
                         color: const Color(0xFFF8FAFC), // Slate 50
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: const Color(0xFFF1F5F9)),
                       ),
                       child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(children: [
                               Icon(Icons.date_range_outlined, size: 14, color: theme.disabledColor),
                               const SizedBox(width: 6),
                               Text("PERIOD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.disabledColor, letterSpacing: 0.5)),
                             ]),
                             const SizedBox(height: 8),
                             Text(
                               "${DateFormat('EEE, MMM dd').format(request.fromDate)}  ➔  ${DateFormat('EEE, MMM dd').format(request.toDate)}",
                               style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                             ),
                          ],
                       ),
                    ),
                  ],
                ),
              ),

              // 3️⃣ ACTIONS
              if (request.status == 'Pending') ...[
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveRequestDetailScreen(request: request)));
                          },
                          icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF64748B)),
                          label: const Text("View Details", style: TextStyle(color: Color(0xFF64748B))),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onUpdateStatus('Rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Color(0xFFFFE4E6)),
                            backgroundColor: const Color(0xFFFEF2F2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                         child: ElevatedButton(
                          onPressed: () => onUpdateStatus('Approved'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminHelpers.primaryColor, // Violet 600
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text("Approve", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                 // If not pending, just show View Details
                 Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8),
                   child: Center(
                     child: TextButton.icon(
                        onPressed: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveRequestDetailScreen(request: request)));
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF7C3AED)),
                        label: const Text("View Full Details", style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
                     ),
                   ),
                 )
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _label(String text) => Text(
    text, 
    style: const TextStyle(
      fontSize: 11, 
      fontWeight: FontWeight.bold, 
      color: Color(0xFF94A3B8), // Slate 400
      letterSpacing: 0.5
    )
  );

  Widget _statusBadge(String status) {
    Color bg;
    Color text;
    switch (status) {
      case 'Approved': bg = const Color(0xFFDCFCE7); text = const Color(0xFF15803D); break;
      case 'Rejected': bg = const Color(0xFFFEE2E2); text = const Color(0xFFB91C1C); break;
      default: bg = const Color(0xFFFEF3C7); text = const Color(0xFFB45309); break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text)),
    );
  }
}


