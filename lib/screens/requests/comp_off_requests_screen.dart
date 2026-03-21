import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/admin_helpers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/responsive_container.dart';
import '../../services/notification_service.dart';
import '../../services/firestore_service.dart';

class CompOffRequestsScreen extends StatefulWidget {
  final String selectedYear;
  final String? adminDepartment; // ✅ Added but not fully used yet
  const CompOffRequestsScreen({super.key, required this.selectedYear, this.adminDepartment});

  @override
  State<CompOffRequestsScreen> createState() => _CompOffRequestsScreenState();
}

class _CompOffRequestsScreenState extends State<CompOffRequestsScreen> with SingleTickerProviderStateMixin {
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
    Stream<QuerySnapshot> getStream() {
      Query q;
      if (widget.adminDepartment == 'All') {
        q = FirebaseFirestore.instance.collectionGroup('records');
      } else {
        q = FirebaseFirestore.instance
            .collection('compOffRequests')
            .doc((widget.adminDepartment != null && widget.adminDepartment != 'All' && widget.adminDepartment != 'General') ? widget.adminDepartment : 'CSE')
            .collection('records');
      }
      if (widget.selectedYear != 'All' && widget.adminDepartment != 'All') {
        q = q.where('academicYearId', isEqualTo: widget.selectedYear);
      }
      return q.snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: getStream(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        var allRequests = docs.map((d) => d.data() as Map<String, dynamic>).toList();
        
        // ✅ In-memory filter for Super Admin 'All' view to avoid Index Error
        if (widget.adminDepartment == 'All' && widget.selectedYear != 'All') {
          allRequests = allRequests.where((r) => r['academicYearId'] == widget.selectedYear).toList();
        }

        // Add ID to each record for child components
        for (var i = 0; i < docs.length; i++) {
          allRequests[i]['id'] = docs[i].id;
        }

        // Filter for Comp-Off requests if using collectionGroup
        if (widget.adminDepartment == 'All') {
          allRequests = allRequests.where((r) => 
            r.containsKey('workedDate') || 
            r['leaveType'] == 'COMP' || 
            r['leaveType'] == 'Comp-Off Earn'
          ).toList();
        }

        // Department filter is now handled by the Firestore query string above

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildStatsRow(allRequests),
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
                  _buildTabContent(allRequests),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildTabContent(List<Map<String, dynamic>> requests) {
    return [
      _CompOffList(requests: requests),
      _CompOffList(requests: requests, filter: 'Pending'),
      _CompOffList(requests: requests, filter: 'Approved'),
      _CompOffList(requests: requests, filter: 'Rejected'),
    ][_tabController.index];
  }

  Widget _buildStatsRow(List<Map<String, dynamic>> requests) {
    int total = requests.length;
    int pending = requests.where((r) => r['status'] == 'Pending').length;
    int approved = requests.where((r) => r['status'] == 'Approved').length;
    int rejected = requests.where((r) => r['status'] == 'Rejected').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamic Spacing based on width
        final double spacing = constraints.maxWidth < 600 ? 12 : 24;
        
        if (constraints.maxWidth < 700) {
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              _statCard(total, "Total Grants", Icons.stars_rounded, AdminHelpers.primaryColor, width: (constraints.maxWidth - spacing - 2) / 2),
              _statCard(pending, "Pending", Icons.hourglass_top_rounded, AdminHelpers.warning, width: (constraints.maxWidth - spacing - 2) / 2),
              _statCard(approved, "Approved", Icons.verified_user_rounded, AdminHelpers.success, width: (constraints.maxWidth - spacing - 2) / 2),
              _statCard(rejected, "Rejected", Icons.cancel_presentation_rounded, AdminHelpers.danger, width: (constraints.maxWidth - spacing - 2) / 2),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _statCard(total, "Total Grants", Icons.stars_rounded, AdminHelpers.primaryColor)),
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

class _CompOffList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final String? filter;
  const _CompOffList({required this.requests, this.filter});

  @override
  Widget build(BuildContext context) {
    final filtered = filter == null
        ? requests
        : requests.where((r) => r['status'] == filter).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(48.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text("No Comp-Off requests found", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
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
              final data = filtered[index];
              return _CompOffCard(docId: data['id'], data: data);
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
                columnSpacing: (constraints.maxWidth - 580) / 4 > 24 ? (constraints.maxWidth - 580) / 4 : 24,
                horizontalMargin: 20,
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13),
                columns: const [
                  DataColumn(label: Text("STAFF NAME")),
                  DataColumn(label: Text("WORKED DATE")),
                  DataColumn(label: Text("DAYS EARNED")),
                  DataColumn(label: Text("STATUS")),
                  DataColumn(label: Text("ACTIONS")),
                ],
                rows: filtered.map((d) {
                  final status = d['status'] ?? 'Pending';
                  dynamic wVal = d['workedDate'];
                  DateTime workedDate;
                  if (wVal is Timestamp) workedDate = wVal.toDate();
                  else if (wVal is String) workedDate = DateTime.tryParse(wVal) ?? DateTime.now();
                  else workedDate = DateTime.now();
                  
                  final days = (d['days'] ?? 0.0).toDouble();

                  return DataRow(
                    cells: [
                      DataCell(
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(d['userId']).get(),
                          builder: (context, snap) {
                            final user = snap.data?.data() as Map<String, dynamic>?;
                            final name = user?['name'] ?? 'Unknown User';
                            final empId = user?['employeeId'] ?? 'N/A';
                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AdminHelpers.getAvatarColor(name).withOpacity(0.12),
                                  child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: AdminHelpers.getAvatarColor(name), fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                    Text(empId, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      DataCell(Text(DateFormat('EEE, MMM dd, yyyy').format(workedDate), style: const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text("${days.toStringAsFixed(1)} Days", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.orange)),
                        ),
                      ),
                      DataCell(_statusBadge(status)),
                      DataCell(
                        Row(
                          children: [
                            if (status == 'Pending') ...[
                              _ActionButton(
                                label: "Approve",
                                color: AdminHelpers.primaryColor,
                                icon: Icons.check_circle_outline,
                                docId: d['id'],
                                data: d,
                                newStatus: 'Approved',
                              ),
                              const SizedBox(width: 8),
                              _ActionButton(
                                label: "Reject",
                                color: Colors.red,
                                icon: Icons.cancel_outlined,
                                docId: d['id'],
                                data: d,
                                newStatus: 'Rejected',
                              ),
                            ] else ...[
                               TextButton.icon(
                                 onPressed: () {
                                   Navigator.pushNamed(
                                      context,
                                      AppRoutes.adminCompOffDetails,
                                      arguments: {'docId': d['id'], 'data': d},
                                    );
                                 },
                                 icon: const Icon(Icons.visibility_rounded, size: 16),
                                 label: const Text("View Details", style: TextStyle(fontSize: 12)),
                               )
                            ],
                          ],
                        ),
                      ),
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
  final String docId;
  final Map<String, dynamic> data;
  final String newStatus;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.docId,
    required this.data,
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
      final fire = FirebaseFirestore.instance;
      // 1. Update Request
      await fire.collection('compOffRequests').doc(widget.docId).update({
        'status': widget.newStatus,
        'actionTakenAt': FieldValue.serverTimestamp(),
      });

      // 2. If Approved, Create Grant in User's Subcollection
      if (widget.newStatus == 'Approved') {
        final userId = widget.data['userId'];
        final rawDays = widget.data['days'];
        final daysToCheck = (rawDays is num) ? rawDays.toDouble() : double.tryParse(rawDays.toString()) ?? 0.0;

        if (daysToCheck > 0 && userId != null) {
          await fire
              .collection('users')
              .doc(userId)
              .collection('compOffGrants')
              .add({
            'userId': userId,
            'days': daysToCheck,
            'sourceRequestId': widget.docId,
            'academicYearId': widget.data['academicYearId'] ?? '2024-2025',
            'grantedAt': FieldValue.serverTimestamp(),
            'workedDate': widget.data['workedDate'],
            'reason': widget.data['description'] ?? 'Approved via Dashboard',
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request ${widget.newStatus}")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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


class _CompOffCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _CompOffCard({required this.docId, required this.data});

  @override
  State<_CompOffCard> createState() => _CompOffCardState();
}

class _CompOffCardState extends State<_CompOffCard> {
  bool _loading = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      final fire = FirebaseFirestore.instance;
      
      // 1. Update Request
      await fire.collection('compOffRequests').doc(widget.docId).update({
        'status': newStatus,
        'actionTakenAt': FieldValue.serverTimestamp(),
      });

      // 2. If Approved, Create Grant in User's Subcollection
      if (newStatus == 'Approved') {
        final userId = widget.data['userId'];
        if (userId == null || userId.toString().isEmpty) {
          throw Exception("User ID missing in request. Cannot grant.");
        }

        final rawDays = widget.data['days'];
        final daysToCheck = (rawDays is num) ? rawDays.toDouble() : double.tryParse(rawDays.toString()) ?? 0.0;

        if (daysToCheck > 0) {
           await fire
              .collection('users')
              .doc(userId)
              .collection('compOffGrants')
              .add({
            'userId': userId,
            'days': daysToCheck,
            'sourceRequestId': widget.docId,
            'academicYearId': widget.data['academicYearId'] ?? '2024-2025',
            'grantedAt': FieldValue.serverTimestamp(),
            'workedDate': widget.data['workedDate'],
            'reason': widget.data['description'] ?? 'Approved via Dashboard',
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request $newStatus")));
      }

      // Notification
      try {
        await NotificationService().sendNotification(
          toUserId: widget.data['userId'],
          title: 'Comp-Off Request $newStatus',
          body: 'Your Comp-Off request for ${widget.data['days']} day(s) has been $newStatus.',
          type: 'status_change',
          relatedId: widget.docId,
          leaveType: 'COMP',
          academicYearId: widget.data['academicYearId'] ?? '2024-2025',
        );
      } catch (e) {
        debugPrint("Notification Error: $e");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    
    dynamic wVal = d['workedDate'];
    DateTime workedDate;
    if (wVal is Timestamp) workedDate = wVal.toDate();
    else if (wVal is String) workedDate = DateTime.tryParse(wVal) ?? DateTime.now();
    else workedDate = DateTime.now();

    final days = (d['days'] ?? 0.0).toDouble();
    final status = d['status'] ?? 'Pending';
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.adminCompOffDetails,
            arguments: {'docId': widget.docId, 'data': widget.data},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // 1️⃣ HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                   FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(d['userId']).get(),
                    builder: (context, snap) {
                       final user = snap.data?.data() as Map<String, dynamic>?;
                       final name = user?['name'] ?? 'Unknown User';
                       return CircleAvatar(
                         radius: 24,
                         backgroundColor: AdminHelpers.getAvatarColor(name).withOpacity(0.12),
                         child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: AdminHelpers.getAvatarColor(name), fontWeight: FontWeight.bold, fontSize: 18)),
                       );
                    }
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(d['userId']).get(),
                          builder: (context, snap) {
                             final user = snap.data?.data() as Map<String, dynamic>?;
                             final name = user?['name'] ?? 'Unknown';
                             final empId = user?['employeeId'] ?? 'N/A';
                             return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                                  Row(
                                    children: [
                                      Text(empId, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontSize: 12)),
                                      if (d['applicationId'] != null) ...[
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4.0),
                                          child: Text("•", style: TextStyle(color: Color(0xFF94A3B8))),
                                        ),
                                        Text(d['applicationId'], style: const TextStyle(color: AdminHelpers.primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                      ],
                                    ],
                                  ),
                                ],
                             );
                          }
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
            ),
            
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            
            // 2️⃣ INFO GRID
            Padding(
               padding: const EdgeInsets.all(24),
               child: Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _label("WORKED DATE"),
                         const SizedBox(height: 6),
                         Row(
                           children: [
                             const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                             const SizedBox(width: 6),
                             Text(
                                DateFormat('EEE, MMM dd, yyyy').format(workedDate),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                             ),
                           ],
                         )
                       ],
                     ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _label("DAYS EARNED"),
                         const SizedBox(height: 6),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                           decoration: BoxDecoration(
                             color: Colors.orange.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Text(
                             "${days.toStringAsFixed(1)} Days",
                             style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.orange),
                           ),
                         ),
                       ],
                     ),
                   ),
                 ],
               ),
            ),

            if (status == 'Pending') ...[
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
                     ),
                   ],
                 ),
               ),
            ]
          ],
        ),
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
