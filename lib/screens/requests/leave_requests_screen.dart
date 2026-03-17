import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:shimmer/shimmer.dart'; 
import '../../models/leave_request_model.dart';
import '../../models/user_model.dart'; // ✅ Added
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import 'admin_leave_detail_screen.dart';
import '../../utils/admin_helpers.dart';
import '../../widgets/responsive_container.dart';

/// ==================================================
/// 🎨 GLOBAL THEME CONSTANTS
/// ==================================================
const Color kPrimaryBlue = Color(0xFF2563EB);
const Color kScaffoldBg = Color(0xFFF8FAFC);
const Color kTextDark = Color(0xFF0F172A);
const Color kTextMuted = Color(0xFF64748B);

/// ==================================================
/// 📄 LEAVE REQUESTS SCREEN (ADMIN)
/// ==================================================
class LeaveRequestsScreen extends StatefulWidget {
  final String? adminDepartment; // ✅ Added
  const LeaveRequestsScreen({super.key, this.adminDepartment});

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  // --------------------------------------------------
  // 🖥 UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Resolve Department (Constructor > Route Args > Null)
    String? effectiveDepartment = widget.adminDepartment;
    if (effectiveDepartment == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        effectiveDepartment = args;
      } else if (args is Map<String, dynamic>) {
        effectiveDepartment = args['department'] as String?;
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: theme.appBarTheme.iconTheme,
        title: Text(
          "Leave Requests",
          style: TextStyle(color: theme.appBarTheme.foregroundColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.appBarTheme.foregroundColor),
            onPressed: () {
              setState(() {}); // Rebuilds the stream
            },
            tooltip: "Refresh List",
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.disabledColor,
          tabs: const [
            Tab(text: "ALL"),
            Tab(text: "PENDING"),
            Tab(text: "APPROVED"),
            Tab(text: "REJECTED"),
          ],
        ),
      ),
      body: ResponsiveContainer(
        child: TabBarView(
          controller: _tabController,
          children: [
            _RequestsTab(adminDepartment: effectiveDepartment),
            _RequestsTab(filter: 'Pending', adminDepartment: effectiveDepartment),
            _RequestsTab(filter: 'Approved', adminDepartment: effectiveDepartment),
            _RequestsTab(filter: 'Rejected', adminDepartment: effectiveDepartment),
          ],
        ),
      ),
    );
  }
}

/// ==================================================
/// 📄 REQUESTS TAB (REAL-TIME)
/// ==================================================
class _RequestsTab extends StatelessWidget {
  final String? filter;
  final String? adminDepartment; // ✅ Added

  const _RequestsTab({this.filter, this.adminDepartment});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final auth = FirebaseAuth.instance;
    final theme = Theme.of(context);

    // Filter Logic:
    // If adminDepartment == 'All' or null -> Show All (Super Admin behavior)
    // If adminDepartment == 'CSE' -> Show Only CSE
    
