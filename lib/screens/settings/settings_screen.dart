import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../routes/app_routes.dart';
import '../../widgets/responsive_container.dart';
import '../../utils/admin_helpers.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class SettingsScreen extends StatefulWidget {
  final String adminDepartment;
  const SettingsScreen({super.key, required this.adminDepartment});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _fire = FirebaseFirestore.instance;
  bool _loading = false;
  
  static const Color primaryColor = AdminHelpers.primaryColor;
  static const Color primaryNavy = Color(0xFF001C3D); 

  final _firestoreService = FirestoreService();

  DateTime? _startYear;
  DateTime? _endYear;
  late String _selectedDepartment;
  List<Map<String, dynamic>> _leaveTypes = [];
  String? _userRole; 
  
  bool get _isSuperAdmin {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == 'leave752@gmail.com') return true;
    return _userRole == 'super_admin';
  }

  @override
  void initState() {
    super.initState();
    _selectedDepartment = widget.adminDepartment;
    if (_selectedDepartment == 'All') {
      _selectedDepartment = 'General';
    }
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _fire.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          _userRole = userDoc.data()?['role'];
          final dept = userDoc.data()?['department'];
          if (_userRole != 'super_admin') {
            _selectedDepartment = dept ?? 'General';
          } else if (dept != null && dept != 'All') {
            _selectedDepartment = dept;
          }
        }
      }

      try {
        final yearSettings = await _firestoreService.getAcademicYearSettings(department: _selectedDepartment);
        final label = yearSettings['label'] as String?;
        if (label != null && label.isNotEmpty) {
          final parts = label.split('-');
          if (parts.length == 2) {
            final startYear = int.tryParse(parts[0]);
            final endYear = int.tryParse(parts[1]);
            if (startYear != null && endYear != null) {
              _startYear = DateTime(startYear, 6, 1);
              _endYear = DateTime(endYear, 5, 31);
            }
          }
        }
      } catch (e) {
        debugPrint("Year settings error: $e");
      }
      
      if (_startYear == null || _endYear == null) {
        final now = DateTime.now();
        final start = now.month >= 6 ? DateTime(now.year, 6, 1) : DateTime(now.year - 1, 6, 1);
        final end = DateTime(start.year + 1, 5, 31);
        _startYear = start;
        _endYear = end;
      }

      final types = await _firestoreService.getLeaveTypes(department: _selectedDepartment);
      _leaveTypes = List<Map<String, dynamic>>.from(types);
      
      bool needsUpdate = false;
      final List<Map<String, dynamic>> migrated = [];
      for (var t in _leaveTypes) {
        final m = AdminHelpers.migrateLegacyType(t);
        if (m != t) needsUpdate = true;
        migrated.add(m);
      }
      
      if (needsUpdate) {
        _leaveTypes = migrated;
        await _updateLeaveTypes(_leaveTypes); 
      } else {
        _leaveTypes = migrated;
      }
    } catch (e) {
      debugPrint("Error loading/creating settings: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateLeaveTypes(List<Map<String, dynamic>> newList, {bool closeDialog = false}) async {
    try {
      setState(() => _leaveTypes = newList);
      await _firestoreService.setLeaveTypes(department: _selectedDepartment, types: newList);
      if (closeDialog && mounted) Navigator.pop(context);
      _showSnack("Settings Updated");
    } catch (e) {
      _showSnack("Error: $e");
    } 
  }

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: primaryNavy, onSurface: Color(0xFF1E293B)),
          dialogTheme: DialogTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
        child: child!,
      ),
    );
    if (d != null) {
      setState(() {
        if (isStart) _startYear = d;
        else _endYear = d;
      });
    }
  }

  void _showSnack(String s) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final user = FirebaseAuth.instance.currentUser;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ResponsiveContainer(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                   isMobile 
                   ? Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text("Settings", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.textTheme.displayLarge?.color)),
                         if (widget.adminDepartment == 'All') ...[
                           const SizedBox(height: 12),
                           _buildDeptDropdown(),
                         ],
                       ],
                     )
                   : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Settings & Configuration",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.textTheme.displayLarge?.color)),
                      if (widget.adminDepartment == 'All') _buildDeptDropdown(),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _buildProfileCard(user, isMobile),
                  const SizedBox(height: 32),

                  _buildSectionHeader("Security", Icons.shield_outlined),
                  const SizedBox(height: 16),
                  _buildSecurityCard(),
                  const SizedBox(height: 32),

                  if (_isSuperAdmin) ...[
                    _buildSectionHeader("User Management", Icons.people),
                    const SizedBox(height: 16),
                    _buildUserManagementCard(),
                    const SizedBox(height: 32),
                  ],

                  _buildSectionHeader("Academic Year", Icons.calendar_today),
                  const SizedBox(height: 16),
                  _buildAcademicYearCard(isMobile),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader("Leave Types", Icons.category),
                      ElevatedButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add New"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AdminHelpers.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLeaveTypesList(),
                ],
              ),
            ),
          );
  }

  Widget _buildDeptDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDepartment,
          icon: const Icon(Icons.arrow_drop_down, color: AdminHelpers.textMuted),
          items: AdminHelpers.departments
              .where((d) => d != 'All')
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (val) {
            if (val != null && val != _selectedDepartment) {
              setState(() => _selectedDepartment = val);
              _fetchSettings();
            }
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildProfileCard(User? user, bool isMobile) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor)),
      child: isMobile 
        ? StreamBuilder<UserModel>(
            stream: _firestoreService.getUserStream(user?.uid ?? ''),
            builder: (context, snapshot) {
              final u = snapshot.data;
              final hasPic = u?.profilePicUrl != null && u!.profilePicUrl!.isNotEmpty;
              return Column(
                children: [
                   CircleAvatar(
                     radius: 30, 
                     backgroundColor: const Color(0xFFF1F5F9), 
                     backgroundImage: hasPic ? NetworkImage(u!.profilePicUrl!) : null,
                     child: !hasPic ? const Icon(Icons.person, size: 32, color: primaryNavy) : null,
                   ),
                   const SizedBox(height: 16),
                   Text(_isSuperAdmin ? "Super Admin" : "Dept Admin", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
                   const SizedBox(height: 16),
                   _logoutButton(true),
                ],
              );
            }
          )
        : StreamBuilder<UserModel>(
            stream: _firestoreService.getUserStream(user?.uid ?? ''),
            builder: (context, snapshot) {
              final u = snapshot.data;
              final hasPic = u?.profilePicUrl != null && u!.profilePicUrl!.isNotEmpty;
              return Row(
                children: [
                   CircleAvatar(
                     radius: 30, 
                     backgroundColor: const Color(0xFFF1F5F9), 
                     backgroundImage: hasPic ? NetworkImage(u!.profilePicUrl!) : null,
                     child: !hasPic ? const Icon(Icons.person, size: 32, color: primaryNavy) : null,
                   ),
                   const SizedBox(width: 16),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text(_isSuperAdmin ? "Super Admin" : "Dept Admin", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
                     ],
                   ),
                   const Spacer(),
                   _logoutButton(false),
                ],
              );
            }
          ),
    );
  }

  Widget _logoutButton(bool isFull) {
    return OutlinedButton.icon(
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.adminLogin, (_) => false);
      },
      icon: const Icon(Icons.logout, size: 18, color: Colors.red),
      label: const Text("Sign Out", style: TextStyle(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: const BorderSide(color: Colors.red),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: isFull ? const Size(double.infinity, 50) : null,
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          const Icon(Icons.lock_reset, color: primaryNavy, size: 28),
          const SizedBox(width: 16),
          const Expanded(child: Text("Change Password", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () => _showChangePasswordDialog(),
            style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Manage"),
          )
        ],
      ),
    );
  }

  Widget _buildUserManagementCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: primaryNavy, size: 28),
          const SizedBox(width: 16),
          const Expanded(child: Text("Manage Dept Admins", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.departmentAdmins),
            style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Open"),
          )
        ],
      ),
    );
  }

  Widget _buildAcademicYearCard(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        children: [
          isMobile 
          ? Column(
              children: [
                _dateField("Start Date", _startYear, true),
                const SizedBox(height: 12),
                _dateField("End Date", _endYear, false),
              ],
            )
          : Row(
              children: [
                Expanded(child: _dateField("Start Date", _startYear, true)),
                const SizedBox(width: 16),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 16),
                Expanded(child: _dateField("End Date", _endYear, false)),
              ],
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                 await _firestoreService.setAcademicYearSettings(department: _selectedDepartment, data: {
                   'start': Timestamp.fromDate(_startYear!),
                   'end': Timestamp.fromDate(_endYear!),
                   'label': '${_startYear!.year}-${_endYear!.year}',
                 });
                 _showSnack("Updated!");
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.all(18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Save Year", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? date, bool isStart) {
    return InkWell(
      onTap: () => _pickDate(isStart),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(date == null ? "Select" : "${date.day}/${date.month}/${date.year}", style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypesList() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, childAspectRatio: 2.2, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemCount: _leaveTypes.length,
      itemBuilder: (context, index) {
        final t = _leaveTypes[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AdminHelpers.getLeaveColor(t['name']).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(AdminHelpers.getLeaveIcon(t['name']), color: AdminHelpers.getLeaveColor(t['name']), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("${t['days']} Days", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () async {
                final newList = List<Map<String, dynamic>>.from(_leaveTypes);
                newList.removeAt(index);
                await _updateLeaveTypes(newList);
              }),
            ],
          ),
        );
      },
    );
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final daysCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Leave Type"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: daysCtrl, decoration: const InputDecoration(labelText: "Days"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
            final newList = List<Map<String, dynamic>>.from(_leaveTypes);
            newList.add({'name': nameCtrl.text, 'days': int.parse(daysCtrl.text)});
            await _updateLeaveTypes(newList, closeDialog: true);
          }, child: const Text("Add")),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
     _showSnack("Use the standard Firebase password reset if needed, or implement full flow.");
  }
}
