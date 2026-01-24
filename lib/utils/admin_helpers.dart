import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminHelpers {
  // --- Date Formatting ---
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  // --- Leave Type UI (Integrity) ---

  static IconData getLeaveIcon(String type) {
    switch (type.toUpperCase()) {
      case 'CL': return Icons.person;
      case 'VL': return Icons.beach_access;
      case 'COMP': return Icons.stars_rounded;
      case 'OD': return Icons.business_center;
      case 'SL': return Icons.local_hospital;
      default: return Icons.event_note_rounded;
    }
  }

  static Color getLeaveColor(String type) {
    switch (type.toUpperCase()) {
      case 'CL': return const Color(0xFF3399CC); // KEC Blue
      case 'VL': return const Color(0xFF8CC63F); // KEC Green
      case 'COMP': return Colors.purple;
      case 'OD': return Colors.indigo;
      case 'SL': return Colors.red;
      default: return Colors.blueGrey;
    }
  }

  static String getLeaveName(String type) {
    switch (type.toUpperCase()) {
      case 'CL': return "Casual Leave";
      case 'VL': return "Vacation Leave";
      case 'COMP': return "Comp Off";
      case 'OD': return "On Duty";
      case 'SL': return "Sick Leave";
      default: return type;
    }
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return const Color(0xFF8CC63F); // KEC Green
      case 'rejected': return const Color(0xFFEF4444); // Red
      case 'pending': return const Color(0xFFF59E0B); // Amber
      default: return const Color(0xFF64748B); // Slate
    }
  }
}
