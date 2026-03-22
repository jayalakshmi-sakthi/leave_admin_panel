import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../../models/leave_request_model.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../utils/admin_helpers.dart';
import '../../models/user_model.dart';
import '../../widgets/responsive_container.dart';
import 'media_viewer_screen.dart'; // ✅ Added

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
  bool _initializing = true; 
  late String _currentStatus;
  
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
        _initializing = false;
    }
  }

  Future<void> _fetchRequest(String id) async {
      try {
          final snap = await FirebaseFirestore.instance
              .collectionGroup('records')
              .where('id', isEqualTo: id)
              .limit(1)
              .get();
          
          if (snap.docs.isNotEmpty) {
              final doc = snap.docs.first;
              setState(() {
                  _request = LeaveRequestModel.fromMap(doc.data(), doc.id);
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
    _userName = _request.userName;
    _employeeId = _request.employeeId ?? "N/A";

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
        if(mounted) setState(() {}); 
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);
    try {
      await _firestoreService.updateLeaveStatus(
        _request.id, 
        status, 
        'admin', 
        department: _request.department ?? 'CSE'
      );
      
      setState(() {
        _currentStatus = status;
      });

      // Notification is handled centrally in FirestoreService.updateLeaveStatus

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request marked as $status")),
        );
        Navigator.pop(context);
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
    
    try {
        final _ = _request.status;
    } catch (e) {
        return const Scaffold(body: Center(child: Text("Request not found.")));
    }

    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Application Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
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
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
              children: [
            // 🏷️ Status Badge
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AdminHelpers.getStatusColor(_currentStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
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
              padding: EdgeInsets.all(isMobile ? 24 : 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      "Date: ${AdminHelpers.formatDate(_request.createdAt)}",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Text("From,", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
                  const SizedBox(height: 12),
                  StreamBuilder<UserModel>(
                    stream: _firestoreService.getUserStream(_request.userId),
                    builder: (context, snapshot) {
                      final profilePic = snapshot.data?.profilePicUrl;
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AdminHelpers.getAvatarColor(_userName).withOpacity(0.1),
                            backgroundImage: profilePic?.isNotEmpty == true ? NetworkImage(profilePic!) : null,
                            child: profilePic?.isNotEmpty == true ? null : Text(_userName[0].toUpperCase(), style: TextStyle(color: AdminHelpers.getAvatarColor(_userName), fontSize: 14)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text("Employee ID: $_employeeId", style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Text("KEC", style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 24),

                  Text("To,", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
                  const SizedBox(height: 4),
                  const Text("The Admin,", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text("Kongu Engineering College,", style: TextStyle(color: Color(0xFF64748B))),
                  const Text("Perundurai.", style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 32),

                  Text(
                    "Subject: Requisition for ${AdminHelpers.getLeaveName(_request.leaveType)} - Reg.",
                    style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontSize: isMobile ? 14 : 15),
                  ),
                  const SizedBox(height: 24),

                  const Text("Respected Sir/Madam,", style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  Text(
                    "    I would like to request ${AdminHelpers.getLeaveName(_request.leaveType)} for ${_request.numberOfDays} day(s) from "
                    "${AdminHelpers.formatDate(_request.fromDate)} to "
                    "${AdminHelpers.formatDate(_request.toDate)} due to "
                    "${_request.reason}.",
                    style: TextStyle(height: 1.8, fontSize: isMobile ? 14 : 15, color: const Color(0xFF334155)),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 12),
                  
                  if (_request.isHalfDay)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          Text(
                            "Half Day: ${_request.halfDaySession} Session",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B), fontSize: 13),
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
                  isMobile 
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Thanking You,", style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 32),
                        const Text("Yours Faithfully,", style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : Row(
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    Column(
                      children: [
                        if (_request.signedFormUrl != null && _request.signedFormUrl!.isNotEmpty)
                          _buildAttachmentButton(
                            "Medical/Proof", 
                            Icons.file_present_rounded, 
                            _request.signedFormUrl!
                          ),
                        if (_request.signedFormUrl != null && _request.signedFormUrl!.isNotEmpty && _request.finalSignedFormUrl != null && _request.finalSignedFormUrl!.isNotEmpty)
                          const SizedBox(height: 12),
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
              isMobile 
              ? Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
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
                  ],
                )
              : Row(
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
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
               builder: (_) => MediaViewerScreen(
                 url: url,
                 title: label,
               )
            ),
          );
        },
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: isSuccess ? AdminHelpers.success : AdminHelpers.secondaryColor,
          side: BorderSide(color: (isSuccess ? AdminHelpers.success : AdminHelpers.secondaryColor).withOpacity(0.5)),
          backgroundColor: (isSuccess ? AdminHelpers.success : AdminHelpers.secondaryColor).withOpacity(0.05),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
