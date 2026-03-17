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
  String _selectedStatus = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Widget _buildSearchAndFilter() {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1.5)),
      ),
      child: isDesktop 
        ? Row(
            children: [
              _searchField(theme),
              const SizedBox(width: 16),
              _statusDropdown(theme),
              const SizedBox(width: 8),
            ],
          )
        : Column(
            children: [
              _searchField(theme, isFull: true),
              const SizedBox(height: 12),
              _statusDropdown(theme, isFull: true),
            ],
          ),
    );
  }

  Widget _searchField(ThemeData theme, {bool isFull = false}) {
    final field = TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchText = value.toLowerCase()),
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
    );
    return isFull ? field : Expanded(flex: 2, child: field);
  }

  Widget _statusDropdown(ThemeData theme, {bool isFull = false}) {
    final dropdown = Container(
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
              child: Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedStatus = value);
          },
        ),
      ),
    );
    return isFull ? dropdown : Expanded(flex: 1, child: dropdown);
  }

  Widget _buildEmployeeList() {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    
    return Expanded(
      child: StreamBuilder<List<UserModel>>(
        stream: _firestoreService.getEmployeesStream(department: widget.adminDepartment ?? 'CSE'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return _buildSkeletonList();
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData || snapshot.data!.isEmpty) return _emptyState();

          final employees = snapshot.data!.where((user) {
            final matchesSearch = user.name.toLowerCase().contains(_searchText) || user.email.toLowerCase().contains(_searchText);
            final matchesStatus = _selectedStatus == 'All' ? true : (_selectedStatus == 'Pending' ? !user.approved : user.approved);
            return matchesSearch && matchesStatus;
          }).toList();

          if (employees.isEmpty) return _emptyState();

          return isDesktop 
              ? _buildDesktopTable(employees)
              : _buildMobileList(employees);
        },
      ),
    );
  }

  Widget _buildMobileList(List<UserModel> employees) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final user = employees[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AdminHelpers.getAvatarColor(user.name).withOpacity(0.1),
                      backgroundImage: user.profilePicUrl?.isNotEmpty == true ? NetworkImage(user.profilePicUrl!) : null,
                      child: user.profilePicUrl?.isNotEmpty == true ? null : Text(user.name[0].toUpperCase(), style: TextStyle(color: AdminHelpers.getAvatarColor(user.name))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(user.manualEmployeeId ?? user.employeeId, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                    _statusBadge(user.approved ? 'Approved' : 'Pending'),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _deptBadge(user.department),
                    Text(user.designation ?? 'N/A', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!user.approved)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveUser(user),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text("Approve"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A389),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    if (!user.approved) const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.employeeDetails, arguments: {'userId': user.uid, 'adminDepartment': widget.adminDepartment ?? 'CSE'}),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text("View Details"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminHelpers.primaryColor,
                          side: const BorderSide(color: AdminHelpers.primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<UserModel> employees) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    headingTextStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12),
                    dataRowHeight: 70,
                    columnSpacing: (constraints.maxWidth - 640) / 5 > 20 ? (constraints.maxWidth - 640) / 5 : 20,
                    horizontalMargin: 20,
                    columns: const [
                      DataColumn(label: Text("STAFF")),
                      DataColumn(label: Text("ID")),
                      DataColumn(label: Text("DEPARTMENT")),
                      DataColumn(label: Text("DESIGNATION")),
                      DataColumn(label: Text("STATUS")),
                      DataColumn(label: Text("ACTIONS")),
                    ],
              rows: employees.map((user) => DataRow(
                cells: [
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 18, backgroundColor: AdminHelpers.getAvatarColor(user.name).withOpacity(0.1), backgroundImage: user.profilePicUrl?.isNotEmpty == true ? NetworkImage(user.profilePicUrl!) : null, child: user.profilePicUrl?.isNotEmpty == true ? null : Text(user.name[0].toUpperCase(), style: TextStyle(color: AdminHelpers.getAvatarColor(user.name)))),
                      const SizedBox(width: 12),
                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  )),
                  DataCell(Text(user.manualEmployeeId ?? user.employeeId, style: const TextStyle(fontSize: 13))),
                  DataCell(_deptBadge(user.department)),
                  DataCell(Text(user.designation ?? 'N/A', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                  DataCell(_statusBadge(user.approved ? 'Approved' : 'Pending')),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!user.approved) IconButton(icon: const Icon(Icons.check_circle_outline, color: Color(0xFF00A389), size: 20), onPressed: () => _approveUser(user)),
                      IconButton(icon: const Icon(Icons.visibility_outlined, color: Color(0xFF001C3D), size: 20), onPressed: () => Navigator.pushNamed(context, AppRoutes.employeeDetails, arguments: {'userId': user.uid, 'adminDepartment': widget.adminDepartment ?? 'CSE'})),
                    ],
                  )),
                ],
              )).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'Approved' ? const Color(0xFF00A389) : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _deptBadge(String dept) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        dept,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 60, color: Color(0xFFCBD5E1)),
          SizedBox(height: 16),
          Text("No employees found", style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _approveUser(UserModel user) async {
     try {
       await _firestoreService.approveUser(user.uid, 'ADMIN'); 
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Approved!")));
     } catch(e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
