import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../routes/app_routes.dart';
import '../../widgets/responsive_container.dart';
import '../../utils/admin_helpers.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _fire = FirebaseFirestore.instance;
  bool _loading = false;
  
  // 🎨 Theme
  static const Color primaryColor = AdminHelpers.primaryColor;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  // Academic Year
  DateTime? _startYear;
  DateTime? _endYear;

  // Leave Types
  List<Map<String, dynamic>> _leaveTypes = [];
  String? _userRole; 
  
  bool get _isSuperAdmin {
    final user = FirebaseAuth.instance.currentUser;
    // 🛡️ Fallback: Explicitly grant access to the owner email
    if (user?.email == 'leave752@gmail.com') return true;
    
    return _userRole == 'super_admin';
  }
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

      // 1.5 Fetch User Role (for Super Admin check)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _fire.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          _userRole = userDoc.data()?['role'];
        }
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
      
      // 3. Migrate Legacy Types (Add Colors/Icons if missing)
      bool needsUpdate = false;
      final List<Map<String, dynamic>> migrated = [];
      for (var t in _leaveTypes) {
        final m = AdminHelpers.migrateLegacyType(t);
        if (m != t) needsUpdate = true;
        migrated.add(m);
      }
      
      if (needsUpdate) {
             _leaveTypes = migrated;
             // Save back immediately to persist migration
             await _updateLeaveTypes(_leaveTypes); 
      } else {
             _leaveTypes = migrated;
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
    
    // Generate unique style
    final style = AdminHelpers.generateNewStyle(newList, name: name);
    
    newList.add({
      'name': name, 
      'days': days,
      'color': style['color'],
      'icon': style['icon'],
    });
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
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
             primary: Color(0xFF3399CC), // Admin Panel Blue
             onSurface: Color(0xFF0F172A), // Dark Slate Text
          ),
          dialogTheme: DialogTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  // --------------------------------------------------
  // 🔐 SECURITY & PASSWORD
  // --------------------------------------------------
  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Color(0xFF3399CC)),
              SizedBox(width: 12),
              Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "For security reasons, you must re-authenticate by entering your current password.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              // Current Password
              TextField(
                controller: currentPassController,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: "Current Password",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // New Password
              TextField(
                controller: newPassController,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: "New Password",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Confirm Password
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Confirm New Password",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.check_circle_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: loading ? null : () async {
                final current = currentPassController.text.trim();
                final newPass = newPassController.text.trim();
                final confirm = confirmPassController.text.trim();

                if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                  _showSnack("Please fill all fields");
                  return;
                }
                if (newPass != confirm) {
                  _showSnack("New passwords do not match");
                  return;
                }
                if (newPass.length < 6) {
                  _showSnack("Password must be at least 6 characters");
                  return;
                }

                setDialogState(() => loading = true);
                
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null || user.email == null) throw "User session not found";

                  // 1. Re-authenticate
                  final cred = EmailAuthProvider.credential(email: user.email!, password: current);
                  await user.reauthenticateWithCredential(cred);

                  // 2. Update Password
                  await user.updatePassword(newPass);

                  if (mounted) {
                    Navigator.pop(context);
                    _showSnack("Password updated successfully!");
                  }
                } on FirebaseAuthException catch (e) {
                  _showSnack(e.message ?? "Update failed");
                } catch (e) {
                  _showSnack("Error: $e");
                } finally {
                  if (mounted) setDialogState(() => loading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: loading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Update Password"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor, width: 1.5),
        boxShadow: [
           if (!isDark)
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          return Row(
            children: [
              // 1. Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AdminHelpers.darkSurface : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.security_rounded, color: Color(0xFF3399CC), size: 28),
              ),
              const SizedBox(width: 16),

              // 2. Text (Expanded to prevent squashing)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Account Security",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Manage your login credentials",
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),

              // 3. Button (Adaptive)
              ElevatedButton(
                onPressed: _showChangePasswordDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isMobile 
                    ? const Icon(Icons.lock_reset, size: 20)
                    : const Text("Change Password"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ResponsiveContainer(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text("Settings & Configuration",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: theme.textTheme.displayLarge?.color)),
                  const SizedBox(height: 32),

                  // 1. Profile Section
                  _buildProfileCard(user),
                  const SizedBox(height: 32),

                  // 2. Security Section
                  _buildSectionHeader("Security", Icons.shield_outlined),
                  const SizedBox(height: 16),
                  _buildSecurityCard(),
                  const SizedBox(height: 32),

                  // 3. User Management Section
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
                            backgroundColor: AdminHelpers.primaryColor,
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
            ),
          );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).disabledColor, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).textTheme.titleMedium?.color)),
      ],
    );
  }

  Widget _buildProfileCard(User? user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor, width: 1.5),
          boxShadow: [
             if (!isDark)
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))
          ]),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 450;
          
          final content = [
              CircleAvatar(
                  radius: 30,
                  backgroundColor: isDark ? AdminHelpers.darkSurface : const Color(0xFFE0F2F9), // KEC soft blue
                  child: const Icon(Icons.business_center_rounded, size: 32, color: Color(0xFF3399CC))),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                   Text(_isSuperAdmin ? "Super Admin" : "Department Admin",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color)),
                   Text(user?.email ?? "—",
                      style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                   const SizedBox(height: 4),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                     decoration: BoxDecoration(
                       color: (_userRole == 'super_admin') ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(4),
                       border: Border.all(color: (_userRole == 'super_admin') ? Colors.purple.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
                     ),
                     child: Text(
                       "Role: ${_userRole?.toUpperCase() ?? 'LOADING...'}",
                       style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (_userRole == 'super_admin') ? Colors.purple : Colors.blue),
                     ),
                   ),
                ],
              ),
               if (!isMobile) const Spacer(),
               if (isMobile) const SizedBox(height: 24),
               InkWell(
                onTap: _logout,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  width: isMobile ? double.infinity : null,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                       Icon(Icons.logout_rounded, size: 20, color: Colors.redAccent),
                       SizedBox(width: 8),
                       Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ];

          if (isMobile) {
             return Column(children: content);
          }
          return Row(children: content);
        }
      ),
    );
  }

  Widget _buildAcademicYearCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor, width: 1.5),
          boxShadow: [
             if (theme.brightness == Brightness.light)
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))
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
                backgroundColor: AdminHelpers.primaryColor,
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
                side: BorderSide(color: theme.dividerColor),
                foregroundColor: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? date, bool isStart) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _pickDate(isStart),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.textTheme.bodySmall?.color, fontWeight: FontWeight.bold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor)),
          suffixIcon: Icon(Icons.calendar_month_rounded, color: theme.iconTheme.color),
          filled: true,
          fillColor: theme.brightness == Brightness.dark ? AdminHelpers.darkSurface : const Color(0xFFF8FAFC),
        ),
        child: Text(
          date == null ? "Select Date" : DateFormat('MMM dd, yyyy').format(date),
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
        ),
      ),
    );
  }

  Widget _buildUserManagementCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor, width: 1.5),
          boxShadow: [
             if (!isDark)
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))
          ]),
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
                
                  return Column(
                      children: [
                        // Show "Dept Admins" ONLY to Super Admin
                        if (_userRole == 'super_admin') ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF6366F1)),
                        ),
                        title: Text(
                          'Department Admins',
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color),
                        ),
                        subtitle: Text(
                          'Manage department-level access',
                          style: TextStyle(color: theme.textTheme.bodySmall?.color),
                        ),
                        trailing: Icon(Icons.chevron_right, color: theme.iconTheme.color),
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.departmentAdmins);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: theme.dividerColor, height: 1),
                      ),
                    ],
                    
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: pendingCount > 0 
                              ? const Color(0xFFF59E0B).withOpacity(isDark ? 0.2 : 0.1)
                              : theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: pendingCount > 0 
                              ? const Color(0xFFF59E0B) 
                              : theme.disabledColor,
                        ),
                      ),
                      title: Text(
                        'Pending User Approvals',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color),
                      ),
                      subtitle: Text(
                        pendingCount > 0 
                            ? '$pendingCount user(s) awaiting approval'
                            : 'No pending approvals',
                        style: TextStyle(color: theme.textTheme.bodySmall?.color),
                      ),
                      trailing: pendingCount > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$pendingCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12
                                ),
                              ),
                            )
                          : Icon(Icons.chevron_right, color: theme.iconTheme.color),
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.pendingUsers);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
  }

  Widget _buildLeaveTypesList() {
    if (_leaveTypes.isEmpty) {
      return Center(child: Text("No leave types configured. Add one!", style: TextStyle(color: Theme.of(context).disabledColor)));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _leaveTypes.length,
      itemBuilder: (ctx, i) {
        final t = _leaveTypes[i];
        final theme = Theme.of(context);
        return Card(
          elevation: 0,
          color: theme.cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor, width: 1.5)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: (t['color'] != null ? Color(t['color']) : AdminHelpers.primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(
                t['icon'] != null ? AdminHelpers.getIconFromCodePoint(t['icon']) : Icons.stars,
                color: t['color'] != null ? Color(t['color']) : AdminHelpers.primaryColor,
              ),
            ),
            title: Text(t['name'],
                style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
            subtitle: Text("${t['days']} days/year", style: TextStyle(color: theme.textTheme.bodySmall?.color)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: AdminHelpers.primaryColor),
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
