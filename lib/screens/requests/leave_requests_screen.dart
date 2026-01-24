import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ Added
import '../../models/leave_request_model.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import 'admin_leave_detail_screen.dart';
import '../../utils/admin_helpers.dart';

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
  const LeaveRequestsScreen({super.key});

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
    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: AppBar(
        backgroundColor: kPrimaryBlue,
        title: const Text(
          "Leave Requests",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() {}); // Rebuilds the stream
            },
            tooltip: "Refresh List",
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "ALL"),
            Tab(text: "PENDING"),
            Tab(text: "APPROVED"),
            Tab(text: "REJECTED"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _RequestsTab(),
          _RequestsTab(filter: 'Pending'),
          _RequestsTab(filter: 'Approved'),
          _RequestsTab(filter: 'Rejected'),
        ],
      ),
    );
  }
}

/// ==================================================
/// 📄 REQUESTS TAB (REAL-TIME)
/// ==================================================
class _RequestsTab extends StatelessWidget {
  final String? filter;
  const _RequestsTab({this.filter});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final auth = FirebaseAuth.instance;

    return StreamBuilder<List<LeaveRequestModel>>(
      stream: firestoreService.getLeaveRequestsStream(statusFilter: filter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Text("No leave requests found"),
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
                );

                // ✅ Send Notification to User
                try {
                  await NotificationService().sendNotification(
                    toUserId: requests[index].userId,
                    title: 'Leave Request $status',
                    body: 'Your leave request for ${AdminHelpers.formatDate(requests[index].fromDate)} has been $status.',
                    type: 'status_change',
                    relatedId: requests[index].id,
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
}

/// ==================================================
/// 🧾 LEAVE REQUEST CARD (PREMIUM UI)
/// ==================================================
class _LeaveRequestCard extends StatelessWidget {
  final LeaveRequestModel request;
  final String adminId;
  final Function(String) onUpdateStatus;

  // Constructor - intentionally removed 'const' to avoid any inferred const issues 
  // with children, although with proper params it technically could be. 
  // Safety first!
  const _LeaveRequestCard({
    required this.request,
    required this.adminId,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = AdminHelpers.getStatusColor(request.status);
    final String leaveType = request.leaveType.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
       // Removed const from here to be safe, though not strictly wrong if params are const
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 👤 User Name
                  Text(
                    request.userName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 🆔 Employee ID
                  Text(
                    "ID: ${request.employeeId ?? 'N/A'}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: kTextMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // 🏷 Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),

          // 🔖 Leave Type (Neutral)
          Text(
            AdminHelpers.getLeaveName(leaveType),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 6),

          // 📅 Dates
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: kTextMuted),
              const SizedBox(width: 6),
              Text(
                "${AdminHelpers.formatDate(request.fromDate)} → ${AdminHelpers.formatDate(request.toDate)}",
                style: const TextStyle(color: kTextMuted, fontSize: 13),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // 📊 Days
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: kTextMuted),
              const SizedBox(width: 6),
              Text(
                request.isHalfDay
                    ? "${request.numberOfDays} Days (${request.halfDaySession == 'FN' ? 'Forenoon' : 'Afternoon'})"
                    : "${request.numberOfDays} Days",
                style: const TextStyle(color: kTextMuted, fontSize: 13),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 📎 Attachment & Details
          Row(
            children: [
              // Initial Attachment (e.g. Med Cert)
              if (request.signedFormUrl != null && request.signedFormUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(request.signedFormUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(Icons.attachment_rounded, size: 18),
                    label: const Text("View Attachment"),
                    style: TextButton.styleFrom(foregroundColor: kPrimaryBlue),
                  ),
                ),

              // Signed Copy (Post-Approval)
              if (request.finalSignedFormUrl != null && request.finalSignedFormUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(request.finalSignedFormUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(Icons.verified_user_rounded, size: 18),
                    label: const Text("View Signed Copy"),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.green, // Distinct color
                        backgroundColor: Colors.green.withOpacity(0.05)),
                  ),
                ),
              
              TextButton.icon(
                onPressed: () {
                  _showRequestDetails(context, request);
                },
                icon: const Icon(Icons.visibility_rounded, size: 18),
                label: const Text("Details"),
                style: TextButton.styleFrom(foregroundColor: kTextDark),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ Actions (Approve/Reject)
          if (request.status == 'Pending') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => onUpdateStatus('Rejected'),
                  child: const Text("Reject", style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => onUpdateStatus('Approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Approve", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showRequestDetails(BuildContext context, LeaveRequestModel request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Application Form Details"),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow("Applicant Name", request.userName),
              _detailRow("Employee ID", request.employeeId ?? "N/A"),
              _detailRow("Leave Type", AdminHelpers.getLeaveName(request.leaveType)),
              _detailRow("From Date", AdminHelpers.formatDate(request.fromDate)),
              _detailRow("To Date", AdminHelpers.formatDate(request.toDate)),
              _detailRow("No. of Days", request.numberOfDays.toString()),
              if(request.isHalfDay) _detailRow("Session", request.halfDaySession ?? "-"),
              const SizedBox(height: 12),
              const Text("Reason:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(request.reason, style: const TextStyle(fontSize: 14)),
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold, color: kTextMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, color: kTextDark),
            ),
          ),
        ],
      ),
    );
  }
}
