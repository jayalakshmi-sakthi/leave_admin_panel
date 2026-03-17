import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/leave_request_model.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import 'admin_leave_detail_screen.dart';
import '../../utils/admin_helpers.dart';
import '../../widgets/responsive_container.dart';

class OnDutyRequestsScreen extends StatefulWidget {
  final String selectedYear;
  final String? adminDepartment; // ✅ Added
  const OnDutyRequestsScreen({super.key, required this.selectedYear, this.adminDepartment});

  @override
  State<OnDutyRequestsScreen> createState() => _OnDutyRequestsScreenState();
}

class _OnDutyRequestsScreenState extends State<OnDutyRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Match Dashboard (ALL, PENDING, APPROVED, REJECTED)
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
      stream: _firestoreService.getLeaveRequestsStream(
        academicYearId: widget.selectedYear, 
        department: widget.adminDepartment ?? 'CSE',
      ),
      builder: (context, snapshot) {
        final allRequests = snapshot.data ?? [];
        // FILTER FOR 'OD' ONLY
        final odRequests = allRequests.where((r) => r.leaveType == 'OD').toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildStatsRow(odRequests),
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
                  _buildTabContent(odRequests),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildTabContent(List<LeaveRequestModel> requests) {
    return [
      _ODList(requests: requests),
      _ODList(requests: requests, filter: 'Pending'),
      _ODList(requests: requests, filter: 'Approved'),
      _ODList(requests: requests, filter: 'Rejected'),
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
              _statCard(total, "Total OD", Icons.business_center_rounded, AdminHelpers.primaryColor, width: (constraints.maxWidth - spacing - 2) / 2),
              _statCard(pending, "Pending", Icons.hourglass_top_rounded, AdminHelpers.warning, width: (constraints.maxWidth - spacing - 2) / 2),
              _statCard(approved, "Approved", Icons.verified_user_rounded, AdminHelpers.success, width: (constraints.maxWidth - spacing - 2) / 2),
              _statCard(rejected, "Rejected", Icons.cancel_presentation_rounded, AdminHelpers.danger, width: (constraints.maxWidth - spacing - 2) / 2),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _statCard(total, "Total OD", Icons.business_center_rounded, AdminHelpers.primaryColor)),
             const SizedBox(width: 24),
            Expanded(child: _statCard(pending, "Pending", Icons.hourglass_top_rounded, AdminHelpers.warning)),
             const SizedBox(width: 24),
            Expanded(child: _statCard(approved, "Approved", Icons.verified_user_rounded, AdminHelpers.success)),
             const SizedBox(width: 24),
            Expanded(child: _statCard(rejected, "Rejected", Icons.cancel_presentation_rounded, AdminHelpers.danger)),
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

class _ODList extends StatelessWidget {
  final List<LeaveRequestModel> requests;
  final String? filter;
  const _ODList({required this.requests, this.filter});

  @override
  Widget build(BuildContext context) {
    final filtered = filter == null
        ? requests
        : requests.where((r) => r.status == filter).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(48.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text("No On-Duty requests found", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _OnDutyCard(request: filtered[index]);
            },
          );
        }

        // Desktop Table View
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 48),
              child: DataTable(
                headingRowHeight: 56,
                dataRowHeight: 72,
                columnSpacing: (constraints.maxWidth - 580) / 5 > 24 ? (constraints.maxWidth - 580) / 5 : 24,
                horizontalMargin: 20,
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13),
                columns: const [
                  DataColumn(label: Text("STAFF NAME")),
                  DataColumn(label: Text("DATE")),
                  DataColumn(label: Text("DAYS")),
                  DataColumn(label: Text("REASON")),
                  DataColumn(label: Text("STATUS")),
                  DataColumn(label: Text("ACTIONS")),
                ],
                rows: filtered.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AdminHelpers.getAvatarColor(r.userName).withOpacity(0.12),
                              child: Text(r.userName.isNotEmpty ? r.userName[0] : '?', style: TextStyle(color: AdminHelpers.getAvatarColor(r.userName), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.userName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                Text(r.employeeId ?? 'N/A', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(
                        r.fromDate == r.toDate 
                          ? DateFormat('dd MMM yyyy').format(r.fromDate)
                          : "${DateFormat('dd MMM').format(r.fromDate)} - ${DateFormat('dd MMM yyyy').format(r.toDate)}",
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      )),
                      DataCell(Text("${r.numberOfDays}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)))),
                      DataCell(SizedBox(width: 150, child: Text(r.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))))),
                      DataCell(_statusBadge(r.status)),
                      DataCell(Row(
                        children: [
                          if (r.status == 'Pending') ...[
                             _ActionButton(
                              label: "Approve",
                              color: AdminHelpers.primaryColor,
                              icon: Icons.check_circle_outline,
                              request: r,
                              newStatus: 'Approved',
                            ),
                            const SizedBox(width: 8),
                            _ActionButton(
                              label: "Reject",
                              color: Colors.red,
                              icon: Icons.cancel_outlined,
                              request: r,
                              newStatus: 'Rejected',
                            ),
                          ] else ...[
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => LeaveRequestDetailScreen(requestId: r.id)),
                                );
                              },
                              icon: const Icon(Icons.visibility_rounded, size: 16),
                              label: const Text("View Details", style: TextStyle(fontSize: 12)),
                            )
                          ],
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text)),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final IconData icon;
  final LeaveRequestModel request;
  final String newStatus;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.request,
    required this.newStatus,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _loading = false;

  Future<void> _update() async {
    setState(() => _loading = true);
    try {
      final fire = FirestoreService();
      final auth = FirebaseAuth.instance;
      
      await fire.updateLeaveStatus(
        widget.request.id,
        widget.newStatus,
        auth.currentUser?.uid ?? 'admin',
        department: widget.request.department ?? 'CSE',
      );

       await NotificationService().sendNotification(
          toUserId: widget.request.userId,
          title: 'On-Duty Request ${widget.newStatus}',
          body: 'Your On-Duty request for ${AdminHelpers.formatDate(widget.request.fromDate)} has been ${widget.newStatus}.',
          type: 'status_change',
          relatedId: widget.request.id,
        );
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request ${widget.newStatus}"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading 
      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
      : InkWell(
          onTap: _update,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: widget.color.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 14, color: widget.color),
                const SizedBox(width: 6),
                Text(widget.label, style: TextStyle(color: widget.color, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
  }
}



class _OnDutyCard extends StatefulWidget {
  final LeaveRequestModel request;
  const _OnDutyCard({required this.request});

  @override
  State<_OnDutyCard> createState() => _OnDutyCardState();
}

class _OnDutyCardState extends State<_OnDutyCard> {
  bool _loading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);
    try {
      final fire = FirestoreService();
      final auth = FirebaseAuth.instance;
      
      await fire.updateLeaveStatus(
        widget.request.id,
        status,
        auth.currentUser?.uid ?? 'admin',
        department: widget.request.department ?? 'CSE',
      );

       await NotificationService().sendNotification(
          toUserId: widget.request.userId,
          title: 'On-Duty Request $status',
          body: 'Your On-Duty request for ${AdminHelpers.formatDate(widget.request.fromDate)} has been $status.',
          type: 'status_change',
          relatedId: widget.request.id,
        );
        
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request $status"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // 1️⃣ HEADER
           Padding(
             padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
             child: Row(
               children: [
                 CircleAvatar(
                    radius: 24,
                    backgroundColor: AdminHelpers.getAvatarColor(r.userName).withOpacity(0.12),
                    child: Text(r.userName.isNotEmpty ? r.userName[0] : '?', 
                      style: TextStyle(color: AdminHelpers.getAvatarColor(r.userName), fontWeight: FontWeight.bold, fontSize: 18)),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(r.userName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                       Text("ID: ${r.employeeId}", style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontSize: 12)),
                     ],
                   ),
                 ),
                 _statusBadge(r.status),
               ],
             ),
           ),

           const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

           // 2️⃣ DETAILS GRID
           Padding(
             padding: const EdgeInsets.all(24),
             child: Column(
               children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Expanded(
                         flex: 4,
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             _label("TYPE"),
                             const SizedBox(height: 4),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                               decoration: BoxDecoration(
                                 color: AdminHelpers.secondaryColor.withOpacity(0.08),
                                 borderRadius: BorderRadius.circular(12),
                               ),
                               child: const Text(
                                 "On Duty (OD)",
                                 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AdminHelpers.secondaryColor),
                               ),
                             ),
                           ],
                         ),
                       ),
                       Expanded(
                         flex: 3,
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             _label("PERIOD"),
                             const SizedBox(height: 6),
                             Text(
                               "${AdminHelpers.formatDate(r.fromDate)} - ${AdminHelpers.formatDate(r.toDate)}",
                               style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                             ),
                           ],
                         ),
                       ),
                    ],
                  ),
                  
                  if (r.reason.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC), // Slate 50
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label("REASON"),
                          const SizedBox(height: 6),
                          Text(r.reason, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4)),
                        ],
                      ),
                    ),
                  ]
               ],
             ),
           ),
             
             // Actions
             if (r.status == 'Pending') ...[
               const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                      TextButton(
                        onPressed: _loading ? null : () => _updateStatus('Rejected'),
                        child: const Text("Reject", style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _loading ? null : () => _updateStatus('Approved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminHelpers.primaryColor, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          elevation: 0,
                        ),
                        child: _loading 
                           ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                           : const Text("Approve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                   ],
                 ),
               ),
             ]
          ],
        ),
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text)),
    );
  }
}
