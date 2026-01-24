import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/admin_helpers.dart';
import '../../models/leave_request_model.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final String userId;

  const EmployeeDetailsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _idController = TextEditingController();
  bool _isEditingId = false;
  bool _isSaving = false;

  // 🎨 Theme
  static const Color primaryBlue = Color(0xFF3399CC);
  static const Color scaffoldBg = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _saveEmployeeId() async {
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateEmployeeId(widget.userId, _idController.text.trim());
      setState(() => _isEditingId = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Employee ID updated successfully"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating ID: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: primaryBlue,
        title: const Text(
          "Employee Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<UserModel>(
        stream: _firestoreService.getUserStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("Employee not found"));
          }

          final user = snapshot.data!;
          if (!_isEditingId) {
            _idController.text = user.employeeId;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _profileCard(user),
                const SizedBox(height: 20),
                _buildLeaveData(user.uid),
              ],
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------
  // 👤 PROFILE CARD
  // --------------------------------------------------
  Widget _profileCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: primaryBlue.withOpacity(0.1),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.department,
                       style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryBlue,
                      ),
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.role.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),
          // 📝 EMPLOYEE ID ROW
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: textMuted, size: 20),
              const SizedBox(width: 12),
              const Text("EMPLOYEE ID:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: _isEditingId 
                  ? TextField(
                      controller: _idController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryBlue),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        border: UnderlineInputBorder(),
                      ),
                    )
                  : Text(user.employeeId, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark)),
              ),
              if (_isEditingId)
                Row(
                  children: [
                    if (_isSaving)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      IconButton(
                        icon: const Icon(Icons.check_rounded, color: Colors.green, size: 22),
                        onPressed: _saveEmployeeId,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.red, size: 22),
                      onPressed: () => setState(() => _isEditingId = false),
                    ),
                  ],
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: primaryBlue, size: 20),
                  onPressed: () => setState(() => _isEditingId = true),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 📊 LEAVE STATS & HISTORY (REAL-TIME)
  // --------------------------------------------------
  Widget _buildLeaveData(String userId) {
    return StreamBuilder<List<LeaveRequestModel>>(
      stream: _firestoreService.getEmployeeLeaveHistory(userId),
      builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
         }
         
         if (snapshot.hasError) {
           return Text("Error loading leaves: ${snapshot.error}");
         }

         final leaves = snapshot.data ?? [];

         // Calculate Stats
         int total = leaves.length;
         int pending = leaves.where((l) => l.status == 'Pending').length;
         int approved = leaves.where((l) => l.status == 'Approved').length;
         int rejected = leaves.where((l) => l.status == 'Rejected').length;

         return Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // Stats Row
             Row(
               children: [
                 _statBox("TOTAL", total, const Color(0xFF3399CC)),
                 _statBox("PENDING", pending, const Color(0xFFF59E0B)),
                 _statBox("APPROVED", approved, const Color(0xFF8CC63F)),
                 _statBox("REJECTED", rejected, const Color(0xFFEF4444)),
               ],
             ),
             
             const SizedBox(height: 32),
             
             // History List
             const Text(
               "Leave History",
               style: TextStyle(
                 fontSize: 18,
                 fontWeight: FontWeight.bold,
                 color: textDark,
               ),
             ),
             const SizedBox(height: 16),
             
             if (leaves.isEmpty)
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(32),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                 ),
                 child: const Column(
                   children: [
                     Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFE2E8F0)),
                     SizedBox(height: 12),
                     Text("No leave records found", style: TextStyle(color: textMuted)),
                   ],
                 ),
               )
             else
               ListView.builder(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: leaves.length,
                 itemBuilder: (context, index) => _leaveCard(leaves[index]),
               ),
           ],
         );
      },
    );
  }

  Widget _statBox(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _leaveCard(LeaveRequestModel leave) {
    final statusColor = AdminHelpers.getStatusColor(leave.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Neutral Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.event_note,
              color: Color(0xFF64748B),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leave Type (Neutral)
                Text(
                  AdminHelpers.getLeaveName(leave.leaveType),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                // Date Range
                Text(
                  "${AdminHelpers.formatDate(leave.fromDate)} → ${AdminHelpers.formatDate(leave.toDate)}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Status Badge (ONLY colored element)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              leave.status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
