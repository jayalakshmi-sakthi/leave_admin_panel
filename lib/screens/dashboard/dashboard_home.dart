import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/admin_helpers.dart';
import '../../widgets/dashboard/Summary_card.dart';

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildRecentRequests(),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 📌 HEADER
  // --------------------------------------------------
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Dashboard Overview",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AdminHelpers.textMain,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Real-time monitoring of departmental leave activity",
          style: TextStyle(
            color: AdminHelpers.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // 📊 STATISTICS
  // --------------------------------------------------
  Widget _buildStatsCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('records') // Using 'records' to stay consistent with new schema
          .snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, approved = 0, rejected = 0;

        if (snapshot.hasData) {
          for (var d in snapshot.data!.docs) {
            total++;
            final status = d['status']?.toString().toLowerCase() ?? 'pending';
            if (status == 'pending') pending++;
            else if (status == 'approved') approved++;
            else if (status == 'rejected') rejected++;
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            if (width < 600) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: SummaryCard(title: "Total Records", value: total.toString(), icon: Icons.folder_copy_rounded, color: AdminHelpers.primaryColor, onTap: () {})),
                      const SizedBox(width: 12),
                      Expanded(child: SummaryCard(title: "Pending", value: pending.toString(), icon: Icons.hourglass_top_rounded, color: AdminHelpers.warning, onTap: () {})),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: SummaryCard(title: "Approved", value: approved.toString(), icon: Icons.verified_user_rounded, color: AdminHelpers.success, onTap: () {})),
                      const SizedBox(width: 12),
                      Expanded(child: SummaryCard(title: "Rejected", value: rejected.toString(), icon: Icons.cancel_presentation_rounded, color: AdminHelpers.danger, onTap: () {})),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: SummaryCard(title: "Total Records", value: total.toString(), icon: Icons.folder_copy_rounded, color: AdminHelpers.primaryColor, onTap: () {})),
                const SizedBox(width: 16),
                Expanded(child: SummaryCard(title: "Pending Approval", value: pending.toString(), icon: Icons.hourglass_top_rounded, color: AdminHelpers.warning, onTap: () {})),
                const SizedBox(width: 16),
                Expanded(child: SummaryCard(title: "Approved Requests", value: approved.toString(), icon: Icons.verified_user_rounded, color: AdminHelpers.success, onTap: () {})),
                const SizedBox(width: 16),
                Expanded(child: SummaryCard(title: "Rejected Entries", value: rejected.toString(), icon: Icons.cancel_presentation_rounded, color: AdminHelpers.danger, onTap: () {})),
              ],
            );
          },
        );
      },
    );
  }


  // --------------------------------------------------
  // 🧾 RECENT REQUESTS (LIMITED)
  // --------------------------------------------------
  Widget _buildRecentRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Recent Leave Activity",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AdminHelpers.textMain,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('records')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                decoration: AdminHelpers.cardDecoration(context),
                child: const Center(child: Text("No recent requests available")),
              );
            }

            return Container(
              decoration: AdminHelpers.cardDecoration(context),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                itemBuilder: (context, index) {
                  final d = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final String leaveType = d['leaveType'] ?? 'Leave';
                  final String status = d['status']?.toString().toLowerCase() ?? 'pending';
                  final Color statusColor = status == 'approved' ? AdminHelpers.success : (status == 'rejected' ? AdminHelpers.danger : AdminHelpers.warning);
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AdminHelpers.getLeaveColor(leaveType).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AdminHelpers.getLeaveIcon(leaveType), color: AdminHelpers.getLeaveColor(leaveType), size: 20),
                    ),
                    title: Text(
                      d['userName'] ?? 'Anonymous',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AdminHelpers.textMain),
                    ),
                    subtitle: Text(
                      "$leaveType - ${d['numberOfDays']} Days",
                      style: TextStyle(color: AdminHelpers.textMuted, fontSize: 13),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
