import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/leave_request_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --------------------------------------------------
  // 👥 USERS (EMPLOYEES)
  // --------------------------------------------------

  /// Get stream of all employees (role = staff)
  /// Optionally filter by department
  Stream<List<UserModel>> getEmployeesStream({String? departmentFilter}) {
    Query query = _db.collection('users').where('role', isEqualTo: 'staff');

    if (departmentFilter != null && departmentFilter.isNotEmpty && departmentFilter != 'All') {
      query = query.where('department', isEqualTo: departmentFilter);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Get single user details
  Stream<UserModel> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        throw Exception("User not found");
      }
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  /// Update Employee ID for meaningful institutional identity
  Future<void> updateEmployeeId(String uid, String newEmployeeId) async {
    await _db.collection('users').doc(uid).update({
      'employeeId': newEmployeeId,
    });
  }

  // --------------------------------------------------
  // 📝 LEAVE REQUESTS (PRODUCTION QUALITY)
  // --------------------------------------------------

  String _getAcademicYear() {
    final now = DateTime.now();
    // Academic year starts in June (month 6)
    int startYear = now.month >= 6 ? now.year : now.year - 1;
    return "$startYear-${startYear + 1}";
  }

  String _getLeaveCollectionName() {
    return 'leaveRequests';
  }

  /// Get stream of leave requests for the specified academic year
  Stream<List<LeaveRequestModel>> getLeaveRequestsStream({String? statusFilter, String? academicYearId}) {
    final collectionName = _getLeaveCollectionName();
    
    Query query = _db.collection(collectionName);

    if (academicYearId != null && academicYearId != 'All') {
      query = query.where('academicYearId', isEqualTo: academicYearId);
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map((snapshot) {
      final requests = snapshot.docs.map((doc) {
        return LeaveRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      if (statusFilter != null && statusFilter != 'All') {
        return requests.where((r) => r.status == statusFilter).toList();
      }
      return requests;
    });
  }

  /// Get distinct academic years from the leaveRequests collection
  Future<List<String>> getAcademicYears() async {
    final snapshot = await _db.collection(_getLeaveCollectionName()).get();
    final years = snapshot.docs
        .map((doc) => doc.data()['academicYearId'] as String?)
        .where((y) => y != null)
        .toSet()
        .toList();
    years.sort((a, b) => b!.compareTo(a!)); // Recent first
    return years.cast<String>();
  }

  /// Get leave history for a specific employee
  Stream<List<LeaveRequestModel>> getEmployeeLeaveHistory(String userId) {
    // Note: This currently only gets history for the CURRENT academic year.
    // If you need global history, you'd need a collection group query or multiple queries.
    return _db.collection(_getLeaveCollectionName())
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          return LeaveRequestModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
  }

  /// Update Leave Status efficiently
  Future<void> updateLeaveStatus(String requestId, String status, String adminId) async {
    await _db.collection(_getLeaveCollectionName()).doc(requestId).update({
      'status': status,
      'approvedBy': adminId,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }
}

