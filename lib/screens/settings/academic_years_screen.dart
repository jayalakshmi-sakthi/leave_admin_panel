import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/admin_helpers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/responsive_container.dart';

class AcademicYearsScreen extends StatefulWidget {
  const AcademicYearsScreen({super.key});

  @override
  State<AcademicYearsScreen> createState() => _AcademicYearsScreenState();
}

class _AcademicYearsScreenState extends State<AcademicYearsScreen> {
  final _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _getAcademicYearsWithStats() async {
    try {
      final snapshot = await _firestore.collection('leaveRequests').get();
      
      final Set<String> uniqueYears = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['academicYearId'] != null) {
          uniqueYears.add(data['academicYearId']);
        }
      }

      List<Map<String, dynamic>> yearData = [];
      int totalApproved = 0;
      int totalPending = 0;
      int totalRejected = 0;

      for (var year in uniqueYears) {
        final yearRequests = snapshot.docs.where((doc) => 
          doc.data()['academicYearId'] == year
        ).toList();

        final app = yearRequests.where((d) => d.data()['status'] == 'Approved').length;
        final pen = yearRequests.where((d) => d.data()['status'] == 'Pending').length;
        final rej = yearRequests.where((d) => d.data()['status'] == 'Rejected').length;

        totalApproved += app;
        totalPending += pen;
        totalRejected += rej;

        yearData.add({
          'year': year,
          'totalRequests': yearRequests.length,
          'approved': app,
          'pending': pen,
          'rejected': rej,
        });
      }

      yearData.sort((a, b) => b['year'].toString().compareTo(a['year'].toString()));
      
      return {
        'years': yearData,
        'globalStats': {
          'totalRequests': snapshot.docs.length,
          'totalYears': uniqueYears.length,
          'totalApproved': totalApproved,
          'totalPending': totalPending,
          'totalRejected': totalRejected,
        }
      };
    } catch (e) {
      debugPrint('Error fetching academic years: $e');
      return {'years': [], 'globalStats': {}};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        title: const Text('Academic Years', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getAcademicYearsWithStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AdminHelpers.primaryColor));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data ?? {};
          final List<Map<String, dynamic>> years = data['years'] ?? [];
          final Map<String, dynamic> globalStats = data['globalStats'] ?? {};

          if (years.isEmpty) {
            return _buildEmptyState(theme);
          }

          return ResponsiveContainer(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderStats(globalStats),
                  const SizedBox(height: 32),
                  const Text(
                    "Select Academic Year",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 16),
                  ...years.map((yearData) => _buildYearCard(yearData)).toList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderStats(Map<String, dynamic> stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AdminHelpers.primaryColor, AdminHelpers.primaryColor.withBlue(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AdminHelpers.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("System Overview", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(height: 4),
                  Text("Snapshot", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.analytics_rounded, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderItem("Total Years", "${stats['totalYears'] ?? 0}"),
              _buildHeaderItem("Total Apps", "${stats['totalRequests'] ?? 0}"),
              _buildHeaderItem("Approved", "${stats['totalApproved'] ?? 0}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildYearCard(Map<String, dynamic> data) {
    final year = data['year'];
    final total = data['totalRequests'];
    final approved = data['approved'];
    final pending = data['pending'];
    final rejected = data['rejected'];

    // Calculate percentages for the bar
    final double appWidth = total == 0 ? 0 : approved / total;
    final double penWidth = total == 0 ? 0 : pending / total;
    final double rejWidth = total == 0 ? 0 : rejected / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.yearEmployees, arguments: year);
          },
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // Slate 100
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.calendar_today_rounded, color: AdminHelpers.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          year,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$total Applications",
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Visual Stat Bar
                if (total > 0)
                  Column(
                    children: [
                      Container(
                        height: 8,
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            if (appWidth > 0) Expanded(flex: (appWidth * 100).toInt(), child: Container(color: const Color(0xFF10B981))),
                            if (penWidth > 0) Expanded(flex: (penWidth * 100).toInt(), child: Container(color: const Color(0xFFF59E0B))),
                            if (rejWidth > 0) Expanded(flex: (rejWidth * 100).toInt(), child: Container(color: const Color(0xFFEF4444))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniStat("Approved", approved, const Color(0xFF10B981)),
                    _buildMiniStat("Pending", pending, const Color(0xFFF59E0B)),
                    _buildMiniStat("Rejected", rejected, const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(
          "$count ",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
            ]),
            child: Icon(Icons.calendar_today_outlined, size: 64, color: theme.disabledColor),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Academic Data Found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Academic years will appear here once applications are filed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
