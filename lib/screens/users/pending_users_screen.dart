import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/admin_helpers.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';

class PendingUsersScreen extends StatefulWidget {
  const PendingUsersScreen({super.key});

  @override
  State<PendingUsersScreen> createState() => _PendingUsersScreenState();
}

class _PendingUsersScreenState extends State<PendingUsersScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _notificationService = NotificationService();

  Stream<List<UserModel>> _getPendingUsers() {
    return _firestore
        .collection('users')
        .where('approved', isEqualTo: false)
        .where('role', isEqualTo: 'staff') // Only staff need approval
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> _approveUser(UserModel user) async {
    try {
      final currentAdmin = FirebaseAuth.instance.currentUser;
      
      await _firestore.collection('users').doc(user.uid).update({
        'approved': true,
        'approvedBy': currentAdmin?.uid,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to user
      await _notificationService.sendNotification(
        toUserId: user.uid,
        title: 'Account Approved',
        body: 'Your account has been approved. You can now access the leave management system.',
        type: 'account_approval',
        relatedId: user.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} approved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rejectUser(UserModel user) async {
    try {
      // Delete user account
      await _firestore.collection('users').doc(user.uid).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} rejected and removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Pending User Approvals', style: TextStyle(color: theme.textTheme.titleLarge?.color, fontWeight: FontWeight.bold)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _getPendingUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final pendingUsers = snapshot.data ?? [];

          if (pendingUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                      ]
                    ),
                    child: Icon(Icons.check_circle_outline_rounded, size: 64, color: theme.disabledColor),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No pending approvals',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.disabledColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All caught up! New registrations will appear here.',
                    style: TextStyle(fontSize: 14, color: theme.disabledColor),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: pendingUsers.length,
            itemBuilder: (context, index) {
              final user = pendingUsers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
                  boxShadow: [
                     if (!isDark)
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundImage: user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty
                            ? NetworkImage(user.profilePicUrl!)
                            : null,
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        child: user.profilePicUrl == null
                            ? Text(user.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 20))
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(AdminHelpers.sanitizeLabel(user.name), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.titleLarge?.color)),
                          Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                             decoration: BoxDecoration(
                               color: theme.dividerColor.withOpacity(0.3),
                               borderRadius: BorderRadius.circular(6)
                             ),
                             child: Text(
                               user.department == "Placement Cell" 
                                   ? (user.employeeId ?? 'No ID')
                                   : "${user.employeeId ?? 'No ID'} • ${user.department}", 
                               style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)
                             ),
                          ),
                           Text(user.email, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),

                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Button
                    ElevatedButton(
                      onPressed: () => _showApprovalDialog(context, user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Review", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showApprovalDialog(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: theme.cardColor, // Ensure theme background
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large Profile Pic
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.dividerColor, width: 4),
                image: user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty
                    ? DecorationImage(image: NetworkImage(user.profilePicUrl!), fit: BoxFit.cover)
                    : null,
                color: Colors.orange.withOpacity(0.1),
              ),
              child: user.profilePicUrl == null
                  ? Center(child: Text(user.name[0].toUpperCase(), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.orange)))
                  : null,
            ),
            const SizedBox(height: 16),
            Text(user.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color), textAlign: TextAlign.center),
            Text(user.email, style: TextStyle(fontSize: 14, color: theme.textTheme.bodySmall?.color), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _detailRow(context, "Employee ID", user.employeeId ?? "N/A"),
            _detailRow(context, "Designation", user.designation ?? "-"),
            if (user.department != "Placement Cell")
              _detailRow(context, "Department", user.department),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _rejectUser(user);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _approveUser(user);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Approve", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }
}
