import 'package:flutter_test/flutter_test.dart';
import 'package:leave_admin_panel/models/leave_request_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Mock Timestamp for testing
class MockTimestamp extends Timestamp {
  final DateTime _date;
  MockTimestamp(this._date) : super(_date.millisecondsSinceEpoch ~/ 1000, (_date.millisecondsSinceEpoch % 1000) * 1000000);
  
  @override
  DateTime toDate() => _date;
}

void main() {
  group('LeaveRequestModel Tests (Admin)', () {
    final DateTime now = DateTime.now();
    final Timestamp nowTs = MockTimestamp(now);

    test('should correctly deserialize department field from Firestore Data', () {
      final map = {
        'userId': 'user_123',
        'userName': 'John Doe',
        'leaveType': 'CL',
        'fromDate': nowTs,
        'toDate': nowTs,
        'numberOfDays': 1.0,
        'reason': 'Sick',
        'status': 'Pending',
        'createdAt': nowTs,
        'department': 'CSE', // ✅ Testing this
      };

      final leave = LeaveRequestModel.fromMap(map, 'doc_id_123');

      expect(leave.department, 'CSE');
      expect(leave.id, 'doc_id_123');
      expect(leave.userName, 'John Doe');
    });

    test('should return null for department if missing (Legacy Data)', () {
      final map = {
        'userId': 'user_456',
        'userName': 'Jane Doe',
        'leaveType': 'VL',
        'fromDate': nowTs,
        'toDate': nowTs,
        'numberOfDays': 2.0,
        'reason': 'Vacation',
        'status': 'Approved',
        'createdAt': nowTs,
        // 'department' missing
      };

      final leave = LeaveRequestModel.fromMap(map, 'doc_id_456');

      expect(leave.department, null);
      expect(leave.userName, 'Jane Doe');
    });
  });
}
