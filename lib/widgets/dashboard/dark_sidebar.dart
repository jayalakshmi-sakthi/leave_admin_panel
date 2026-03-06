import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/admin_helpers.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class DarkSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isDesktop;

  const DarkSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AdminHelpers.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(4, 0),
          )
        ],
      ),
      child: Column(
        children: [
          // 1. Header (Logo)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Row(
              children: [
                Image.asset('assets/logo.png', width: 32, height: 32),
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
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AdminHelpers.border)),
      ),
      child: StreamBuilder<UserModel>(
        stream: FirestoreService().getUserStream(FirebaseAuth.instance.currentUser?.uid ?? ''),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final name = user?.name ?? "Admin User";
          final email = user?.email ?? "";
          
          return Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AdminHelpers.primaryColor.withOpacity(0.1),
                backgroundImage: user?.profilePicUrl != null ? NetworkImage(user!.profilePicUrl!) : null,
                child: user?.profilePicUrl == null 
                  ? const Icon(Icons.person, color: AdminHelpers.primaryColor, size: 18) 
                  : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: AdminHelpers.textMain, fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      email,
                      style: const TextStyle(color: AdminHelpers.textMuted, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AdminHelpers.textMuted, size: 20),
                onPressed: () => FirebaseAuth.instance.signOut(),
                tooltip: "Logout",
              )
            ],
          );
        }
      ),
    );
  }
}