    return StreamBuilder<List<LeaveRequestModel>>(
      stream: firestoreService.getLeaveRequestsStream(
        statusFilter: filter, 
        department: adminDepartment ?? 'CSE',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonList(context);
        }

        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
          ));
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 64, color: theme.disabledColor),
                const SizedBox(height: 16),
                Text("No $filter requests found", style: TextStyle(color: theme.disabledColor, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            return _LeaveRequestCard(
              request: requests[index],
              adminId: auth.currentUser?.uid ?? 'admin',
              onUpdateStatus: (status) async {
                await firestoreService.updateLeaveStatus(
                  requests[index].id,
                  status,
                  auth.currentUser?.uid ?? 'admin',
                  department: requests[index].department ?? 'CSE',
                );

                // ✅ Send Notification to User
                try {
                  await NotificationService().sendNotification(
                    toUserId: requests[index].userId,
                    title: 'Leave Request $status',
                    body: 'Your ${requests[index].leaveType} request for ${AdminHelpers.formatDate(requests[index].fromDate)} has been $status.',
                    type: 'status_change',
                    relatedId: requests[index].id,
                    leaveType: requests[index].leaveType,
                    academicYearId: requests[index].academicYearId,
                  );
                } catch (e) {
                  debugPrint("Notification Error: $e");
                }
                
                // Show snackbar
                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Leave $status successfully"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSkeletonList(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 200,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// ==================================================
/// 🧾 LEAVE REQUEST CARD (PREMIUM UI)
/// ==================================================
class _LeaveRequestCard extends StatelessWidget {
  final LeaveRequestModel request;
  final String adminId;
  final Function(String) onUpdateStatus;

  const _LeaveRequestCard({
    required this.request,
    required this.adminId,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color statusColor = AdminHelpers.getStatusColor(request.status);
    final String leaveType = request.leaveType.toString();

    // 🌟 Directional Logic
    final bool isApproved = request.status == 'Approved';
    final MainAxisAlignment alignment = isApproved ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Row(
      mainAxisAlignment: alignment,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), // Prevent full-width stretch
          child: Container(
            width: MediaQuery.of(context).size.width > 900 ? 500 : MediaQuery.of(context).size.width * 0.85,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isApproved ? Colors.green.withOpacity(0.3) : theme.dividerColor.withOpacity(0.6), 
                width: 1 // Keep it subtle
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🌟 LIVE USER DATA FETCH
                    StreamBuilder<UserModel>(
                      stream: FirestoreService().getUserStream(request.userId),
                      builder: (context, userSnap) {
                        final user = userSnap.data;
                        final String displayName = user?.name ?? request.userName;
                        final String displayId = user?.manualEmployeeId ?? user?.employeeId ?? request.employeeId ?? 'N/A';
                        final String? profilePic = user?.profilePicUrl;

                        return Row(
                          children: [
                            // 🖼️ AVATAR
                            Container(
                                margin: const EdgeInsets.only(right: 12.0),
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                child: CircleAvatar(
                                radius: 22,
                                backgroundColor: AdminHelpers.primaryColor.withOpacity(0.1),
                                backgroundImage: profilePic != null && profilePic.isNotEmpty
                                    ? NetworkImage(profilePic)
                                    : null,
                                child: profilePic == null 
                                    ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AdminHelpers.primaryColor))
                                    : null,
                              ),
                            ),
                            
                            // 📄 TEXT INFO
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textTheme.titleLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.dividerColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    displayId,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.textTheme.bodyMedium?.color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    ),
                    // 🏷 Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        request.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 🔖 Leave Type (Neutral)
                Row(
                  children: [
                    Text(
                      AdminHelpers.getLeaveName(leaveType),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if(request.isHalfDay)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text("HALF DAY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // 📅 Dates
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: theme.primaryColor),
                      const SizedBox(width: 10),
                      Text(
                        "${AdminHelpers.formatDate(request.fromDate)}  ➔  ${AdminHelpers.formatDate(request.toDate)}",
                        style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      Container(width: 1, height: 16, color: theme.dividerColor),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time_rounded, size: 16, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        "${request.numberOfDays} Days",
                        style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 📎 Attachment & Details
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Initial Attachment (e.g. Med Cert)
                    if (request.signedFormUrl != null && request.signedFormUrl!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () async {
                            final uri = Uri.parse(request.signedFormUrl!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                        },
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text("Proof"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminHelpers.primaryColor,
                          side: BorderSide(color: AdminHelpers.primaryColor.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                    // Signed Copy (Post-Approval)
                    if (request.finalSignedFormUrl != null && request.finalSignedFormUrl!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () async {
                            final uri = Uri.parse(request.finalSignedFormUrl!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                        },
                        icon: const Icon(Icons.verified_rounded, size: 18),
                        label: const Text("Signed Copy"),
                         style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal,
                          side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                          backgroundColor: Colors.teal.withOpacity(0.05),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    
                    OutlinedButton.icon(
                      onPressed: () {
                        _showRequestDetails(context, request);
                      },
                      icon: Icon(Icons.visibility_rounded, size: 18, color: theme.textTheme.bodyLarge?.color),
                      label: Text("View Details", style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.dividerColor),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),

                // ✅ Actions (Approve/Reject)
                if (request.status == 'Pending') ...[
                  const SizedBox(height: 20),
                  Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                       Expanded(
                         child: OutlinedButton(
                          onPressed: () => onUpdateStatus('Rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red.withOpacity(0.2)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                       ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => onUpdateStatus('Approved'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminHelpers.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Approve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showRequestDetails(BuildContext context, LeaveRequestModel request) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: theme.cardColor,
        title: Text("Application Form Details", style: TextStyle(color: theme.textTheme.titleLarge?.color)),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(context, "Applicant Name", request.userName),
              _detailRow(context, "Employee ID", request.employeeId ?? "N/A"),
              _detailRow(context, "Leave Type", AdminHelpers.getLeaveName(request.leaveType)),
              _detailRow(context, "From Date", AdminHelpers.formatDate(request.fromDate)),
              _detailRow(context, "To Date", AdminHelpers.formatDate(request.toDate)),
              _detailRow(context, "No. of Days", request.numberOfDays.toString()),
              if(request.isHalfDay) _detailRow(context, "Session", request.halfDaySession ?? "-"),
              const SizedBox(height: 12),
              Text("Reason:", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              Text(request.reason, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              "$label:",
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
            ),
          ),
        ],
      ),
    );
  }
}
