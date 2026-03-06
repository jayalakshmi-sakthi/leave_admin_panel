import 'package:flutter/material.dart';
import '../../utils/admin_helpers.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../routes/app_routes.dart';
import '../../widgets/responsive_container.dart';
import 'package:shimmer/shimmer.dart';

class EmployeesScreen extends StatefulWidget {
  final String? adminDepartment;
  const EmployeesScreen({super.key, this.adminDepartment});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _selectedStatus = 'All'; // New Filter

  // 🎨 Theme
  // Using AdminHelpers constants directly
  static const Color primaryBlue = AdminHelpers.secondaryColor; // Mapped to secondary for actionable logic

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // 🖥 UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      child: Column(
        children: [
          _buildSearchAndFilter(),
          _buildEmployeeList(),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 🔍 SEARCH & FILTER
  // --------------------------------------------------
  // --------------------------------------------------
  // 🔍 SEARCH & FILTER
  // --------------------------------------------------
  Widget _buildSearchAndFilter() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1.5)),
      ),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchText = value.toLowerCase());
              },
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              decoration: InputDecoration(
                hintText: "Search name or email...",
                hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: theme.iconTheme.color, size: 20),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AdminHelpers.secondaryColor, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Status Dropdown
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  dropdownColor: theme.cardColor,
                  icon: Icon(Icons.filter_list_rounded, color: theme.iconTheme.color, size: 18),
                  items: ['All', 'Pending', 'Approved'].map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedStatus = value);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 👥 EMPLOYEE LIST (REAL-TIME)
  // --------------------------------------------------
  Widget _buildEmployeeList() {
    final theme = Theme.of(context);
    
    return Expanded(
      child: StreamBuilder<List<UserModel>>(
        stream: _firestoreService.getEmployeesStream(department: widget.adminDepartment ?? 'CSE'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonList();
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: theme.textTheme.bodyMedium?.color)));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _emptyState();
          }

          // Client-side search & status filtering
          final employees = snapshot.data!.where((user) {
            final name = user.name.toLowerCase();
            final email = user.email.toLowerCase();
            bool matchesSearch = name.contains(_searchText) || email.contains(_searchText);
            bool matchesStatus = _selectedStatus == 'All' 
                ? true 
                : (_selectedStatus == 'Pending' ? !user.approved : user.approved);
            
            return matchesSearch && matchesStatus;
          }).toList();

          if (employees.isEmpty) {
            return _emptyState();
          }

          return Column(
            children: [
              // 📊 STATS HEADER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                   Text(
                      "All Employees",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Total: ${employees.length}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    return _employeeCard(context, employees[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState() {
     final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 48, color: theme.disabledColor),
          const SizedBox(height: 12),
          Text(
            "No employees found",
            style: TextStyle(color: theme.disabledColor, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 🧑‍💼 EMPLOYEE CARD
  // --------------------------------------------------
  Widget _employeeCard(BuildContext context, UserModel user) {
     final theme = Theme.of(context);
     final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.employeeDetails,
          arguments: {
            'userId': user.uid,
            'adminDepartment': widget.adminDepartment ?? 'CSE',
          },
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF64748B).withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Row(
          children: [
             // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
                ],
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: user.approved ? AdminHelpers.getAvatarColor(user.name).withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                backgroundImage: user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty
                    ? NetworkImage(user.profilePicUrl!)
                    : null,
                child: user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty
                    ? null
                    : Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: user.approved ? AdminHelpers.getAvatarColor(user.name) : Colors.orange,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      Flexible(
                        child: Text(
                          AdminHelpers.sanitizeLabel(user.name),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B), // Slate 800
                          ),
                        ),
                      ),
                      if (!user.approved)
                         Padding(
                           padding: const EdgeInsets.only(left: 8.0),
                           child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                             decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                             child: const Text("PENDING", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                           ),
                         ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.manualEmployeeId != null && user.manualEmployeeId!.isNotEmpty 
                        ? "ID: ${user.manualEmployeeId!}" 
                        : "ID: ${user.employeeId}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8), // Slate 400
                      letterSpacing: 0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  Row(
                    children: [
                      if (user.designation != null && user.designation!.isNotEmpty)
                         Text(
                           user.department == "Placement Cell" 
                               ? user.designation! 
                               : "${user.designation}  •  ",
                           style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                         ),
                      if (user.department != "Placement Cell")
                        Text(
                          user.department,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AdminHelpers.primaryColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            if (!user.approved)
               ElevatedButton(
                 onPressed: () => _approveUser(user),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: AdminHelpers.primaryColor, 
                   elevation: 0,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                 ),
                 child: const Text("Approve", style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
               )
            else
               const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  void _approveUser(UserModel user) async {
     try {
       // Ideally currently logged in admin ID needed. Passing 'admin' for now or fetch auth
       // Assuming auth is handled elsewhere or single admin
       await _firestoreService.approveUser(user.uid, 'ADMIN'); 
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Approved!")));
     } catch(e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
     }
  }

  Widget _buildSkeletonList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 8,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 100,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
