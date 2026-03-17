import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/admin_helpers.dart';
import '../../models/leave_request_model.dart';
import '../../services/excel_service.dart';
import '../requests/admin_leave_detail_screen.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final String userId;

  final String? academicYearId;
  final String adminDepartment; // ✅ Required for dept isolation

  const EmployeeDetailsScreen({
    super.key,
    required this.userId,
    this.academicYearId,
    this.adminDepartment = 'CSE', // default fallback
  });

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _idController = TextEditingController();
  bool _isEditingId = false;
  bool _isSaving = false;

  // 🎨 Theme
  static const Color primaryColor = AdminHelpers.primaryColor;
  static const Color scaffoldBg = AdminHelpers.scaffoldBg;
  static const Color textDark = AdminHelpers.textMain;
  static const Color textMuted = AdminHelpers.textMuted;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _saveEmployeeId() async {
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateEmployeeId(widget.userId, _idController.text.trim());
      setState(() => _isEditingId = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Employee ID updated successfully"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating ID: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _downloadReport(UserModel user) async {
    setState(() => _isSaving = true);
    try {
      final settings = await _firestoreService.getAcademicYearSettings(department: widget.adminDepartment);
      final academicYear = widget.academicYearId ?? (settings['label'] as String);
      
      final leaves = await _firestoreService.getEmployeeLeaveHistory(user.uid, widget.adminDepartment).first;
      final leaveTypes = await _firestoreService.getLeaveTypes(department: widget.adminDepartment);
      
      final compOffStats = await _firestoreService.getCompOffStats(user.uid, academicYear, department: widget.adminDepartment);
      final finalLeaveTypes = List<Map<String, dynamic>>.from(leaveTypes);
      
      bool hasComp = finalLeaveTypes.any((t) => t['name'] == 'COMP' || (t['leaveType'] != null && t['leaveType'] == 'COMP'));
      if (!hasComp) {
        finalLeaveTypes.add({
          'name': 'COMP',
          'days': compOffStats['limit'],
        });
      }

      final leaveData = leaves.map((l) => l.toMap()).toList();
      
      await ExcelService.generateAdvancedLeaveReport(
        userName: user.name,
        employeeId: user.employeeId,
        academicYear: academicYear,
        leaves: leaveData,
        leaveTypes: finalLeaveTypes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report generated successfully"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error generating report: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<UserModel>(
        stream: _firestoreService.getUserStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          if (snapshot.hasError) {
             return Scaffold(body: Center(child: Text("Error: ${snapshot.error}")));
          }

          if (!snapshot.hasData) {
            return const Scaffold(body: Center(child: Text("Employee not found")));
          }

          final user = snapshot.data!;
          if (!_isEditingId) {
            _idController.text = user.employeeId;
          }

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              backgroundColor: const Color(0xFF001C3D), // Explicit KEC Navy
              elevation: 0,
              title: const Text(
                "Employee Details",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: theme.dividerColor, height: 1),
              ),
              actions: [
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2)),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: primaryColor),
                    tooltip: "Download Annual Report",
                    onPressed: () => _downloadReport(user),
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _profileCard(user),
                  const SizedBox(height: 24),
                  _buildStatusBreakdown(user.uid),
                  const SizedBox(height: 24),
                  _buildLeavePulse(user.uid),
                  const SizedBox(height: 24),
                  _buildBalanceAnalytics(user),
                  const SizedBox(height: 32),
                  _buildLeaveData(user.uid),
                ],
              ),
            ),
          );
        },
      );
  }

  // --------------------------------------------------
  // 👤 PROFILE CARD
  // --------------------------------------------------
  Widget _profileCard(UserModel user) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminHelpers.cardDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AdminHelpers.getAvatarColor(user.name).withOpacity(0.12),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AdminHelpers.getAvatarColor(user.name),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.department,
                       style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      user.email,
                      style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user.role.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          Divider(height: 1, color: theme.dividerColor),
          const SizedBox(height: 20),
          // 📝 EMPLOYEE ID ROW
          Row(
            children: [
              Icon(Icons.badge_outlined, color: theme.disabledColor, size: 20),
              const SizedBox(width: 12),
              Text("EMPLOYEE ID:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.disabledColor)),
              const SizedBox(width: 12),
              Expanded(
                child: _isEditingId 
                  ? TextField(
                      controller: _idController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        border: UnderlineInputBorder(),
                      ),
                    )
                  : Text(user.employeeId, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              ),
              if (_isEditingId)
                Row(
                  children: [
                    if (_isSaving)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      IconButton(
                        icon: const Icon(Icons.check_rounded, color: AdminHelpers.success, size: 22),
                        onPressed: _saveEmployeeId,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.red, size: 22),
                      onPressed: () => setState(() => _isEditingId = false),
                    ),
                  ],
                )
              else
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: primaryColor, size: 20),
                  onPressed: () => setState(() => _isEditingId = true),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 📊 STATUS BREAKDOWN
  // --------------------------------------------------
  Widget _buildStatusBreakdown(String userId) {
    return FutureBuilder<Map<String, int>>(
      future: _fetchStatusCounts(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final counts = snapshot.data!;
        final total = counts.values.fold(0, (a, b) => a + b);
        if (total == 0) return const SizedBox();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: AdminHelpers.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Request Status Breakdown", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statusIndicator("Approved", counts['Approved'] ?? 0, total, AdminHelpers.success),
                  const SizedBox(width: 8),
                  _statusIndicator("Pending", counts['Pending'] ?? 0, total, AdminHelpers.warning),
                  const SizedBox(width: 8),
                  _statusIndicator("Rejected", counts['Rejected'] ?? 0, total, AdminHelpers.danger),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      if (counts['Approved']! > 0) Expanded(flex: counts['Approved']!, child: Container(color: AdminHelpers.success)),
                      if (counts['Pending']! > 0) Expanded(flex: counts['Pending']!, child: Container(color: AdminHelpers.warning)),
                      if (counts['Rejected']! > 0) Expanded(flex: counts['Rejected']!, child: Container(color: AdminHelpers.danger)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, int>> _fetchStatusCounts(String userId) async {
    // Use collectionGroup to get all records for this user across departments (admin view)
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('records')
        .where('userId', isEqualTo: userId)
        .get();
    
    Map<String, int> counts = {'Approved': 0, 'Pending': 0, 'Rejected': 0};
    for (var doc in snapshot.docs) {
      final status = doc.data()['status'] as String? ?? 'Pending';
      if (counts.containsKey(status)) {
        counts[status] = counts[status]! + 1;
      }
    }
    return counts;
  }

  Widget _statusIndicator(String label, int count, int total, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
            ],
          ),
          const SizedBox(height: 4),
          Text("$count", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 📈 LEAVE PULSE (MONTHLY BAR CHART)
  // --------------------------------------------------
  Widget _buildLeavePulse(String userId) {
    return FutureBuilder<List<double>>(
      future: _fetchMonthlyData(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final data = snapshot.data!;
        final maxVal = data.fold(1.0, (m, v) => v > m ? v : m);
        final monthLabels = ["Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May"];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: AdminHelpers.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Monthly Leave Pulse", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
                  const Icon(Icons.bar_chart_rounded, color: primaryColor, size: 20),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(12, (i) {
                    final heightFactor = data[i] / maxVal;
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (data[i] > 0)
                            Text(data[i].toInt().toString(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryColor)),
                          const SizedBox(height: 4),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: (heightFactor * 80).clamp(4.0, 80.0),
                            decoration: BoxDecoration(
                              color: data[i] > 0 ? primaryColor : primaryColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                              gradient: data[i] > 0 ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [primaryColor, primaryColor.withOpacity(0.6)],
                              ) : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(monthLabels[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<double>> _fetchMonthlyData(String userId) async {
    final settings = await _firestoreService.getAcademicYearSettings(department: widget.adminDepartment);
    final academicYearLabel = widget.academicYearId ?? (settings['label'] ?? _firestoreService.getCurrentAcademicYearString());

    // 1. Fetch Leaves — use dept-scoped path
    final leafSnap = await FirebaseFirestore.instance
        .collection('leaveRequests')
        .doc(widget.adminDepartment)
        .collection('records')
        .where('userId', isEqualTo: userId)
        .where('academicYearId', isEqualTo: academicYearLabel)
        .where('status', isEqualTo: 'Approved')
        .get();

    // 2. Fetch Comp Offs — use dept-scoped path
    final compSnap = await FirebaseFirestore.instance
        .collection('compOffRequests')
        .doc(widget.adminDepartment)
        .collection('records')
        .where('userId', isEqualTo: userId)
        .where('academicYearId', isEqualTo: academicYearLabel)
        .where('status', isEqualTo: 'Approved')
        .get();

    List<double> months = List.filled(12, 0.0);
    
    // Process Leaves
    for (var doc in leafSnap.docs) {
      final date = (doc.data()['fromDate'] as Timestamp?)?.toDate();
      if (date != null) {
        int m = date.month;
        int index = (m >= 6) ? (m - 6) : (m + 6);
        if (index >= 0 && index < 12) {
          months[index] += (doc.data()['numberOfDays'] ?? 0).toDouble();
        }
      }
    }

    // Process Comp Offs (Added to pulse)
    for (var doc in compSnap.docs) {
      final dateVal = doc.data()['workedDate'];
      DateTime? date;
      if (dateVal is Timestamp) date = dateVal.toDate();
      else if (dateVal is String) date = DateTime.tryParse(dateVal);
      
      if (date != null) {
        int m = date.month;
        int index = (m >= 6) ? (m - 6) : (m + 6);
        if (index >= 0 && index < 12) {
          months[index] += (doc.data()['days'] ?? 0).toDouble();
        }
      }
    }

    return months;
  }

  // --------------------------------------------------
  // 📊 LEAVE STATS & HISTORY (REAL-TIME)
  // --------------------------------------------------
  // --------------------------------------------------
  // 📊 LEAVE ANALYTICS
  // --------------------------------------------------
  Widget _buildBalanceAnalytics(UserModel user) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchAnalyticsData(user.uid, user.leaveOverrides),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: LinearProgressIndicator());
        }

        final data = snapshot.data!;
        final List<Map<String, dynamic>> typeLimits = data['limits'];
        final Map<String, double> usedMap = data['used'];
        final Map<String, double> compStats = data['compStats'];

        List<Widget> cards = [];

        // Build Normal Leave Types
        for (var type in typeLimits) {
          final name = type['name'] as String;
          if (name == 'COMP') continue;

          final limit = (type['days'] as num).toDouble();
          final used = usedMap[name] ?? 0.0;
          final balance = (limit - used).clamp(0.0, 99.0);

          cards.add(_analyticsCard(
            AdminHelpers.getLeaveName(name),
            balance,
            used,
            limit,
            AdminHelpers.getLeaveColor(name),
            AdminHelpers.getLeaveIcon(name),
          ));
        }

        // Add Comp Off
        // Check for manual override first
        double compLimit = compStats['limit']!;
        // Determine override key (try 'COMP' or 'Comp Off')
        // The dialog saves keys based on limits list. If 'COMP' is not in limits list by default,
        // it might be added if we handle it. 
        // But usually overrides are checked against effectiveLimits.
        
        // Let's check if 'COMP' is in effectiveLimits (which includes overrides)
        final compOverride = typeLimits.firstWhere(
           (t) => t['name'] == 'COMP', 
           orElse: () => {'days': null}
        )['days'];

        if (compOverride != null) {
           compLimit = (compOverride as num).toDouble();
        }

        cards.add(_analyticsCard(
          "Comp Off",
          (compLimit - compStats['used']!).clamp(0.0, 99.0),
          compStats['used']!,
          compLimit,
          const Color(0xFF8B5CF6),
          Icons.stars_rounded,
        ));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Leave Analytics",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color),
                ),
                TextButton.icon(
                  onPressed: () => _showEditLimitsDialog(user, typeLimits),
                  icon: const Icon(Icons.tune_rounded, size: 20), // changed icon
                  label: const Text("Customize Limits"), // changed label
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    backgroundColor: primaryColor.withOpacity(0.05), // Added bg foundation
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300, // ✅ responsive width constraint
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1, // ✅ Adjusted for better card shape & to prevent overflow
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) => cards[index],
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchAnalyticsData(String userId, Map<String, double>? overrides) async {
    final settings = await _firestoreService.getAcademicYearSettings(department: widget.adminDepartment);
    final academicYear = widget.academicYearId ?? (settings['label'] ?? _firestoreService.getCurrentAcademicYearString());
    
    final limits = await _firestoreService.getLeaveTypes(department: widget.adminDepartment);
    final compStats = await _firestoreService.getCompOffStats(userId, academicYear, department: widget.adminDepartment);

    // Apply Overrides to limits
    final effectiveLimits = limits.map((limitMap) {
      final name = limitMap['name'] as String;
      if (overrides != null && overrides.containsKey(name)) {
        return {...limitMap, 'days': overrides[name]};
      }
      return limitMap;
    }).toList();
    
    // Ensure COMP is in the list
    if (!effectiveLimits.any((l) => l['name'] == 'COMP')) {
      effectiveLimits.add({
        'name': 'COMP',
        'days': overrides != null && overrides.containsKey('COMP') 
             ? overrides['COMP'] 
             : compStats['limit'], // Default to calculated
      });
    }

    // Fetch used counts from leaveRequests — use dept-scoped path
    final snapshot = await FirebaseFirestore.instance
        .collection('leaveRequests')
        .doc(widget.adminDepartment)
        .collection('records')
        .where('userId', isEqualTo: userId)
        .where('academicYearId', isEqualTo: academicYear)
        .where('status', isEqualTo: 'Approved')
        .get();

    Map<String, double> usedMap = {};
    for (var doc in snapshot.docs) {
      final type = doc.data()['leaveType'] as String? ?? 'Other';
      final days = (doc.data()['numberOfDays'] ?? 0).toDouble();
      usedMap[type] = (usedMap[type] ?? 0) + days;
    }

    return {
      'limits': effectiveLimits,
      'used': usedMap,
      'compStats': compStats,
    };
  }

  void _showEditLimitsDialog(UserModel user, List<Map<String, dynamic>> currentLimits) {
    final Map<String, TextEditingController> controllers = {};
    
    // We want to show ALL leave types, even if not currently overriden.
    // effectiveLimits passed in 'currentLimits' already has overrides applied.
    // We should try to get the "Base" limits (defaults) to show comparison if possible.
    // But for now, we just allow editing the current values.
    
    for (var limit in currentLimits) {
      final name = limit['name'] as String;
      // Skip computed/special types if needed, but COMP is often allowed to be overriden
      final days = limit['days'].toString();
      controllers[name] = TextEditingController(text: days);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.tune_rounded, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text("Customize Leave Limits", style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: SizedBox( // Limit width
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    "Set specific leave quotas for this employee. These overrides will persist until manually changed.",
                    style: TextStyle(fontSize: 13, color: textMuted),
                  ),
                ),
                ...controllers.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: entry.value,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: AdminHelpers.getLeaveName(entry.key),
                        helperText: "Global Default applies if cleared",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(AdminHelpers.getLeaveIcon(entry.key), color: AdminHelpers.getLeaveColor(entry.key)),
                        suffixIcon: IconButton(
                           icon: const Icon(Icons.restart_alt_rounded, size: 18),
                           tooltip: "Reset to Default",
                           onPressed: () {
                              // Ideally we'd fetch the actual default here, but clearing it conveys removal of override
                              // The logic below treats '0' as value. 
                              // To truly reset, we might need to handle empty string.
                              entry.value.text = ""; 
                           },
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
             onPressed: () {
                // Clear all overrides
                controllers.forEach((_, c) => c.text = "");
             }, 
             child: const Text("Reset All", style: TextStyle(color: Colors.red))
          ),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              final Map<String, double> newOverrides = {};
              controllers.forEach((key, controller) {
                final text = controller.text.trim();
                // If text is empty, we DON'T add it to map, effective removing the override.
                if (text.isNotEmpty) {
                  final val = double.tryParse(text) ?? 0.0;
                  newOverrides[key] = val;
                }
              });

              Navigator.pop(context);
              setState(() => _isSaving = true);
              try {
                // Determine if we are technically passing "null" or empty map if all are removed
                // Firestore update with map replaces the field. 
                await _firestoreService.updateUserLeaveOverrides(user.uid, newOverrides);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Custom limits saved successfully"), backgroundColor: AdminHelpers.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  Widget _analyticsCard(String label, double balance, double used, double total, Color color, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  "Total: ${total.toInt()}",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            balance.toStringAsFixed(1),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color, letterSpacing: -1),
          ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: total > 0 ? (used / total) : 0,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 4),
          Text(
            "${used.toStringAsFixed(1)} used",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // 📊 LEAVE REQUEST LOGS
  // --------------------------------------------------
  Widget _buildLeaveData(String userId) {
    return StreamBuilder<List<LeaveRequestModel>>(
      stream: _firestoreService.getEmployeeLeaveHistory(userId, widget.adminDepartment),
      builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(); // Analytics handles loader
         }
         
         if (snapshot.hasError) {
           return Text("Error loading leaves: ${snapshot.error}");
         }

         final leaves = snapshot.data ?? [];

         return Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // History List
             const Text(
               "Leave Request History",
               style: TextStyle(
                 fontSize: 18,
                 fontWeight: FontWeight.bold,
                 color: textDark,
               ),
             ),
             const SizedBox(height: 16),
             
             if (leaves.isEmpty)
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(32),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: const Color(0xFFE2E8F0)),
                 ),
                 child: const Column(
                   children: [
                     Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFE2E8F0)),
                     SizedBox(height: 12),
                     Text("No request records found", style: TextStyle(color: textMuted)),
                   ],
                 ),
               )
             else
               ListView.builder(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: leaves.length,
                 itemBuilder: (context, index) => _leaveCard(leaves[index]),
               ),
           ],
         );
      },
    );
  }

  Widget _statBox(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _leaveCard(LeaveRequestModel leave) {
    final statusColor = AdminHelpers.getStatusColor(leave.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Fixed overflow by removing IntrinsicHeight
        children: [
          // Status Strip
          Container(
            width: 6,
            height: 100, // Fixed height for visual consistency
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AdminHelpers.getLeaveName(leave.leaveType),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textDark),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          leave.status.toUpperCase(),
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap( // Use Wrap for responsiveness
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _iconLabel(Icons.calendar_today_outlined, "${AdminHelpers.formatDate(leave.fromDate)} → ${AdminHelpers.formatDate(leave.toDate)}"),
                      _iconLabel(Icons.access_time_rounded, "${leave.numberOfDays} day(s)"),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    leave.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveRequestDetailScreen(request: leave)));
            },
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: primaryColor),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _iconLabel(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textMuted),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
