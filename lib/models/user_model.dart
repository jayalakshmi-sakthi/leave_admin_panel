import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String employeeId;
  final String role; // 'admin' or 'staff'
  final String department;
  final DateTime? createdAt;
  final bool approved; // New: User approval status
  final String? approvedBy; // New: Admin who approved
  final DateTime? approvedAt; // New: Approval timestamp
  final Map<String, double>? leaveOverrides; // New: Personalized leave counts
  final String? manualEmployeeId; // NEW
  final String? designation; // NEW
  final String? profilePicUrl; // ✅ NEW: Profile Picture

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.employeeId,
    required this.role,
    required this.department,
    this.createdAt,
    this.approved = false,
    this.approvedBy,
    this.approvedAt,
    this.leaveOverrides,
    this.manualEmployeeId,
    this.designation,
    this.profilePicUrl, 
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      employeeId: data['employeeId'] ?? "EMP-TEMP",
      role: data['role'] ?? 'staff',
      department: data['department'] ?? 'General',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      approved: data['approved'] ?? true,
      approvedBy: data['approvedBy'],
      approvedAt: data['approvedAt'] is Timestamp
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      leaveOverrides: data['leaveOverrides'] != null 
          ? (data['leaveOverrides'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()))
          : null,
      manualEmployeeId: data['manualEmployeeId'],
      designation: data['designation'],
      profilePicUrl: data['profilePicUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'employeeId': employeeId,
      'role': role,
      'department': department,
      'createdAt': createdAt,
      'approved': approved,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
      'leaveOverrides': leaveOverrides,
      'manualEmployeeId': manualEmployeeId,
      'designation': designation,
      'profilePicUrl': profilePicUrl,
    };
  }
}
