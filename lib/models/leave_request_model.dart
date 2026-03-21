import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequestModel {
  final String id;
  final String userId;
  final String userName; // Denormalized for easier display
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final double numberOfDays;
  final String reason;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final DateTime createdAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final bool isHalfDay;
  final String? halfDaySession; // 'FN' or 'AN'
  final String? signedFormUrl;
  final String? finalSignedFormUrl;
  final String? employeeId;
  final String? academicYearId;
  final String? department; 
  final String? applicationId; // ✅ Added

  LeaveRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.numberOfDays,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.approvedBy,
    this.approvedAt,
    this.isHalfDay = false,
    this.halfDaySession,
    this.signedFormUrl,
    this.finalSignedFormUrl,
    this.employeeId,
    this.academicYearId,
    this.department, 
    this.applicationId, // ✅ ADDED
  });

  factory LeaveRequestModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic d) {
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return LeaveRequestModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      employeeId: data['employeeId'],
      leaveType: data['leaveType'] ?? 'Leave',
      fromDate: parseDate(data['fromDate']),
      toDate: parseDate(data['toDate']),
      numberOfDays: (data['numberOfDays'] ?? 0).toDouble(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'Pending',
      createdAt: parseDate(data['createdAt']),
      approvedBy: data['approvedBy'],
      approvedAt: data['approvedAt'] != null ? parseDate(data['approvedAt']) : null,
      isHalfDay: data['isHalfDay'] ?? false,
      halfDaySession: data['halfDaySession'],
      signedFormUrl: data['signedFormUrl'],
      finalSignedFormUrl: data['finalSignedFormUrl'],
      academicYearId: data['academicYearId'],
      department: data['department'], 
      applicationId: data['applicationId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'employeeId': employeeId,
      'department': department, // ✅ Added
      'leaveType': leaveType,
      'fromDate': fromDate,
      'toDate': toDate,
      'numberOfDays': numberOfDays,
      'reason': reason,
      'status': status,
      'createdAt': createdAt,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
      'isHalfDay': isHalfDay,
      'halfDaySession': halfDaySession,
      'signedFormUrl': signedFormUrl,
      'finalSignedFormUrl': finalSignedFormUrl,
      'academicYearId': academicYearId,
      'applicationId': applicationId, // ✅ Added
    };
  }
}
