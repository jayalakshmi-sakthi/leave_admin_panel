import 'dart:async';
import 'dart:convert';
import 'dart:js' as js; // ✅ For OneSignal Web Interop
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http; // ✅ For OneSignal REST API
import 'package:onesignal_flutter/onesignal_flutter.dart'; 

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  String? _currentUserId; // ✅ Store current user for token association

  // 🧭 Navigation Stream
  final _navController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get navigationStream => _navController.stream;

  Future<void> init() async {
    // 🔔 ONESIGNAL INIT (Multi-platform)
    const String appId = '76f30b3e-82fb-48cb-8c8a-88cd994e1a1c';

    if (kIsWeb) {
      js.context.callMethod('initOneSignal', [appId]);
    } else {
      OneSignal.initialize(appId);
      OneSignal.Notifications.requestPermission(true);
    }

    // 🌐 WEB DEEP LINK CHECK
    if (kIsWeb) {
      final params = Uri.base.queryParameters;
      if (params.containsKey('type') && params.containsKey('id')) {
        debugPrint("🌐 Admin Web Launch Params Detected: $params");
        // Map URL keys to internal keys
        final mappedData = Map<String, dynamic>.from(params);
        mappedData['relatedId'] = params['id'];
        mappedData['academicYearId'] = params['year'];
        _navController.add(mappedData);
      }
    }
    
    // 6. Local Notifications Init (Mobile/Desktop)
    if (!kIsWeb) {
      try {
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidSettings);

        await _localNotifications.initialize(
          initSettings,
           onDidReceiveNotificationResponse: (details) {
               // Handle navigation from Local Notification
               final payload = details.payload;
               if (payload != null) {
                 try {
                   final data = jsonDecode(payload) as Map<String, dynamic>;
                   debugPrint("🔔 Local Notification Click Payload: $data");
                   _navController.add(data); // Push to stream
                 } catch (e) {
                   debugPrint("Error parsing payload: $e");
                 }
               }
           },
        );

        const channel = AndroidNotificationChannel(
          'admin_alerts_channel',
          'Admin Alerts',
          description: 'Notifications for new leave requests',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

      } catch (e) {
        debugPrint("⚠️ Admin Notification Init Error: $e");
      }
    }
  }
  
  void _handleInteraction(RemoteMessage message) {
    // Parse data to determine navigation
    final data = message.data;
    debugPrint("🔔 FCM Interaction Data: $data");
    _navController.add(data);
  }

  // --- Auth Integration ---
  void setUserId(String? userId) {
    _currentUserId = userId;
    if (userId != null) {
      if (kIsWeb) {
        // 🔗 Link this browser session (Web)
        js.context.callMethod('setOneSignalUser', [userId]);
      } else {
        // 🔗 Link this app session (Mobile/Desktop)
        OneSignal.login(userId);
      }
    }
  }

  Future<void> _saveToken(String? token, String? userId) async {
    if (token == null || userId == null || userId.isEmpty) return;
    try {
      await _db.collection('users').doc(userId).update({
        'fcmToken': token,
        'tokens': FieldValue.arrayUnion([token]), // Keep a list for multi-device
        'lastActive': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ Token saved for user: $userId");
    } catch (e) {
      debugPrint("Error saving token: $e");
    }
  }

  Future<void> notifyAdmins({
    required String title,
    required String body,
    String? type,
    String? relatedId,
    String? leaveType,
    String? academicYearId,
    String? targetDepartment,
    String? triggeringUserId,
  }) async {
    try {
      final sanitizedTarget = targetDepartment?.trim();
      
      // 1. Fetch ALL admins/super_admins
      final adminsSnap = await _db.collection('users')
          .where('role', whereIn: ['admin', 'super_admin'])
          .get();
      
      final Set<String> recipientIds = {};

      for (var doc in adminsSnap.docs) {
          if (doc.id == triggeringUserId) continue;

          final data = doc.data();
          final String role = data['role'] ?? 'staff';
          final String? adminDept = (data['department'] as String?)?.trim();
          
          bool shouldNotify = false;

          // A. Super Admins (Always get everything)
          if (role == 'super_admin') {
            shouldNotify = true;
          } 
          // B. Department Admins
          else if (role == 'admin') {
            if (adminDept == 'All') {
              shouldNotify = true;
            } else if (sanitizedTarget != null && adminDept?.toLowerCase() == sanitizedTarget.toLowerCase()) {
              shouldNotify = true;
            } else if (sanitizedTarget == null && adminDept == null) {
              // Global notification, no target, and admin has no specific dept (Generalist)
              shouldNotify = true;
            }
          }

          if (shouldNotify) recipientIds.add(doc.id);
      }

      // Send to identified recipients
      for (var uid in recipientIds) {
        await sendNotification(
          toUserId: uid,
          title: title,
          body: body,
          type: type,
          relatedId: relatedId,
          leaveType: leaveType,
          academicYearId: academicYearId,
          targetDepartment: targetDepartment,
        );
      }
    } catch (e) {
      debugPrint("NotifyAdmins Error: $e");
    }
  }

  // 🔔 UI Notification Stream (For real-time floating alerts)
  final _uiController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get uiNotificationStream => _uiController.stream;

  // --- Firestore Listeners (Legacy/Real-time) ---
  void listenForNewNotifications(String userId) {
    if (userId.isEmpty) return;
    
    _db.collection('notifications')
       .where('toUserId', isEqualTo: userId)
       .where('isRead', isEqualTo: false)
       .snapshots()
       .listen((snap) {
         for (var change in snap.docChanges) {
           if (change.type == DocumentChangeType.added) {
             final data = change.doc.data();
             final rawCreatedAt = data?['createdAt'];
             final createdAt = (rawCreatedAt is Timestamp) 
                 ? rawCreatedAt.toDate() 
                 : (rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null);
             
             // Only show if received in the last 10 seconds (real-time enough)
             final isRecent = createdAt != null && createdAt.isAfter(DateTime.now().subtract(const Duration(seconds: 10)));
             
             if (isRecent) {
               // 1. Show Local Notification (Android/iOS)
               if (!kIsWeb) {
                 showLocalNotification(
                   id: change.doc.id.hashCode,
                   title: data?['title'] ?? 'New Alert',
                   body: data?['body'] ?? '',
                   payload: jsonEncode(data), 
                 );
               }

               // 2. Broadcast to UI (Web/Desktop/Mobile) for real-time floating overlay
               _uiController.add(data ?? {});
             }
           }
         }
       });
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    try {
      final androidDetails = const AndroidNotificationDetails(
        'admin_alerts_channel',
        'Admin Alerts',
        importance: Importance.max,
        priority: Priority.max,
        color: Color(0xFF7C3AED),
        timeoutAfter: 5000, // ✅ Auto-dismiss after 5 seconds
      );
      final details = NotificationDetails(android: androidDetails);
      await _localNotifications.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint("Local Notification Error: $e");
    }
  }

  Future<void> sendNotification({
    required String toUserId,
    required String title,
    required String body,
    String? type,
    String? relatedId, // e.g., leaveId
    String? leaveType, // e.g., CL, VL, OD
    String? academicYearId,
    String? targetDepartment, // ✅ Added for filtering
  }) async {
    try {
      // 1. Save to Firestore (Real-time DB)
      await _db.collection('notifications').add({
        'toUserId': toUserId,
        'title': title,
        'body': body,
        'type': type ?? 'status_change',
        'relatedId': relatedId,
        'leaveType': leaveType,
        'academicYearId': academicYearId,
        'targetDepartment': targetDepartment, // ✅ Added for filtering
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Trigger OneSignal Push (Background/System Tray)
      await sendOneSignalPush(
        toUserId: toUserId,
        title: title,
        body: body,
        data: {
          'type': type ?? 'status_change',
          'relatedId': relatedId ?? '',
          'leaveType': leaveType ?? '',
          'academicYearId': academicYearId ?? '',
          'targetDepartment': targetDepartment ?? '',
        },
      );
    } catch (e) {
      debugPrint("Error sending notification: $e");
    }
  }

  /// 🔔 REST API call to OneSignal (Free Layer 2)
  Future<void> sendOneSignalPush({
    required String toUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // NOTE: You must paste your REST API Key here (from your screenshot)
      const String onesignalRestKey = "os_v2_app_xxxxxxxxxxxxxxxxxxxxxxxxxxx"; // TODO: PASTE LEGACY API KEY HERE
      const String appId = "76f30b3e-82fb-48cb-8c8a-88cd994e1a1c";

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $onesignalRestKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'include_external_user_ids': [toUserId], // Targeting the specific person
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data,
          // Web specific tweaks
          'web_url': 'https://leave-management-app-f07b8.web.app/#/notifications', // Fallback URL
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("🚀 OneSignal Push Sent Successfully to $toUserId");
      } else {
        debugPrint("❌ OneSignal Error (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      debugPrint("OneSignal Push Exception: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> streamNotifications(String userId, {String? departmentFilter}) {
    Query query = _db
        .collection('notifications')
        .where('toUserId', isEqualTo: userId);
        
    if (departmentFilter != null && departmentFilter != 'All') {
      query = query.where('targetDepartment', isEqualTo: departmentFilter);
    }

    return query
        .limit(50)
        .snapshots()
        .map((snap) {
          final List<Map<String, dynamic>> notifications = snap.docs.map((d) {
            final Map<String, dynamic> data = Map<String, dynamic>.from(d.data() as Map);
            data['id'] = d.id;
            return data;
          }).toList();

          DateTime parseDate(dynamic d) {
            if (d is Timestamp) return d.toDate();
            if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
            return DateTime.now();
          }
          
          notifications.sort((a, b) {
            final aTime = parseDate(a['createdAt']);
            final bTime = parseDate(b['createdAt']);
            return bTime.compareTo(aTime);
          });
          
          return notifications;
        });
  }

  Stream<int> getUnreadCount(String userId, {String? departmentFilter}) {
    if (userId.isEmpty) return Stream.value(0);
    
    Query query = _db
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false);
        
    if (departmentFilter != null && departmentFilter != 'All') {
      // Note: This relies on targetDepartment being present in the document.
      // If we want to show global notifications (targetDepartment == null) even in isolated view,
      // we'd need a more complex query or in-memory filtering. 
      // For now, let's keep it strictly isolated to the department.
      query = query.where('targetDepartment', isEqualTo: departmentFilter);
    }
    
    return query.snapshots().map((snap) => snap.docs.length);
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint("Error marking read: $e");
    }
  }
  
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _db.batch();
      final snap = await _db.collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
          
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking all as read: $e");
    }
  }
  
  Future<void> sendLeaveStatusNotification({
    required String userId,
    required String status,
    required String leaveType,
    required DateTime fromDate,
  }) async {
    final dateStr = DateFormat('MMM dd, yyyy').format(fromDate);
    await sendNotification(
      toUserId: userId,
      title: 'Leave $status',
      body: 'Your $leaveType request for $dateStr has been $status.',
      type: 'status_change',
    );
  }
}
