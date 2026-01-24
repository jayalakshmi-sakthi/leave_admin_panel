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
  final String? finalSignedFormUrl; // ✅ Added
  final String? employeeId;

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
    this.finalSignedFormUrl, // ✅ Added
    this.employeeId,
  });

  factory LeaveRequestModel.fromMap(Map<String, dynamic> data, String id) {
    return LeaveRequestModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      employeeId: data['employeeId'], // ✅ Added
      leaveType: data['leaveType'] ?? 'Leave',
      fromDate: (data['fromDate'] as Timestamp).toDate(),
      toDate: (data['toDate'] as Timestamp).toDate(),
      numberOfDays: (data['numberOfDays'] ?? 0).toDouble(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'Pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      approvedBy: data['approvedBy'],
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      isHalfDay: data['isHalfDay'] ?? false,
      halfDaySession: data['halfDaySession'],
      signedFormUrl: data['signedFormUrl'],
      finalSignedFormUrl: data['finalSignedFormUrl'], // ✅ Added
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'employeeId': employeeId,
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
      'finalSignedFormUrl': finalSignedFormUrl, // ✅ Added
    };
  }
}
