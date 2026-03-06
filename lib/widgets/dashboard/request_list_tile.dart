import 'package:flutter/material.dart';
import '../../utils/admin_helpers.dart'; // For colors

class RequestListTile extends StatelessWidget {
  final String name;
  final String rollNo;
  final String leaveType;
  final String dateRange;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final String? profilePic;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const RequestListTile({
    super.key,
    required this.name,
    required this.rollNo,
    required this.leaveType,
    required this.dateRange,
    required this.status,
    this.profilePic,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPending = status == 'Pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AdminHelpers.scaffoldBg,
          backgroundImage: profilePic != null ? NetworkImage(profilePic!) : null,
          child: profilePic == null 
            ? Text(name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AdminHelpers.textMain))
            : null,
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminHelpers.textMain),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AdminHelpers.getLeaveColor(leaveType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                leaveType,
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.w600, 
                  color: AdminHelpers.getLeaveColor(leaveType)
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text("$dateRange • $rollNo", style: const TextStyle(fontSize: 12, color: AdminHelpers.textMuted)),
          ],
        ),
        trailing: isPending 
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionButton(
                  icon: Icons.check_rounded, 
                  color: AdminHelpers.success, 
                  onTap: onApprove,
                  tooltip: "Approve",
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.close_rounded, 
                  color: AdminHelpers.danger, 
                  onTap: onReject,
                  tooltip: "Reject",
                ),
              ],
            )
          : _StatusBadge(status: status),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionButton({required this.icon, required this.color, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Approved': color = AdminHelpers.success; break;
      case 'Rejected': color = AdminHelpers.danger; break;
      default: color = AdminHelpers.warning;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
