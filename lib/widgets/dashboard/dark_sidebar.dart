import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/admin_helpers.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class DarkSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isDesktop;
  final String? profilePicUrl; // ✅ Added

  const DarkSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isDesktop,
    this.profilePicUrl, // ✅ Added
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AdminHelpers.border)),
      ),
      child: Column(
        children: [
          // 1. Header (Logo)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: AdminHelpers.primaryColor, size: 32), // Using Icon as fallback if asset missing
                const SizedBox(width: 12),
                const Text(
                  "LeaveX",
                  style: TextStyle(
                    color: AdminHelpers.textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // 2. Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSectionLabel("MENU"),
                _buildNavItem(0, "Dashboard", Icons.grid_view),
                _buildNavItem(1, "Employees", Icons.group),
                _buildNavItem(2, "On-Duty", Icons.business),
                _buildNavItem(3, "Comp-Off", Icons.grade),
                
                const SizedBox(height: 24),
                _buildSectionLabel("COMMUNICATION"),
                _buildNavItem(4, "Notifications", Icons.notifications),
                _buildNavItem(5, "Department Calendar", Icons.calendar_month),
                
                const SizedBox(height: 24),
                _buildSectionLabel("SYSTEM"),
                _buildNavItem(6, "Settings", Icons.settings),
              ],
            ),
          ),

          // 3. User Profile (Bottom)
          _buildUserProfile(),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AdminHelpers.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final bool isSelected = selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AdminHelpers.primaryColor.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: AdminHelpers.primaryColor.withOpacity(0.1)) : null,
      ),
      child: ListTile(
        onTap: () => onItemSelected(index),
        leading: Icon(
          icon,
          color: isSelected ? AdminHelpers.primaryColor : AdminHelpers.textMuted,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AdminHelpers.primaryColor : AdminHelpers.textMain,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
      ),
    );
  }

  Widget _buildUserProfile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: StreamBuilder<UserModel>(
        stream: FirestoreService().getUserStream(FirebaseAuth.instance.currentUser?.uid ?? ''),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final name = user?.name ?? "Admin User";
          final isSuperAdmin = user?.role == 'super_admin';
          final department = isSuperAdmin ? "Super Admin" : (user?.department ?? "General");
          final finalProfilePic = profilePicUrl ?? user?.profilePicUrl;
          final hasPic = finalProfilePic != null && finalProfilePic.isNotEmpty;

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AdminHelpers.primaryColor.withOpacity(0.1), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        backgroundImage: hasPic ? NetworkImage(finalProfilePic) : null,
                        child: !hasPic ? const Icon(Icons.person_rounded, size: 20, color: AdminHelpers.primaryColor) : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            department,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSuperAdmin ? AdminHelpers.success : AdminHelpers.getDeptColor(department)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => onItemSelected(-1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.1)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: 14, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          "Sign Out",
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}

