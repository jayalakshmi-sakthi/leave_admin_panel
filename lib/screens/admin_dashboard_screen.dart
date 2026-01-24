import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/leave_request_model.dart';
import '../../services/firestore_service.dart';
import '../routes/app_routes.dart';
import 'requests/admin_leave_detail_screen.dart'; // ✅ Added
import 'requests/comp_off_requests_screen.dart'; // ✅ Added
import 'employees/employees_screen.dart';
import 'settings/settings_screen.dart';
import '../utils/admin_helpers.dart';
import '../../services/notification_service.dart'; // ✅ Added


class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  // 🎨 Sidebar Theme (Able Pro Inspired - Light Sidebar)
  // 🎨 Soulful Colors
  static const Color primaryBlue = Color(0xFF2563EB); // Deep Blue
  static const Color sidebarColor = Colors.white;
  static const Color activeBg = Color(0xFFDCEEFB); // Soft Blue tint
  static const Color activeText = Color(0xFF2563EB);
  static const Color inactiveText = Color(0xFF64748B);
  static const Color indicatorColor = Color(0xFF10B981); // Soulful Emerald
  static const Color scaffoldBg = Color(0xFFF8FAFC); // Slate 50

  final List<Widget> _pages = [
    const SizedBox.shrink(), // DashboardContent Placeholder
    const EmployeesScreen(),
    const SizedBox.shrink(), // CompOffRequestsScreen Placeholder
    const SettingsScreen(),
  ];

  String _selectedAcademicYear = 'All';
  List<String> _academicYears = ['All'];
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  Future<void> _loadYears() async {
    final years = await _firestoreService.getAcademicYears();
    if (mounted) {
      setState(() {
        _academicYears = ['All', ...years];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Row(
        children: [
          // --------------------------
          // ▐ SIDEBAR
          // --------------------------
          Container(
            width: 250,
            color: sidebarColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  // 🏛️ Placement-Focused Header Logo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      children: [
                        _LeaveXLogo(),
                        SizedBox(width: 12),
                        Text(
                          "LeaveX",
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 👤 USER PROFILE SECTION
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: activeBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                          ),
                          child: const Icon(Icons.business_center_rounded, color: Color(0xFF3399CC), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Placement Cell", 
                                style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 13)),
                              Text("Official Administrator", 
                                style: TextStyle(color: inactiveText, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.only(left: 24, top: 32, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("NAVIGATION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                    ),
                  ),

                  // 🧭 Navigation Items
                  _buildNavItem(0, "Dashboard", Icons.dashboard_outlined),
                  _buildNavItem(1, "Employees", Icons.people_outline),
                  _buildNavItem(2, "Comp-Off Grants", Icons.stars_outlined),
                  _buildNavItem(3, "Settings", Icons.settings_outlined),

                  const SizedBox(height: 32),
                  const Divider(indent: 20, endIndent: 20, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // 🚪 Logout Area
                  _buildNavItem(-1, "Logout", Icons.logout, isLogout: true),
                  const SizedBox(height: 40), // Extra padding at bottom
                ],
              ),
            ),
          ),

          // --------------------------
          // 📄 MAIN CONTENT AREA
          // --------------------------
          Expanded(
            child: Column(
              children: [
                // 🔍 TOP BAR
                Container(
                  height: 70,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_rounded, color: Color(0xFF64748B)),
                      const SizedBox(width: 24),
                      // 📅 Academic Year Dropdown relocated to Top Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: scaffoldBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF3399CC).withOpacity(0.2)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedAcademicYear,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                            items: _academicYears.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedAcademicYear = val);
                            },
                          ),
                        ),
                      ),
                      const Spacer(),
                      const CircleAvatar(radius: 16, backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=admin')),
                    ],
                  ),
                ),
                Expanded(
                  child: _pageWithDependencies(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageWithDependencies() {
    switch (_selectedIndex) {
      case 0:
        return DashboardContent(selectedYear: _selectedAcademicYear);
      case 1:
        return const EmployeesScreen();
      case 2:
        return CompOffRequestsScreen(selectedYear: _selectedAcademicYear);
      case 3:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }


  Widget _buildNavItem(int index, String title, IconData icon, {bool isLogout = false}) {
    final bool isActive = _selectedIndex == index;

    return InkWell(
      onTap: () => isLogout ? _logout() : setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isLogout 
              ? Colors.redAccent.withOpacity(0.08) 
              : (isActive ? activeBg : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: isLogout 
              ? Border.all(color: Colors.redAccent.withOpacity(0.15), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isLogout ? Colors.redAccent : (isActive ? activeText : inactiveText),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isLogout ? Colors.redAccent : (isActive ? activeText : inactiveText),
                fontSize: 13,
                fontWeight: isActive || isLogout ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
  const DashboardContent({super.key, required this.selectedYear});

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaveRequestModel>>(
      stream: _firestoreService.getLeaveRequestsStream(academicYearId: widget.selectedYear),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildStatsRow(requests),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF3399CC),
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorColor: const Color(0xFF8CC63F),
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: "ALL"),
                      Tab(text: "PENDING"),
                      Tab(text: "APPROVED"),
                      Tab(text: "REJECTED"),
                    ],
                  ),
                  SizedBox(
                    height: 800,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _RequestsList(requests: requests),
                        _RequestsList(requests: requests, filter: 'Pending'),
                        _RequestsList(requests: requests, filter: 'Approved'),
                        _RequestsList(requests: requests, filter: 'Rejected'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsRow(List<LeaveRequestModel> requests) {
    int total = requests.length;
    int pending = requests.where((r) => r.status == 'Pending').length;
    int approved = requests.where((r) => r.status == 'Approved').length;
    int rejected = requests.where((r) => r.status == 'Rejected').length;

    return Row(
      children: [
        _statCard("Total", total, Icons.people_outline, const Color(0xFF3399CC)),
        _statCard("Pending", pending, Icons.insert_chart_outlined, const Color(0xFFF59E0B)),
        _statCard("Approved", approved, Icons.task_alt, const Color(0xFF8CC63F)),
        _statCard("Rejected", rejected, Icons.close_rounded, const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(value.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}


class _RequestsList extends StatelessWidget {
  final List<LeaveRequestModel> requests;
  final String? filter;

  const _RequestsList({required this.requests, this.filter});

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
            Text("No $filter requests", style: TextStyle(color: Colors.grey[400])),
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
          onUpdateStatus: (status) async {
            await firestoreService.updateLeaveStatus(
              req.id,
              status,
              auth.currentUser?.uid ?? 'admin',
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

  const _LeaveCard({required this.request, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    final leaveType = request.leaveType.toString();
    final statusColor = AdminHelpers.getStatusColor(request.status);
    IconData statusIcon;

    switch (request.status.toLowerCase()) {
      case 'approved':
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusIcon = Icons.access_time;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 📅 Date Indicator (Neutral)
              Container(
                width: 6,
                color: const Color(0xFFE2E8F0),
              ),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // 🖼️ Avatar/Initial Circle (Neutral)
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFF1F5F9),
                        child: Text(
                          request.userName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // 📝 Details Sub-Grid
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              request.userName.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "ID: ${request.employeeId ?? 'N/A'}",
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Leave Type (Neutral Text)
                                Text(
                                  AdminHelpers.getLeaveName(leaveType),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Status Badge (ONLY colored element)
                                _badge(request.status.toUpperCase(), statusColor),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 🗓️ Duration Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                             Text(
                              "${request.numberOfDays} DAYS",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${DateFormat('MMM dd').format(request.fromDate)} - ${DateFormat('MMM dd').format(request.toDate)}",
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                      // ⚡ Actions
                      if (request.status == 'Pending') ...[
                        Row(
                          children: [
                             IconButton.filled(
                               onPressed: () => onUpdateStatus('Approved'),
                               icon: const Icon(Icons.check, size: 20),
                               style: IconButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                             ),
                             const SizedBox(width: 8),
                             IconButton.outlined(
                               onPressed: () => onUpdateStatus('Rejected'),
                               icon: const Icon(Icons.close, size: 20),
                               style: IconButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFEF4444))),
                             ),
                          ],
                        ),
                      ] else ...[
                        Icon(statusIcon, color: statusColor.withOpacity(0.5), size: 32),
                      ],
                      
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LeaveRequestDetailScreen(request: request),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// 🏛️ UNIQUE PLACEMENT-FOCUSED LOGO (PRECISION CALENDAR)
class _LeaveXLogo extends StatelessWidget {
  const _LeaveXLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 📅 Calendar Body
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
          ),
          // 🔵 Top Header of Calendar
          Positioned(
            top: 2,
            child: Container(
              width: 34,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF0EA5E9), // Sky Blue
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
            ),
          ),
          // ⏱️ Precision Clock Accent
          Positioned(
            bottom: 2,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF8CC63F), // Original Light Green
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8CC63F).withOpacity(0.3),
                    blurRadius: 6,
                  )
                ],
              ),
              child: Center(
                child: Container(
                  width: 1.5,
                  height: 8,
                  color: Colors.white,
                  transform: Matrix4.rotationZ(0.5),
                ),
              ),
            ),
          ),
          // Calendar Grid Dots
          Positioned(
            top: 18,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(3, (i) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), shape: BoxShape.circle),
                  )),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(2, (i) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), shape: BoxShape.circle),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
