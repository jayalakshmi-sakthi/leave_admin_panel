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
        _cachedAdminDept = (doc.data()?['department'] as String?)?.trim();
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
  // 👥 EMPLOYEES (Department-scoped, limited)
  // ──────────────────────────────────────────────────────────

  Stream<List<UserModel>> getEmployeesStream({required String department}) {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'staff')
        .where('department', isEqualTo: department)
        .limit(200) // Prevent full-scan reads
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                return UserModel.fromMap(doc.data(), doc.id);
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
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
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
  // 📝 LEAVE REQUESTS (Department-scoped, limited)
  // ──────────────────────────────────────────────────────────

  Stream<List<LeaveRequestModel>> getLeaveRequestsStream({
    required String department,
    String? statusFilter,
    String? academicYearId,
  }) {
    Query query = _db
        .collection('leaveRequests')
        .doc(department)
        .collection('records')
        .limit(100); // Limit to 100 most recent after in-memory sort

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

  // ──────────────────────────────────────────────────────────
  // 🔀 COMP-OFF REQUESTS
  // ──────────────────────────────────────────────────────────

  Future<void> updateCompOffStatus(
    String requestId,
    String status,
    String adminId, {
    required String department,
    required Map<String, dynamic> data,
  }) async {
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
      final userId = data['userId'];
      final rawDays = data['days'];
      final daysToCheck = rawDays is num
          ? rawDays.toDouble()
          : double.tryParse(rawDays.toString()) ?? 0.0;

      if (daysToCheck > 0) {
        await _db
            .collection('departments')
            .doc(department)
            .collection('compOffGrants')
            .add({
          'userId': userId,
          'days': daysToCheck,
          'sourceRequestId': requestId,
          'academicYearId': data['academicYearId'] ?? getCurrentAcademicYearString(),
          'grantedAt': FieldValue.serverTimestamp(),
          'workedDate': data['workedDate'],
          'reason': data['description'] ?? 'Approved Request',
        });
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  // ⚙️ SETTINGS (Cached to avoid repeat reads)
  // ──────────────────────────────────────────────────────────

  String getCurrentAcademicYearString() {
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }

  Future<Map<String, dynamic>> getAcademicYearSettings(
      {required String department}) async {
    final cacheKey = 'aySettings_$department';
    if (_settingsCache.containsKey(cacheKey)) {
      return _settingsCache[cacheKey]!;
    }
    try {
      final doc = await _db
          .collection('departments')
          .doc(department)
          .collection('settings')
          .doc('academic_year')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        if ((data['label'] as String?)?.isNotEmpty == true) {
          _settingsCache[cacheKey] = data;
          return data;
        }
      }
    } catch (e) {
      debugLog('getAcademicYearSettings error: $e');
    }
    final defaultData = {'label': getCurrentAcademicYearString()};
    _settingsCache[cacheKey] = defaultData;
    return defaultData;
  }

  Future<void> setAcademicYearSettings(
      {required String department, required Map<String, dynamic> data}) async {
    _settingsCache.remove('aySettings_$department'); // Invalidate cache
    await _db
        .collection('departments')
        .doc(department)
        .collection('settings')
        .doc('academic_year')
        .set(data, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getLeaveTypes(
      {required String department}) async {
    if (_leaveTypesCache.containsKey(department)) {
      return _leaveTypesCache[department]!;
    }
    try {
      final doc = await _db
          .collection('departments')
          .doc(department)
          .collection('settings')
          .doc('leave_types')
          .get();
      if (doc.exists) {
        final List<dynamic> types = doc.data()?['types'] ?? [];
        final result = types.cast<Map<String, dynamic>>();
        _leaveTypesCache[department] = result;
        return result;
      }
    } catch (e) {
      debugLog('getLeaveTypes error: $e');
    }
    const defaults = [
      {'name': 'CL', 'days': 12},
      {'name': 'VL', 'days': 6},
      {'name': 'OD', 'days': 10},
    ];
    _leaveTypesCache[department] = defaults;
    return defaults;
  }

  Future<void> setLeaveTypes(
      {required String department,
      required List<Map<String, dynamic>> types}) async {
    _leaveTypesCache.remove(department); // Invalidate cache
    await _db
        .collection('departments')
        .doc(department)
        .collection('settings')
        .doc('leave_types')
        .set({'types': types}, SetOptions(merge: true));
  }

  // ──────────────────────────────────────────────────────────
  // 📅 ACADEMIC YEARS (Cached)
  // ──────────────────────────────────────────────────────────

  Future<List<String>> getAcademicYears({required String department}) async {
    if (_academicYearsCache.containsKey(department)) {
      return _academicYearsCache[department]!;
    }
    try {
      final snapshot = await _db
          .collection('departments')
          .doc(department)
          .collection('academicYears')
          .orderBy('id', descending: true)
          .limit(10)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final years = snapshot.docs.map((doc) => doc.id).toList();
        _academicYearsCache[department] = years;
        return years;
      }
    } catch (e) {
      debugLog('getAcademicYears error: $e');
    }
    return [getCurrentAcademicYearString()];
  }

  // ──────────────────────────────────────────────────────────
  // 📊 COMP-OFF STATS
  // ──────────────────────────────────────────────────────────

  Future<Map<String, double>> getCompOffStats(
      String userId, String academicYear, String department) async {
    double safeParse(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    // Run both reads in parallel
    final results = await Future.wait([
      _db
          .collection('departments')
          .doc(department)
          .collection('compOffGrants')
          .where('userId', isEqualTo: userId)
          .where('academicYearId', isEqualTo: academicYear)
          .limit(50)
          .get(),
      _db
          .collection('leaveRequests')
          .doc(department)
          .collection('records')
          .where('userId', isEqualTo: userId)
          .where('academicYearId', isEqualTo: academicYear)
          .limit(50)
          .get(),
    ]);

    double totalGranted = 0.0;
    for (var d in results[0].docs) {
      totalGranted += safeParse(d.data()['days']);
    }

    double totalUsed = 0.0;
    for (var d in results[1].docs) {
      final data = d.data();
      if ((data['leaveType'] == 'COMP' || data['leaveType'] == 'Comp-Off') &&
          data['status'] != 'Rejected') {
        totalUsed += safeParse(data['numberOfDays']);
      }
    }

    return {'limit': totalGranted, 'used': totalUsed};
  }

  // ──────────────────────────────────────────────────────────
  // 🔔 BADGE COUNTS (Department-scoped, limited)
  // ──────────────────────────────────────────────────────────

  Stream<int> getPendingLeaveCountStream(
      {required String department, String? academicYearId}) {
    Query query = _db
        .collection('leaveRequests')
        .doc(department)
        .collection('records')
        .where('status', isEqualTo: 'Pending')
        .limit(50);

    if (academicYearId != null && academicYearId != 'All') {
      query = query.where('academicYearId', isEqualTo: academicYearId);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .where((doc) =>
            (doc.data() as Map<String, dynamic>)['leaveType'] != 'OD')
        .length);
  }

  Stream<int> getPendingODCountStream(
      {required String department, String? academicYearId}) {
    Query query = _db
        .collection('leaveRequests')
        .doc(department)
        .collection('records')
        .where('status', isEqualTo: 'Pending')
        .where('leaveType', isEqualTo: 'OD')
        .limit(50);

    if (academicYearId != null && academicYearId != 'All') {
      query = query.where('academicYearId', isEqualTo: academicYearId);
    }

    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getPendingCompOffCountStream(
      {required String department, String? academicYearId}) {
    Query query = _db
        .collection('compOffRequests')
        .doc(department)
        .collection('records')
        .where('status', isEqualTo: 'Pending')
        .limit(50);

    if (academicYearId != null && academicYearId != 'All') {
      query = query.where('academicYearId', isEqualTo: academicYearId);
    }

    return query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  // ──────────────────────────────────────────────────────────
  // 🛠 INTERNAL
  // ──────────────────────────────────────────────────────────
  void debugLog(String msg) {
    // ignore: avoid_print
    print('[FirestoreService] $msg');
  }
}
