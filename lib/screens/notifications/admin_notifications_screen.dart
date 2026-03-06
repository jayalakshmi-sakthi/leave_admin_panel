import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';
import '../../utils/admin_helpers.dart';
// import '../../routes/app_routes.dart'; // 🔴 Removed to fix circular dependency

class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: Colors.grey[50], // Admin Panel Background
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Colors.blue),
            onPressed: () => NotificationService().markAllAsRead(user.uid),
            tooltip: "Mark all as read",
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NotificationService().streamNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.notifications_off_rounded, size: 64, color: Colors.grey[300]),
                   const SizedBox(height: 16),
                   Text("No notifications yet", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
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
                    
                    // Admin Palette
                    Color color = Colors.indigo; 
                    IconData icon = Icons.info_outline;

                    if (title.toLowerCase().contains('request') || leaveType.isNotEmpty) {
                       if (leaveType == 'CL') { color = Colors.orange; icon = Icons.article_outlined; }
                       else if (leaveType == 'OD') { color = Colors.blue; icon = Icons.directions_walk; }
                       else if (leaveType == 'COMP') { color = Colors.purple; icon = Icons.stars_rounded; }
                       else { color = Colors.indigo; icon = Icons.assignment_late_outlined; }
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
                                 // Determine functionality
                                 if (leaveType == 'COMP' || leaveType == 'Comp-Off Earn') {
                                   // Fetch Comp-Off
                                   final doc = await FirebaseFirestore.instance
                                       .collection('compOffRequests') 
                                       .doc(relatedId)
                                       .get();

                                   if (doc.exists && context.mounted) {
                                      Navigator.pushNamed(
                                        context, 
                                        '/admin/comp-off-details',
                                        arguments: {'docId': relatedId, 'data': doc.data()}
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

                                   final doc = await FirebaseFirestore.instance
                                       .collection('leaveRequests')
                                       .doc(relatedId)
                                       .get();

                                   if (doc.exists && context.mounted) {
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
                               Navigator.pushNamed(context, '/pending-users');
                            } else {
                               // Default Fallback
                               Navigator.pushNamed(context, '/leave-requests'); 
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isRead ? Colors.white.withOpacity(0.6) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isRead ? Colors.grey[300]! : color.withOpacity(0.5), width: isRead ? 1 : 2),
                              boxShadow: isRead ? [] : [
                                BoxShadow(color: color.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                              ]
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, color: color),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(AdminHelpers.sanitizeLabel(title), style: TextStyle(fontWeight: isRead ? FontWeight.w600 : FontWeight.bold, fontSize: 15))),
                                          if (!isRead)
                                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(AdminHelpers.sanitizeLabel(body), style: TextStyle(color: Colors.grey[700], height: 1.3)),
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
