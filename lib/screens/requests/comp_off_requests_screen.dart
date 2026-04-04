import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/admin_helpers.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../routes/app_routes.dart';
import '../../widgets/responsive_container.dart';

class CompOffRequestsScreen extends StatefulWidget {
  final String selectedYear;
  final String adminDepartment;

  const CompOffRequestsScreen({
    super.key,
    required this.selectedYear,
    required this.adminDepartment,
  });

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getCompOffRequestsStream(
        department: widget.adminDepartment,
        academicYearId: widget.selectedYear,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final requests = snapshot.data ?? [];

        return Column(
          children: [
            _buildStatsRow(requests),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: "ALL"),
                Tab(text: "PENDING"),
                Tab(text: "APPROVED"),
                Tab(text: "REJECTED"),
              ],
              labelColor: AdminHelpers.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AdminHelpers.primaryColor,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CompOffList(requests: requests),
                  _CompOffList(requests: requests, filter: 'Pending'),
                  _CompOffList(requests: requests, filter: 'Approved'),
                  _CompOffList(requests: requests, filter: 'Rejected'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsRow(List<Map<String, dynamic>> requests) {
    int total = requests.length;
    int pending = requests.where((r) => r['status'] == 'Pending').length;
    int approved = requests.where((r) => r['status'] == 'Approved').length;
    int rejected = requests.where((r) => r['status'] == 'Rejected').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int crossAxisCount = width > 1000 ? 4 : (width > 600 ? 2 : 2);
        double spacing = width > 600 ? 16 : 8;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          padding: const EdgeInsets.all(16),
          childAspectRatio: width > 1200 ? 1.6 : (width > 600 ? 1.4 : 1.1),
          children: [
            _statCard(total, "Total Grants", Icons.stars_rounded, AdminHelpers.primaryColor),
            _statCard(pending, "Pending", Icons.hourglass_top_rounded, AdminHelpers.warning),
            _statCard(approved, "Approved", Icons.verified_user_rounded, AdminHelpers.success),
            _statCard(rejected, "Rejected", Icons.cancel_presentation_rounded, AdminHelpers.danger),
          ],
        );
      }
    );
  }

  Widget _statCard(int value, String label, IconData icon, Color color) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(12),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), 
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.toString(), 
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.w900, 
                letterSpacing: -0.5, 
                color: isDark ? Colors.white : AdminHelpers.textMain
              )
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(), 
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.bold, 
              color: isDark ? Colors.grey[400] : AdminHelpers.textMuted, 
              letterSpacing: 0.5
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No $filter requests found", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        
        // 🚀 Mobile View
        if (width < 900) {
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _CompOffCard(
              docId: filtered[index]['id'],
              data: filtered[index],
            ),
          );
        }

        // 🚀 Desktop Table View (Matching Employees & On-Duty)
        return _buildDesktopTable(filtered, context, isDark, constraints);
      },
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> filtered, BuildContext context, bool isDark, BoxConstraints constraints) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AdminHelpers.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AdminHelpers.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(isDark ? AdminHelpers.primaryColor.withOpacity(0.8) : const Color(0xFF001C3D)),
            headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            dataRowHeight: 70,
            columnSpacing: (constraints.maxWidth - 600) / 5 > 24 ? (constraints.maxWidth - 600) / 5 : 24,
            horizontalMargin: 20,
            columns: const [
              DataColumn(label: Text("STAFF NAME")),
              DataColumn(label: Text("WORKED DATE")),
              DataColumn(label: Text("DAYS")),
              DataColumn(label: Text("REASON")),
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

              return DataRow(
                cells: [
                  DataCell(
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(d['userId']).get(),
                      builder: (context, snap) {
                        final userData = snap.data?.data() as Map?;
                        final name = userData?['name'] ?? d['userName'] ?? 'Unknown';
                        final profilePic = userData?['profilePicUrl'];
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AdminHelpers.getAvatarColor(name).withOpacity(0.1),
                              backgroundImage: profilePic?.isNotEmpty == true ? NetworkImage(profilePic!) : null,
                              child: profilePic?.isNotEmpty == true ? null : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(color: AdminHelpers.getAvatarColor(name), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                Text(userData?['employeeId'] ?? d['employeeId'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                              ],
                            ),
                          ],
                        );
                      }
                    ),
                  ),
                  DataCell(Text(DateFormat('dd MMM yyyy').format(workedDate), style: const TextStyle(fontSize: 13))),
                  DataCell(Text("${d['days']}d", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataCell(SizedBox(width: 150, child: Text(d['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))),
                  DataCell(_statusBadge(status)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, color: AdminHelpers.primaryColor, size: 20),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.adminCompOffDetails,
                              arguments: {'docId': d['id'], 'data': d},
                            );
                          },
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

class _CompOffCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _CompOffCard({required this.docId, required this.data});

  @override
  State<_CompOffCard> createState() => _CompOffCardState();
}

class _CompOffCardState extends State<_CompOffCard> {
  bool _loading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);
    try {
      await FirestoreService().updateCompOffStatus(
        widget.docId,
        status,
        'admin',
        department: widget.data['department'] ?? 'General',
        data: widget.data,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request $status successfully")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))
        ],
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
            // HEADER
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(d['userId']).get(),
                    builder: (context, snap) {
                      final userData = snap.data?.data() as Map?;
                      final name = userData?['name'] ?? d['userName'] ?? 'Unknown';
                      final profilePic = userData?['profilePicUrl'];
                      return CircleAvatar(
                        radius: 24,
                        backgroundColor: AdminHelpers.getAvatarColor(name).withOpacity(0.1),
                        backgroundImage: profilePic?.isNotEmpty == true ? NetworkImage(profilePic!) : null,
                        child: profilePic?.isNotEmpty == true ? null : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(color: AdminHelpers.getAvatarColor(name), fontWeight: FontWeight.bold)),
                      );
                    }
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(d['userId']).get(),
                      builder: (context, snap) {
                        final user = snap.data?.data() as Map?;
                        final name = user?['name'] ?? 'Loading...';
                        final empId = user?['employeeId'] ?? '';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name.toUpperCase(), 
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(empId, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ),
                          ],
                        );
                      }
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            // INFO GRID
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("WORKED DATE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(DateFormat('MMM dd, yyyy').format(workedDate), 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("DAYS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text("${days.toStringAsFixed(1)}d", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (status == 'Pending') ...[
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _loading ? null : () => _updateStatus('Rejected'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact),
                        child: const Text("Reject", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : () => _updateStatus('Approved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminHelpers.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Approve", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: text)),
    );
  }
}
