import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/leave_request_model.dart';

/// ============================================================
/// FirestoreService — Performance-Optimized + Department-Isolated
/// ============================================================
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ──────────────────────────────────────────────────────────
  // 🚀 IN-MEMORY CACHES (avoid repeat network calls)
  // ──────────────────────────────────────────────────────────
  static final Map<String, Map<String, dynamic>> _settingsCache = {};
  static final Map<String, List<String>> _academicYearsCache = {};
  static final Map<String, List<Map<String, dynamic>>> _leaveTypesCache = {};
  static String? _cachedAdminUid;
  static String? _cachedAdminDept;

  // ──────────────────────────────────────────────────────────
  // 👤 ADMIN — Department Resolution (cached)
  // ──────────────────────────────────────────────────────────
  Future<String?> getAdminDepartment(String adminUid) async {
    if (_cachedAdminUid == adminUid && _cachedAdminDept != null) {
      return _cachedAdminDept;
    }
    try {
      final doc = await _db.collection('users').doc(adminUid).get();
      if (doc.exists) {
        _cachedAdminUid = adminUid;
        final data = doc.data() as Map<String, dynamic>?;
        _cachedAdminDept = (data?['department'] as String?)?.trim();
        return _cachedAdminDept;
      }
    } catch (e) {
      debugLog('getAdminDepartment error: $e');
    }
    return null;
  }

  static void clearCache() {
    _settingsCache.clear();
    _academicYearsCache.clear();
    _leaveTypesCache.clear();
    _cachedAdminUid = null;
    _cachedAdminDept = null;
  }

  // ──────────────────────────────────────────────────────────
  // 👥 EMPLOYEES (Department-scoped)
  // ──────────────────────────────────────────────────────────

  Stream<List<UserModel>> getEmployeesStream({required String department}) {
    Query query = _db.collection('users').where('role', isEqualTo: 'staff');
    if (department != 'All') {
      query = query.where('department', isEqualTo: department);
    }
    return query
        .limit(200)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                return UserModel.fromMap(data, doc.id);
              } catch (e) {
                debugLog('Error parsing user ${doc.id}: $e');
                return null;
              }
            })
            .whereType<UserModel>()
            .toList());
  }

  Stream<UserModel> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) throw Exception('User not found');
      final data = doc.data() as Map<String, dynamic>;
      return UserModel.fromMap(data, doc.id);
    });
  }

  Future<void> updateEmployeeId(String uid, String newEmployeeId) async {
    await _db.collection('users').doc(uid).update({'employeeId': newEmployeeId});
  }

  Future<void> approveUser(String uid, String adminId) async {
    await _db.collection('users').doc(uid).update({
      'approved': true,
      'approvedBy': adminId,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserLeaveOverrides(
      String uid, Map<String, double> overrides) async {
    await _db.collection('users').doc(uid).update({'leaveOverrides': overrides});
  }

  // ──────────────────────────────────────────────────────────
  // 📝 LEAVE REQUESTS (Department-scoped)
  // ──────────────────────────────────────────────────────────

  Stream<List<LeaveRequestModel>> getLeaveRequestsStream({
    required String department,
    String? statusFilter,
    String? academicYearId,
  }) {
    Query query;
    if (department == 'All') {
      query = _db.collectionGroup('records').limit(200);
    } else {
      query = _db
          .collection('leaveRequests')
          .doc(department)
          .collection('records')
          .limit(100);
    }

    if (academicYearId != null && academicYearId != 'All') {
      query = query.where('academicYearId', isEqualTo: academicYearId);
    }

    return query.snapshots().map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => LeaveRequestModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (statusFilter != null && statusFilter != 'All') {
        return requests.where((r) => r.status == statusFilter).toList();
      }
      return requests;
    });
  }

  Stream<List<LeaveRequestModel>> getEmployeeLeaveHistory(
      String userId, String department) {
    return _db
        .collection('leaveRequests')
        .doc(department)
        .collection('records')
        .where('userId', isEqualTo: userId)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => LeaveRequestModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return docs;
    });
  }

  Future<void> updateLeaveStatus(
    String requestId,
    String status,
    String adminId, {
    required String department,
  }) async {
    final docRef = _db
        .collection('leaveRequests')
        .doc(department)
        .collection('records')
        .doc(requestId);

    await docRef.update({
      'status': status,
      'approvedBy': adminId,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    if (status == 'Approved') {
      try {
        final doc = await docRef.get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final leaveType = data['leaveType'];
          if (leaveType == 'Comp-Off Earn' || leaveType == 'Comp-Off Earned') {
            final userId = data['userId'];
            final days = data['numberOfDays'] as num;
            final academicYearId = data['academicYearId'];
            final reason = data['reason'];
            await _db
                .collection('departments')
                .doc(department)
                .collection('compOffGrants')
                .add({
              'userId': userId,
              'days': days.toDouble(),
              'academicYearId': academicYearId,
              'reason': 'Approved: $reason',
              'sourceRequestId': requestId,
              'grantedAt': FieldValue.serverTimestamp(),
              'grantedBy': adminId,
            });
          }
        }
      } catch (e) {
        debugLog('Failed to create Comp Off Grant: $e');
      }
    }
  }

  Future<void> updateCompOffStatus(
      String requestId, String status, String adminId,
      {required String department, required Map<String, dynamic> data}) async {
    final docRef = _db
        .collection('compOffRequests')
        .doc(department)
        .collection('records')
        .doc(requestId);

    await docRef.update({
      'status': status,
      'approvedBy': adminId,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    if (status == 'Approved') {
      try {
        final userId = data['userId'];
        final days = data['days'] as num;
        final academicYearId = data['academicYearId'];
        final description = data['description'];

        await _db
            .collection('departments')
            .doc(department)
            .collection('compOffGrants')
            .add({
          'userId': userId,
          'days': days.toDouble(),
          'academicYearId': academicYearId,
          'reason': 'Approved Comp-Off Earn: $description',
          'sourceRequestId': requestId,
          'grantedAt': FieldValue.serverTimestamp(),
          'grantedBy': adminId,
        });
      } catch (e) {
        debugLog('Failed to grant comp-off: $e');
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  // ⚙️ SETTINGS & CONFIG
  // ──────────────────────────────────────────────────────────

  String getCurrentAcademicYearString() {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  Future<List<String>> getAcademicYears({required String department}) async {
    final doc = await _db.collection('departments').doc(department).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final years = (data['academicYears'] as List<dynamic>?)?.cast<String>() ?? [];
      if (years.isNotEmpty) return years;
    }
    return [getCurrentAcademicYearString()];
  }

  Future<Map<String, dynamic>> getAcademicYearSettings({required String department}) async {
    final doc = await _db.collection('departments').doc(department).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'label': data['currentAcademicYear'] ?? getCurrentAcademicYearString(),
        'start': data['academicYearStart'],
        'end': data['academicYearEnd'],
      };
    }
    return {'label': getCurrentAcademicYearString()};
  }

  Future<void> setAcademicYearSettings(
      {required String department, required Map<String, dynamic> data}) async {
    await _db.collection('departments').doc(department).set({
      'currentAcademicYear': data['label'],
      'academicYearStart': data['start'],
      'academicYearEnd': data['end'],
      'settingsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getLeaveTypes({required String department}) async {
    final doc = await _db.collection('departments').doc(department).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final types = (data['leaveTypes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      if (types.isNotEmpty) return types;
    }
    return [
      {'name': 'CL', 'days': 12},
      {'name': 'VL', 'days': 6},
      {'name': 'OD', 'days': 10},
    ];
  }

  Future<void> setLeaveTypes(
      {required String department, required List<Map<String, dynamic>> types}) async {
    await _db.collection('departments').doc(department).set({
      'leaveTypes': types,
      'settingsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, double>> getCompOffStats(String userId, String academicYear,
      {required String department}) async {
    try {
      final results = await Future.wait([
        _db.collection('departments').doc(department).collection('compOffGrants').where('userId', isEqualTo: userId).where('academicYearId', isEqualTo: academicYear).get(),
        _db.collectionGroup('records').where('userId', isEqualTo: userId).where('academicYearId', isEqualTo: academicYear).get()
      ]);

      double totalGranted = 0.0;
      for (var d in results[0].docs) {
        final data = d.data() as Map<String, dynamic>;
        totalGranted += (data['days'] ?? 0.0) as double;
      }

      double totalUsed = 0.0;
      for (var d in results[1].docs) {
        final data = d.data() as Map<String, dynamic>;
        if (data['leaveType'] == 'COMP' && data['status'] != 'Rejected') {
           totalUsed += (data['numberOfDays'] ?? 0.0) as double;
        }
      }

      return {'limit': totalGranted, 'used': totalUsed};
    } catch (e) {
      return {'limit': 0.0, 'used': 0.0};
    }
  }

  // ──────────────────────────────────────────────────────────
  // 📊 DASHBOARD COUNTS
  // ──────────────────────────────────────────────────────────

  Stream<int> getPendingLeaveCount({required String department}) {
    if (department == 'All') {
      return _db.collectionGroup('records').where('status', isEqualTo: 'Pending').snapshots().map((snap) => snap.docs.length);
    }
    return _db.collection('leaveRequests').doc(department).collection('records').where('status', isEqualTo: 'Pending').snapshots().map((snap) => snap.docs.length);
  }

  Stream<int> getPendingCompOffCount({required String department}) {
    if (department == 'All') {
       return _db.collectionGroup('records').where('leaveType', isEqualTo: 'Comp-Off Earn').where('status', isEqualTo: 'Pending').snapshots().map((snap) => snap.docs.length);
    }
    return _db.collection('leaveRequests').doc(department).collection('records').where('leaveType', isEqualTo: 'Comp-Off Earn').where('status', isEqualTo: 'Pending').snapshots().map((snap) => snap.docs.length);
  }

  Stream<int> getPendingOnDutyCount({required String department}) {
    if (department == 'All') {
       return _db.collectionGroup('records').where('leaveType', isEqualTo: 'OD').where('status', isEqualTo: 'Pending').snapshots().map((snap) => snap.docs.length);
    }
    return _db.collection('leaveRequests').doc(department).collection('records').where('leaveType', isEqualTo: 'OD').where('status', isEqualTo: 'Pending').snapshots().map((snap) => snap.docs.length);
  }

  Stream<int> getPendingUserCount() {
    return _db.collection('users').where('approved', isEqualTo: false).where('role', isEqualTo: 'staff').snapshots().map((snap) => snap.docs.length);
  }

  void debugLog(String msg) => print('🔥 FirestoreService: $msg');
}
