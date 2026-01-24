import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/admin_helpers.dart';

class CompOffRequestsScreen extends StatefulWidget {
  final String selectedYear;
  const CompOffRequestsScreen({super.key, required this.selectedYear});

  @override
  State<CompOffRequestsScreen> createState() => _CompOffRequestsScreenState();
}

class _CompOffRequestsScreenState extends State<CompOffRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _fire = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return ListView( // ✅ Changed to ListView
      padding: const EdgeInsets.all(24),
      children: [
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
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF2563EB),
                tabs: const [
                  Tab(text: "PENDING"),
                  Tab(text: "APPROVED"),
                  Tab(text: "REJECTED"),
                ],
              ),
              SizedBox(
                height: 800, // Increased for better visibility
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CompOffList(status: 'Pending', selectedYear: widget.selectedYear),
                    _CompOffList(status: 'Approved', selectedYear: widget.selectedYear),
                    _CompOffList(status: 'Rejected', selectedYear: widget.selectedYear),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompOffList extends StatelessWidget {
  final String status;
  final String selectedYear;
  const _CompOffList({required this.status, required this.selectedYear});

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('compOffRequests')
        .where('status', isEqualTo: status);
    
    if (selectedYear != 'All') {
      query = query.where('academicYearId', isEqualTo: selectedYear);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No $status requests", style: const TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true, // ✅ Added
          physics: const NeverScrollableScrollPhysics(), // ✅ Added
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _CompOffCard(docId: doc.id, data: data);
          },
        );
      },
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
          debugPrint("ERROR: Cannot grant Comp-Off. UserId is null/empty!");
          throw Exception("User ID missing in request. Cannot grant.");
        }

        debugPrint("DEBUG: Granting Comp-Off to User: $userId");
        
        await fire
            .collection('users')
            .doc(userId)
            .collection('compOffGrants')
            .add({
          'userId': userId,
          'days': widget.data['days'],
          'sourceRequestId': widget.docId,
          'academicYearId': widget.data['academicYearId'] ?? '2024-2025',
          'grantedAt': FieldValue.serverTimestamp(),
          'workedDate': widget.data['workedDate'],
          'reason': widget.data['description'],
        });
        debugPrint("DEBUG: Grant created successfully.");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request $newStatus")));
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text("${days.toStringAsFixed(1)} Days Credited"),
                  backgroundColor: AdminHelpers.getLeaveColor('COMP').withOpacity(0.1),
                  labelStyle: TextStyle(color: AdminHelpers.getLeaveColor('COMP'), fontWeight: FontWeight.bold),
                ),
                Text(AdminHelpers.formatDate(workedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(d['userId']).get(),
              builder: (context, snap) {
                if (!snap.hasData) return const Text("Loading...");
                final user = snap.data!.data() as Map<String, dynamic>?;
                return Text(
                  (user?['name'] ?? 'Unknown User').toString().toUpperCase(), 
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))
                );
              },
            ),
            const SizedBox(height: 8),
            Text(d['description'] ?? "No description", style: const TextStyle(color: Colors.black87)),
            if (d['proofUrl'] != null && (d['proofUrl'] as String).isNotEmpty) ...[
               const SizedBox(height: 12),
               InkWell(
                 onTap: () async {
                   final uri = Uri.parse(d['proofUrl']);
                   if (await canLaunchUrl(uri)) {
                     await launchUrl(uri);
                   }
                 },
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: Colors.blue.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(8),
                     border: Border.all(color: Colors.blue.withOpacity(0.3))
                   ),
                   child: const Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Icon(Icons.attachment_rounded, size: 16, color: Colors.blue),
                       SizedBox(width: 6),
                       Text("View Attached Proof", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                     ],
                   ),
                 ),
               ),
            ],
            if (status == 'Pending') ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   TextButton(
                    onPressed: _loading ? null : () => _updateStatus('Rejected'),
                    child: const Text("Reject", style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : () => _updateStatus('Approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    child: _loading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Approve & Grant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
