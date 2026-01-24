import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added
import '../../models/leave_request_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/admin_helpers.dart';

class LeaveRequestDetailScreen extends StatefulWidget {
  final LeaveRequestModel request;

  const LeaveRequestDetailScreen({super.key, required this.request});

  @override
  State<LeaveRequestDetailScreen> createState() => _LeaveRequestDetailScreenState();
}

class _LeaveRequestDetailScreenState extends State<LeaveRequestDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _loading = false;
  late String _currentStatus;
  
  // User Data State
  String _userName = "Loading...";
  String _employeeId = "";
  
  @override
  void initState() {
    super.initState();
    _currentStatus = widget.request.status;
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 1. Use existing data if available
    _userName = widget.request.userName;
    _employeeId = widget.request.employeeId ?? "N/A";

    // 2. If data is missing (legacy records), fetch from User Profile
    if (_userName == 'Unknown' || _userName.isEmpty || _employeeId == 'N/A') {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.request.userId).get();
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
      // Assuming 'admin' as standard for now, could be passed from auth
      await _firestoreService.updateLeaveStatus(widget.request.id, status, 'admin');
      
      setState(() {
        _currentStatus = status;
      });

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Application Details", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF3399CC),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 📄 Application Form "Paper"
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2), // Paper-like
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (Date)
                  Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      "Date: ${AdminHelpers.formatDate(widget.request.createdAt)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // FROM
                  const Text("From,", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text("Employee ID: $_employeeId"),
                  const Text("KEC"), // Contextual
                  const SizedBox(height: 20),

                  // TO
                  const Text("To,", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text("The Principal / HOD,", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text("Kongu Engineering College,"),
                  const Text("Perundurai."),
                  const SizedBox(height: 20),

                  // SUBJECT
                  Text(
                    "Subject: Requisition for ${AdminHelpers.getLeaveName(widget.request.leaveType)} - Reg.",
                    style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                  ),
                  const SizedBox(height: 20),

                  // BODY
                  const Text("Respected Sir/Madam,"),
                  const SizedBox(height: 12),
                  Text(
                    "    I would like to request ${AdminHelpers.getLeaveName(widget.request.leaveType)} for ${widget.request.numberOfDays} day(s) from "
                    "${AdminHelpers.formatDate(widget.request.fromDate)} to "
                    "${AdminHelpers.formatDate(widget.request.toDate)} due to "
                    "${widget.request.reason}.",
                    style: const TextStyle(height: 1.6, fontSize: 15),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 12),
                  
                  if (widget.request.isHalfDay)
                    Text(
                      "    (Note: This is a Half Day leave for ${widget.request.halfDaySession} session)",
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),

                  const SizedBox(height: 12),
                  const Text(
                    "    I kindly request you to grant me permission for the same.",
                    style: TextStyle(height: 1.6, fontSize: 15),
                  ),
                  const SizedBox(height: 40),

                  // SIGNATURE AREA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Thanking You,"),
                      Column(
                        children: [
                          const Text("Yours Faithfully,"),
                          const SizedBox(height: 40),
                          Text("($_userName)", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 📎 Attachments Card
            if ((widget.request.signedFormUrl != null && widget.request.signedFormUrl!.isNotEmpty) || 
                (widget.request.finalSignedFormUrl != null && widget.request.finalSignedFormUrl!.isNotEmpty))
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (widget.request.signedFormUrl != null && widget.request.signedFormUrl!.isNotEmpty)
                          _buildAttachmentButton(
                            "Medical/Proof", 
                            Icons.attachment, 
                            widget.request.signedFormUrl!
                          ),
                        const SizedBox(width: 12),
                        if (widget.request.finalSignedFormUrl != null && widget.request.finalSignedFormUrl!.isNotEmpty)
                          _buildAttachmentButton(
                            "Signed Copy", 
                            Icons.verified_user, 
                            widget.request.finalSignedFormUrl!,
                            isSuccess: true
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
            const SizedBox(height: 30),

            // ⚡ ACTIONS
            if (_currentStatus == 'Pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : () => _updateStatus('Rejected'),
                      icon: const Icon(Icons.close),
                      label: const Text("REJECT"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : () => _updateStatus('Approved'),
                      icon: _loading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Icon(Icons.check),
                      label: const Text("APPROVE"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color: _currentStatus == 'Approved' ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _currentStatus == 'Approved' ? Colors.green.shade200 : Colors.red.shade200
                  )
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Icon(
                       _currentStatus == 'Approved' ? Icons.check_circle : Icons.cancel, 
                       color: _currentStatus == 'Approved' ? Colors.green : Colors.red
                     ),
                     const SizedBox(width: 8),
                     Text(
                       "This request has been $_currentStatus",
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                         color: _currentStatus == 'Approved' ? Colors.green.shade700 : Colors.red.shade700
                       ),
                     ),
                  ],
                ),
              ),
          ],
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
