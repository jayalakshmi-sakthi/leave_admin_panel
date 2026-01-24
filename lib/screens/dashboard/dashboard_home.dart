import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  // 🎨 Theme
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color scaffoldBg = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Overview",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "Quick insights on leave activities",
          style: TextStyle(color: textMuted),
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
          .collectionGroup('leaveRequests')
          .snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, approved = 0;

        if (snapshot.hasData) {
          for (var d in snapshot.data!.docs) {
            total++;
            final status = d['status'];
            if (status == 'Pending') pending++;
            if (status == 'Approved') approved++;
          }
        }

        return Row(
          children: [
            _statCard("Total Requests", total, Colors.blue),
            _statCard("Pending", pending, Colors.orange),
            _statCard("Approved", approved, Colors.green),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: textMuted)),
          ],
        ),
      ),
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
          "Recent Leave Requests",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('leaveRequests')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.data!.docs.isEmpty) {
              return const Text("No recent requests");
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_note, color: primaryBlue),
                  title: Text(
                    d['leaveType'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    d['status'] ?? 'Pending',
                    style: const TextStyle(color: textMuted),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
