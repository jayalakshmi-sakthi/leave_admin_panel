import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';
import '../../utils/admin_helpers.dart';
// import '../../routes/app_routes.dart'; // 🔴 Removed to fix circular dependency

class AdminNotificationsScreen extends StatelessWidget {
  final String? departmentFilter; // ✅ Added for isolation
  const AdminNotificationsScreen({super.key, this.departmentFilter});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: AdminHelpers.scaffoldBg, // Admin Panel Background
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Notifications", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: AdminHelpers.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Colors.white70),
            onPressed: () => NotificationService().markAllAsRead(user.uid),
            tooltip: "Mark all as read",
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NotificationService().streamNotifications(user.uid),
        builder: (context, snapshot) {
          final allNotifications = snapshot.data ?? [];
          
            // 🔎 APPLY FILTER
          final notifications = allNotifications.where((n) {
            if (departmentFilter == null || departmentFilter == 'All') return true;
            
            final target = n['targetDepartment']?.toString();
            // Case-insensitive match or null
            // If target is null, it's a global notification. We only show it in 'All' view.
            if (target == null) return true; // ✅ Show global notifications to everyone
            return target.toLowerCase() == departmentFilter!.toLowerCase();
          }).toList();

          if (notifications.isEmpty) {
            final bool isFiltered = departmentFilter != null && departmentFilter != 'All';
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.notifications_off_rounded, size: 64, color: Colors.grey[300]),
                   const SizedBox(height: 16),
                   Text(
                     isFiltered ? "No notifications for $departmentFilter" : "No notifications yet", 
                     style: TextStyle(color: Colors.grey[500], fontSize: 16)
                   ),
                ],
              ),
            );
          }

          // 🗓️ GROUP BY DATE
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (var notif in notifications) {
            final createdAt = (notif['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final now = DateTime.now();
            final diff = DateTime(now.year, now.month, now.day).difference(DateTime(createdAt.year, createdAt.month, createdAt.day)).inDays;
            
            String key = "Earlier";
            if (diff == 0) key = "Today";
            else if (diff == 1) key = "Yesterday";
            
            if (!grouped.containsKey(key)) grouped[key] = [];
            grouped[key]!.add(notif);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Text(
                      entry.key, 
                      style: TextStyle(
                        color: Colors.grey[600], 
                        fontWeight: FontWeight.bold, 
                        fontSize: 14,
                        letterSpacing: 0.5
                      )
                    ),
                  ),
                  
                  // List Items
                  ...entry.value.map((notif) {
                    final isRead = notif['isRead'] == true;
                    final title = notif['title']?.toString() ?? 'Alert';
                    final body = notif['body']?.toString() ?? '';
                    final createdAt = (notif['createdAt'] as Timestamp?)?.toDate();
                    final leaveType = notif['leaveType']?.toString() ?? '';
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    
                    // Unified Professional Color Strategy
                    Color color = AdminHelpers.primaryColor; 
                    IconData icon = Icons.info_outline;

                    if (title.toLowerCase().contains('request') || leaveType.isNotEmpty) {
                       color = AdminHelpers.getLeaveColor(leaveType.isNotEmpty ? leaveType : title);
                       icon = AdminHelpers.getLeaveIcon(leaveType.isNotEmpty ? leaveType : title);
                    } else if (title.toLowerCase().contains('registration') || body.toLowerCase().contains('registered')) {
                      color = AdminHelpers.success;
                      icon = Icons.person_add_alt_1_rounded;
                    }

                    // Optional: Override icon with Dept icon if it's a general alert
                    final String? targetDept = notif['targetDepartment'] as String?;
                    if (targetDept != null && icon == Icons.info_outline) {
                      icon = AdminHelpers.getDeptIcon(targetDept);
                      color = AdminHelpers.getDeptColor(targetDept);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Dismissible(
                        key: Key(notif['id']),
                        background: Container(
                          decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: Icon(Icons.delete_outline, color: Colors.red[800]),
                        ),
                        onDismissed: (_) {
                          // Optional: Delete notification logic
                        },
                        child: InkWell(
                          onTap: () async {
                            if (!isRead) {
                              await NotificationService().markAsRead(notif['id']);
                            }
                            
                            // 🧭 NAVIGATION LOGIC
                            // Fetch detailed data before navigating
                            final String? leaveType = notif['leaveType'] as String?;
                            final String? relatedId = notif['relatedId'] as String?;
                            final String? academicYearId = notif['academicYearId'] as String?;
                            final String? type = notif['type'] as String?; // ✅ Added Type

                            if (relatedId != null && type != 'new_user') { // ✅ Avoid fetch for new_user
                               try {
                                 final String? targetDept = notif['targetDepartment'] as String?;
                                 
                                 // Determine functionality
                                 if (leaveType == 'COMP' || leaveType == 'Comp-Off Earn') {
                                   // Fetch Comp-Off (using isolated department path)
                                   // Fallback to searching if dept mismatch or missing
                                   DocumentSnapshot? doc;
                                   
                                   if (targetDept != null && targetDept.isNotEmpty) {
                                      doc = await FirebaseFirestore.instance
                                          .collection('compOffRequests') 
                                          .doc(targetDept)
                                          .collection('records')
                                          .doc(relatedId)
                                          .get();
                                   }

                                   if (doc == null || !doc.exists) {
                                      // Search across all departments (backup for legacy)
                                      final search = await FirebaseFirestore.instance
                                          .collectionGroup('records')
                                          .where('applicationId', isEqualTo: relatedId) // or search by ID if possible
                                          .get();
                                      if (search.docs.isNotEmpty) doc = search.docs.first;
                                   }

                                   if (doc != null && doc.exists && context.mounted) {
                                      Navigator.pushNamed(
                                        context, 
                                        '/admin/comp-off-details',
                                        arguments: {'docId': doc.id, 'data': doc.data()}
                                      );
                                   }
                                 } else {
                                   // Fetch Leave/OD
                                   String yearId = academicYearId ?? '2024-2025';
                                   if (academicYearId == null) {
                                      final settings = await FirebaseFirestore.instance.collection('settings').doc('academic_year').get();
                                      if (settings.exists) {
                                         yearId = settings.data()?['id'] ?? '2024-2025';
                                      }
                                   }

                                   // Search across all dept subcollections
                                   final snap = await FirebaseFirestore.instance
                                       .collectionGroup('records')
                                       .where('id', isEqualTo: relatedId)
                                       .limit(1)
                                       .get();

                                   if (snap.docs.isNotEmpty && context.mounted) {
                                      final doc = snap.docs.first;
                                      Navigator.pushNamed(
                                        context,
                                        '/requests/detail', 
                                        arguments: {'id': doc.id},
                                      );
                                   }
                                 }
                               } catch (e) {
                                 debugPrint("Navigation Error: $e");
                                 if (context.mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text("Could not load details: $e")),
                                   );
                                 }
                               }
                            } else if (type == 'new_user' || title.toLowerCase().contains('registration')) {
                               // Direct Navigation for Registration
                               Navigator.pushNamed(context, '/pending-users', arguments: {'departmentFilter': departmentFilter});
                            } else {
                               // Default Fallback
                               Navigator.pushNamed(context, '/leave-requests'); 
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isRead ? (isDark ? AdminHelpers.darkSurface.withOpacity(0.5) : Colors.white.withOpacity(0.6)) : (isDark ? AdminHelpers.darkSurface : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isRead ? (isDark ? AdminHelpers.darkBorder : const Color(0xFFE2E8F0)) : color.withOpacity(0.5), width: 1),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(AdminHelpers.sanitizeLabel(title), style: TextStyle(fontWeight: isRead ? FontWeight.w600 : FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : AdminHelpers.textMain))),
                                          if (notif['targetDepartment'] != null && (departmentFilter == null || departmentFilter == 'All'))
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AdminHelpers.getDeptColor(notif['targetDepartment']).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                notif['targetDepartment'],
                                                style: TextStyle(
                                                  color: AdminHelpers.getDeptColor(notif['targetDepartment']),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold
                                                ),
                                              ),
                                            ),
                                          if (!isRead)
                                            Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 8), decoration: BoxDecoration(color: color, shape: BoxShape.circle))
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(AdminHelpers.sanitizeLabel(body), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.3)),
                                      if (createdAt != null) ...[
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(DateFormat('hh:mm a').format(createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                        )
                                      ]
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
