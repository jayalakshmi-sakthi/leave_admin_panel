import 'package:flutter/material.dart';
import '../../utils/admin_helpers.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../routes/app_routes.dart';
import '../../widgets/responsive_container.dart';
import 'package:shimmer/shimmer.dart';

class YearEmployeesScreen extends StatefulWidget {
  final String academicYearId;
  final String adminDepartment;
  const YearEmployeesScreen({
    super.key,
    required this.academicYearId,
    this.adminDepartment = 'CSE',
  });

  @override
  State<YearEmployeesScreen> createState() => _YearEmployeesScreenState();
}

class _YearEmployeesScreenState extends State<YearEmployeesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _selectedStatus = 'All';

  // 🎨 Theme
  static const Color primaryColor = AdminHelpers.primaryColor;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Employees', style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 22)),
            Text(widget.academicYearId, style: const TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textDark),
        actions: [
          IconButton(
            onPressed: () {}, // Future: Add CSV Export
            icon: const Icon(Icons.download_rounded, color: primaryColor),
            tooltip: "Export List",
          )
        ],
      ),
      body: ResponsiveContainer(
        child: Column(
          children: [
             _buildSearchAndFilter(),
             const Divider(height: 1, color: Color(0xFFE2E8F0)),
             _buildEmployeeList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          // Search Bar
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchText = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search name or ID...",
                hintStyle: const TextStyle(color: textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 18),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Status Dropdown
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF64748B), size: 16),
                  items: ['All', 'Pending', 'Approved'].map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDark)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedStatus = value);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    return Expanded(
      child: StreamBuilder<List<UserModel>>(
        stream: _firestoreService.getEmployeesStream(department: widget.adminDepartment),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return _buildSkeletonList();
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return _emptyState();

          final employees = snapshot.data!.where((user) {
            final name = user.name.toLowerCase();
            final email = user.email.toLowerCase();
            final empId = user.employeeId.toLowerCase();
            bool matchesSearch = name.contains(_searchText) || email.contains(_searchText) || empId.contains(_searchText);
            bool matchesStatus = _selectedStatus == 'All' 
                ? true 
                : (_selectedStatus == 'Pending' ? !user.approved : user.approved);
            return matchesSearch && matchesStatus;
          }).toList();

          if (employees.isEmpty) return _emptyState();

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: employees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _employeeCard(context, employees[index]);
            },
          );
        },
      ),
    );
  }

  Widget _employeeCard(BuildContext context, UserModel user) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.employeeDetails,
          arguments: {
            'userId': user.uid,
            'yearId': widget.academicYearId,
            'adminDepartment': widget.adminDepartment,
          },
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: user.approved ? AdminHelpers.getAvatarColor(user.name).withOpacity(0.12) : Colors.orange.withOpacity(0.12),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: user.approved ? AdminHelpers.getAvatarColor(user.name) : Colors.orange,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                     user.name,
                     style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                   ),
                   const SizedBox(height: 4),
                   Row(
                     children: [
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(
                           color: textMuted.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(4),
                         ),
                         child: Text(user.employeeId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted)),
                       ),
                       const SizedBox(width: 8),
                       Text(
                         user.role.toUpperCase(),
                         style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor),
                       ),
                     ],
                   )
                ],
              ),
            ),
            if (!user.approved)
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.amber.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.amber.withOpacity(0.3)),
                 ),
                 child: const Text("PENDING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
               )
            else
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: textMuted.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text("No employees found", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(height: 80, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
      ),
    );
  }
}
