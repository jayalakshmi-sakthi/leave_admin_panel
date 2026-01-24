import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../routes/app_routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _fire = FirebaseFirestore.instance;
  bool _loading = false;

  // Academic Year
  DateTime? _startYear;
  DateTime? _endYear;

  // Leave Types
  List<Map<String, dynamic>> _leaveTypes = [];

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() => _loading = true);
    try {
      // 1. Fetch Academic Year
      final yearDoc = await _fire.collection('settings').doc('academic_year').get();
      if (yearDoc.exists) {
        final data = yearDoc.data()!;
        _startYear = (data['start'] as Timestamp?)?.toDate();
        _endYear = (data['end'] as Timestamp?)?.toDate();
      } else {
        // Create Default Academic Year if missing
        final now = DateTime.now();
        final start = now.month >= 6 ? DateTime(now.year, 6, 1) : DateTime(now.year - 1, 6, 1);
        final end = DateTime(start.year + 1, 5, 31);
        
        await _fire.collection('settings').doc('academic_year').set({
          'start': Timestamp.fromDate(start),
          'end': Timestamp.fromDate(end),
          'label': '${start.year}-${end.year}',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        _startYear = start;
        _endYear = end;
      }

      // 2. Fetch Leave Types
      final typesDoc = await _fire.collection('settings').doc('leave_types').get();
      if (typesDoc.exists) {
        final data = typesDoc.data()!;
        _leaveTypes = List<Map<String, dynamic>>.from(data['types'] ?? []);
      } else {
        // Create Default Leave Types if missing
        final defaults = [
          {'name': 'CL', 'days': 12}, // Sick Leave merged into CL
          {'name': 'VL', 'days': 7},
          {'name': 'OD', 'days': 10},
        ];
        await _fire.collection('settings').doc('leave_types').set({
          'types': defaults,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _leaveTypes = defaults;
      }
    } catch (e) {
      debugPrint("Error loading/creating settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAcademicYear() async {
    if (_startYear == null || _endYear == null) return;
    setState(() => _loading = true);
    try {
      await _fire.collection('settings').doc('academic_year').set({
        'start': Timestamp.fromDate(_startYear!),
        'end': Timestamp.fromDate(_endYear!),
        'label': '${_startYear!.year}-${_endYear!.year}', // Useful for display
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSnack("Academic Year Updated!");
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addLeaveType(String name, int days) async {
    final newList = List<Map<String, dynamic>>.from(_leaveTypes);
    newList.add({'name': name, 'days': days});
    await _updateLeaveTypes(newList, closeDialog: true);
  }

  Future<void> _deleteLeaveType(int index) async {
    final newList = List<Map<String, dynamic>>.from(_leaveTypes);
    newList.removeAt(index);
    await _updateLeaveTypes(newList, closeDialog: false);
  }

  Future<void> _updateLeaveTypes(List<Map<String, dynamic>> newList, {bool closeDialog = false}) async {
    // Don't set _loading = true here to avoid full page refresh
    try {
      // Optimistic Update
      setState(() => _leaveTypes = newList);
      
      await _fire.collection('settings').doc('leave_types').set({
        'types': newList,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (closeDialog && mounted) Navigator.pop(context);
      _showSnack("Leave Types Updated");
    } catch (e) {
      _showSnack("Error: $e");
      // Revert if needed (omitted for simplicity, but could reload)
    } 
  }

  void _showAddDialog() {
    _showTypeDialog(null);
  }

  void _showEditDialog(int index) {
    _showTypeDialog(index);
  }

  void _showTypeDialog(int? index) {
    final isEdit = index != null;
    final nameCtrl = TextEditingController(text: isEdit ? _leaveTypes[index]['name'] : "");
    final daysCtrl = TextEditingController(text: isEdit ? _leaveTypes[index]['days'].toString() : "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? "Edit Leave Type" : "New Leave Type"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name (e.g. Sick)", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Days (e.g. 12)", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty || daysCtrl.text.isEmpty) return;
              if (isEdit) {
                _editLeaveType(index, nameCtrl.text.trim(), int.parse(daysCtrl.text));
              } else {
                _addLeaveType(nameCtrl.text.trim(), int.parse(daysCtrl.text));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3399CC), foregroundColor: Colors.white),
            child: Text(isEdit ? "Update" : "Add"),
          )
        ],
      ),
    );
  }

  Future<void> _editLeaveType(int index, String name, int days) async {
    final newList = List<Map<String, dynamic>>.from(_leaveTypes);
    newList[index] = {'name': name, 'days': days};
    await _updateLeaveTypes(newList, closeDialog: true);
  }

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.adminLogin, (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  const Text("Settings & Configuration",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 32),

                  // 1. Profile Section
                  _buildProfileCard(user),
                  const SizedBox(height: 32),

                  // 2. User Management Section
                  _buildSectionHeader("User Management", Icons.people),
                  const SizedBox(height: 16),
                  _buildUserManagementCard(),
                  const SizedBox(height: 32),

                  // 3. Academic Year Config
                  _buildSectionHeader("Academic Year", Icons.calendar_today),
                  const SizedBox(height: 16),
                  _buildAcademicYearCard(),

                  const SizedBox(height: 32),

                  // 4. Leave Types Config
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader("Leave Types", Icons.category),
                      ElevatedButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add New"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3399CC),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLeaveTypesList(),
                ],
              ),
            );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildProfileCard(User? user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))
          ]),
      child: Row(
        children: [
          CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFFE0F2F9), // KEC soft blue
              child: const Icon(Icons.business_center_rounded, size: 32, color: Color(0xFF3399CC))),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Placement Cell Admin",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(user?.email ?? "—",
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const Spacer(),
          InkWell(
            onTap: _logout,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicYearCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))
          ]),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _dateField("Start Date", _startYear, true)),
              const SizedBox(width: 16),
              const Icon(Icons.arrow_forward, color: Colors.grey),
              const SizedBox(width: 16),
              Expanded(
                  child: _dateField("End Date", _endYear, false)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveAcademicYear,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: const Color(0xFF3399CC),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Update Academic Year", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.academicYears),
              icon: const Icon(Icons.history),
              label: const Text("View All Academic Years"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFF64748B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? date, bool isStart) {
    return InkWell(
      onTap: () => _pickDate(isStart),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          suffixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF64748B)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
        ),
        child: Text(
          date == null ? "Select Date" : DateFormat('MMM dd, yyyy').format(date),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildUserManagementCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Pending Approvals
            StreamBuilder<QuerySnapshot>(
              stream: _fire
                  .collection('users')
                  .where('approved', isEqualTo: false)
                  .where('role', isEqualTo: 'staff')
                  .snapshots(),
              builder: (context, snapshot) {
                final pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pendingCount > 0 
                          ? const Color(0xFFFEF3C7) 
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_add_alt_1,
                      color: pendingCount > 0 
                          ? const Color(0xFFF59E0B) 
                          : const Color(0xFF64748B),
                    ),
                  ),
                  title: const Text(
                    'Pending User Approvals',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    pendingCount > 0 
                        ? '$pendingCount user(s) awaiting approval'
                        : 'No pending approvals',
                  ),
                  trailing: pendingCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.pendingUsers);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypesList() {
    if (_leaveTypes.isEmpty) {
      return const Center(child: Text("No leave types configured. Add one!"));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _leaveTypes.length,
      itemBuilder: (ctx, i) {
        final t = _leaveTypes[i];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F9),
                  borderRadius: BorderRadius.circular(10)),
              child: Text("${t['days']}",
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, color: Color(0xFF3399CC))),
            ),
            title: Text(t['name'],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${t['days']} days/year"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF3399CC)),
                  onPressed: () => _showEditDialog(i),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteLeaveType(i),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
