import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added
import '../../models/leave_request_model.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../utils/admin_helpers.dart';
import '../../widgets/responsive_container.dart';

class LeaveRequestDetailScreen extends StatefulWidget {
  final LeaveRequestModel? request;
  final String? requestId;

  const LeaveRequestDetailScreen({super.key, this.request, this.requestId});

  @override
  State<LeaveRequestDetailScreen> createState() => _LeaveRequestDetailScreenState();
}

class _LeaveRequestDetailScreenState extends State<LeaveRequestDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _loading = false;
  late LeaveRequestModel _request;
  bool _initializing = true; // For initial fetch
  late String _currentStatus;
  
  // User Data State
  String _userName = "Loading...";
  String _employeeId = "";

  @override
  void initState() {
    super.initState();
    if (widget.request != null) {
        _request = widget.request!;
        _currentStatus = _request.status;
        _initializing = false;
        _initializeData();
    } else if (widget.requestId != null) {
        _fetchRequest(widget.requestId!);
    } else {
        // Error state
        _initializing = false;
    }
  }

  Future<void> _fetchRequest(String id) async {
      try {
          // Fetch from active year first or try to find it
          // Ideally we need yearId. If not passed, we search?
          // For now, let's search in likely places or assume active year.
          // BETTER: Pass collection/yearId in arguments.
          // Fallback: search common collections.
          final doc = await FirebaseFirestore.instance.collection('leaveRequests').doc(id).get();
          if (!doc.exists) {
              // Try previous year? Or just fail.
              // Fail for now.
          }
          
          if (doc.exists) {
              setState(() {
                  _request = LeaveRequestModel.fromMap(doc.data()!, doc.id);
                  _currentStatus = _request.status;
                  _initializing = false;
              });
              _initializeData();
          } else {
              if (mounted) setState(() => _initializing = false);
          }
      } catch (e) {
          debugPrint("Error fetching request: $e");
          if (mounted) setState(() => _initializing = false);
      }
  }

  Future<void> _initializeData() async {
    // 1. Use existing data if available
    _userName = _request.userName;
    _employeeId = _request.employeeId ?? "N/A";

    // 2. If data is missing (legacy records), fetch from User Profile
    if (_userName == 'Unknown' || _userName.isEmpty || _employeeId == 'N/A') {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_request.userId).get();
        if (userDoc.exists) {
           final data = userDoc.data();
           if (mounted) {
             setState(() {
               _userName = data?['name'] ?? 'Unknown User';
               _employeeId = data?['employeeId'] ?? 'N/A';
             });
           }
        }
      } catch (e) {
        debugPrint("Error fetching user details: $e");
      }
    } else {
        // Ensure UI updates if it was stuck on initial state
        if(mounted) setState(() {}); 
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);
    try {
      // Passing department ensures we hit the correct isolated nested collection
      await _firestoreService.updateLeaveStatus(
        _request.id, 
        status, 
        'admin', 
        department: _request.department ?? 'CSE'
      );
      
      setState(() {
        _currentStatus = status;
      });

      // ✅ Send Notification to User
      try {
        await NotificationService().sendNotification(
          toUserId: _request.userId,
          title: 'Leave Request $status',
          body: 'Your ${AdminHelpers.getLeaveName(_request.leaveType)} request for ${AdminHelpers.formatDate(_request.fromDate)} has been $status.',
          type: 'status_change',
          relatedId: _request.id,
          leaveType: _request.leaveType,
          academicYearId: _request.academicYearId,
        );
      } catch (e) {
        debugPrint("Notification Error: $e");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request marked as $status")),
        );
        Navigator.pop(context); // Go back to list after action
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
        return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
        );
    }
    
    // Check if request loaded
    // We used 'late' so if _initializing is false and _request not set, it might crash if we accessed it.
    // But we set it in _fetch or via widget.
    // Safety check:
    try {
        // Access a property to ensure initialized
        final s = _request.status;
    } catch (e) {
        return const Scaffold(body: Center(child: Text("Request not found.")));
    }

    // 🎨 Theme & Colors
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        title: const Text("Application Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B), // Slate 800
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
              children: [
            // 🏷️ Status Badge
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AdminHelpers.getStatusColor(_currentStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AdminHelpers.getStatusColor(_currentStatus).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(
                     _currentStatus == 'Approved' ? Icons.check_circle_rounded : (_currentStatus == 'Rejected' ? Icons.cancel_rounded : Icons.hourglass_top_rounded),
                     size: 16,
                     color: AdminHelpers.getStatusColor(_currentStatus),
                   ),
                   const SizedBox(width: 8),
                   Text(
                     "STATUS: ${_currentStatus.toUpperCase()}",
                     style: TextStyle(
                       fontWeight: FontWeight.bold, 
                       color: AdminHelpers.getStatusColor(_currentStatus), 
                       fontSize: 12, 
                       letterSpacing: 1
                     ),
                   ),
                ],
              ),
            ),

            // 📄 Application Form "Paper"
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF64748B).withOpacity(0.08), // Softer shadow
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ],
                border: Border.all(color: const Color(0xFFE2E8F0)), // Subtle border
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (Date)
                  Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      "Date: ${_initializing ? '...' : AdminHelpers.formatDate(_request.createdAt)}",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // FROM
                  Text("From,", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
                  const SizedBox(height: 4),
                  Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Employee ID: $_employeeId", style: const TextStyle(color: Color(0xFF64748B))),
                  const Text("KEC", style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 24),

                  // TO
                  Text("To,", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
                  const SizedBox(height: 4),
                  const Text("The Admin,", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text("Kongu Engineering College,", style: TextStyle(color: Color(0xFF64748B))),
                  const Text("Perundurai.", style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 32),

                  // SUBJECT
                  Text(
                    "Subject: Requisition for ${AdminHelpers.getLeaveName(_request.leaveType)} - Reg.",
                    style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontSize: 15),
                  ),
                  const SizedBox(height: 24),

                  // BODY
                  const Text("Respected Sir/Madam,", style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Text(
                    "    I would like to request ${AdminHelpers.getLeaveName(_request.leaveType)} for ${_request.numberOfDays} day(s) from "
                    "${AdminHelpers.formatDate(_request.fromDate)} to "
                    "${AdminHelpers.formatDate(_request.toDate)} due to "
                    "${_request.reason}.",
                    style: const TextStyle(height: 1.8, fontSize: 15, color: Color(0xFF334155)),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 12),
                  
                  if (_request.isHalfDay)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            "Half Day: ${_request.halfDaySession} Session",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                  const Text(
                    "    I kindly request you to grant me permission for the same.",
                    style: TextStyle(height: 1.8, fontSize: 15, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 48),

                  // SIGNATURE AREA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Thanking You,", style: TextStyle(fontWeight: FontWeight.w500)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text("Yours Faithfully,", style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 48),
                          Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 📎 Attachments Card
            if ((_request.signedFormUrl != null && _request.signedFormUrl!.isNotEmpty) || 
                (_request.finalSignedFormUrl != null && _request.finalSignedFormUrl!.isNotEmpty))
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                     BoxShadow(
                        color: const Color(0xFF64748B).withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                         Icon(Icons.attachment_rounded, size: 20, color: Color(0xFF64748B)),
                         SizedBox(width: 8),
                         Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_request.signedFormUrl != null && _request.signedFormUrl!.isNotEmpty)
                          _buildAttachmentButton(
                            "Medical/Proof", 
                            Icons.file_present_rounded, 
                            _request.signedFormUrl!
                          ),
                        const SizedBox(width: 12),
                        if (_request.finalSignedFormUrl != null && _request.finalSignedFormUrl!.isNotEmpty)
                          _buildAttachmentButton(
                            "Signed Copy", 
                            Icons.verified_rounded, 
                            _request.finalSignedFormUrl!,
                            isSuccess: true
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
            const SizedBox(height: 40),

            // ⚡ ACTIONS
            if (_currentStatus == 'Pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _updateStatus('Rejected'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Reject Request", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : () => _updateStatus('Approved'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AdminHelpers.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Text("Approve Request", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentButton(String label, IconData icon, String url, {bool isSuccess = false}) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () async {
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url));
          }
        },
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: isSuccess ? Colors.green : Colors.blue,
          side: BorderSide(color: isSuccess ? Colors.green.withOpacity(0.5) : Colors.blue.withOpacity(0.5)),
          backgroundColor: isSuccess ? Colors.green.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
        ),
      ),
    );
  }
}
