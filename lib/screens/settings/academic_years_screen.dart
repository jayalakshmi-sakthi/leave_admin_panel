import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AcademicYearsScreen extends StatefulWidget {
  const AcademicYearsScreen({super.key});

  @override
  State<AcademicYearsScreen> createState() => _AcademicYearsScreenState();
}

class _AcademicYearsScreenState extends State<AcademicYearsScreen> {
  final _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> _getAllAcademicYears() async {
    try {
      // Get all leave requests and extract unique years
      final snapshot = await _firestore.collection('leaveRequests').get();
      
      final Set<String> years = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['academicYearId'] != null) {
          years.add(data['academicYearId']);
        }
      }

      // Get stats for each year
      List<Map<String, dynamic>> yearData = [];
      for (var year in years) {
        final requests = snapshot.docs.where((doc) => 
          doc.data()['academicYearId'] == year
        ).toList();

        yearData.add({
          'year': year,
          'totalRequests': requests.length,
          'approved': requests.where((d) => d.data()['status'] == 'Approved').length,
          'pending': requests.where((d) => d.data()['status'] == 'Pending').length,
          'rejected': requests.where((d) => d.data()['status'] == 'Rejected').length,
        });
      }

      // Sort by year descending
      yearData.sort((a, b) => b['year'].toString().compareTo(a['year'].toString()));
      
      return yearData;
    } catch (e) {
      debugPrint('Error fetching academic years: $e');
      return [];
    }
  }

  Future<void> _deleteAcademicYear(String year) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Academic Year?'),
        content: Text(
          'This will permanently delete all leave requests for $year. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete all leave requests for this year
      final batch = _firestore.batch();
      final requests = await _firestore
          .collection('leaveRequests')
          .where('academicYearId', isEqualTo: year)
          .get();

      for (var doc in requests.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $year successfully')),
        );
        setState(() {}); // Refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Years'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getAllAcademicYears(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final years = snapshot.data ?? [];

          if (years.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No academic years found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: years.length,
            itemBuilder: (context, index) {
              final yearData = years[index];
              final year = yearData['year'];
              final total = yearData['totalRequests'];
              final approved = yearData['approved'];
              final pending = yearData['pending'];
              final rejected = yearData['rejected'];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.calendar_month,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    year,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$total total requests',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: const Color(0xFFEF4444),
                            onPressed: () => _deleteAcademicYear(year),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statChip('Approved', approved, const Color(0xFF10B981)),
                          _statChip('Pending', pending, const Color(0xFFF59E0B)),
                          _statChip('Rejected', rejected, const Color(0xFFEF4444)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
