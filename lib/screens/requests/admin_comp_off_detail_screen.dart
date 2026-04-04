import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/admin_helpers.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import 'media_viewer_screen.dart'; // ✅ Added

class AdminCompOffDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const AdminCompOffDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  State<AdminCompOffDetailScreen> createState() => _AdminCompOffDetailScreenState();
}

class _AdminCompOffDetailScreenState extends State<AdminCompOffDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _loading = false;
  
  // User Profile Data
  String _userName = "Loading...";
  String _employeeId = "Loading...";
  String _department = "Loading...";

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.data['userId'])
          .get();
      
      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        setState(() {
          _userName = data['name'] ?? 'Unknown User';
          _employeeId = data['employeeId'] ?? 'N/A';
          _department = data['department'] ?? 'N/A';
        });
      }
    } catch (e) {
      debugPrint("Error fetching user for comp-off: $e");
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      final department = widget.data['department'] ?? 'General';

      // 1. Update Request via Service (hits isolated path)
      await _firestoreService.updateCompOffStatus(
        widget.docId, 
        newStatus, 
        'admin', 
        department: department,
        data: widget.data
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request $newStatus")));

        // ✅ Send Notification to User
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

        Navigator.pop(context);
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
    final theme = Theme.of(context);
    final d = widget.data;
    
    // Parse Dates
    dynamic workedVal = d['workedDate'];
    DateTime workedDate;
    if (workedVal is Timestamp) workedDate = workedVal.toDate();
    else if (workedVal is String) workedDate = DateTime.tryParse(workedVal) ?? DateTime.now();
    else workedDate = DateTime.now();

    final status = d['status'] ?? 'Pending';
    final statusColor = AdminHelpers.getStatusColor(status);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        title: const Text("Comp-Off Request", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B), // Slate 800
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 🏷️ Status Header
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(
                     status == 'Approved' ? Icons.check_circle_rounded : (status == 'Rejected' ? Icons.cancel_rounded : Icons.hourglass_top_rounded),
                     size: 16,
                     color: statusColor,
                   ),
                   const SizedBox(width: 8),
                   Text(
                     "STATUS: ${status.toUpperCase()}",
                     style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                   ),
                ],
              ),
            ),

            // 📄 Request Document
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Expanded(
                         child: Text("Compensatory Off Grant Requisition", 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, color: theme.textTheme.titleMedium?.color)),
                       ),
                       Text("Date: ${AdminHelpers.formatDate(workedDate)}"),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // STAFF PROFILE SECTION
                  Row(
                    children: [
                       FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(widget.data['userId']).get(),
                          builder: (context, snap) {
                            final userData = snap.data?.data() as Map?;
                            final name = userData?['name'] ?? _userName;
                            final profilePic = userData?['profilePicUrl'];
                            return CircleAvatar(
                               radius: 28,
                               backgroundColor: AdminHelpers.getAvatarColor(name).withOpacity(0.1),
                               backgroundImage: profilePic?.isNotEmpty == true ? NetworkImage(profilePic!) : null,
                               child: profilePic?.isNotEmpty == true ? null : Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: AdminHelpers.getAvatarColor(name), fontSize: 20, fontWeight: FontWeight.bold)),
                            );
                          }
                       ),
                       const SizedBox(width: 16),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              Text(_userName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: AdminHelpers.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Text(_department, style: const TextStyle(color: AdminHelpers.primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text("ID: $_employeeId", style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                           ],
                         ),
                       ),
                    ],
                  ),
                  const Divider(height: 48, color: Color(0xFFE2E8F0)),
                  
                  // DETAILS GRID
                  _detailRow("Date Worked", AdminHelpers.formatDate(workedDate)),
                  if (d['applicationId'] != null)
                    _detailRow("Application ID", d['applicationId']),
                  
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(width: 140, child: Text("Days Credited:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text("${(d['days'] ?? 0.0)} Day(s)", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 48, color: Color(0xFFE2E8F0)),
                  
                  const Text("Reason/Justification:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(d['description'] ?? "No description provided.", 
                    style: const TextStyle(height: 1.6, fontSize: 14, color: Color(0xFF334155))),
                  
                  const SizedBox(height: 32),

                  // ATTACHMENT
                  if (d['proofUrl'] != null && (d['proofUrl'] as String).isNotEmpty)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                             builder: (_) => MediaViewerScreen(
                               url: d['proofUrl'],
                               title: "Work Evidence",
                             )
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AdminHelpers.secondaryColor.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminHelpers.secondaryColor.withOpacity(0.2)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.file_present_rounded, color: AdminHelpers.secondaryColor),
                            SizedBox(width: 12),
                            Text("View Official Proof / Work Evidence", 
                              style: TextStyle(color: AdminHelpers.secondaryColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (status == 'Pending') ...[
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _updateStatus('Rejected'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Reject Request", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : () => _updateStatus('Approved'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: AdminHelpers.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Approve & Credit", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
