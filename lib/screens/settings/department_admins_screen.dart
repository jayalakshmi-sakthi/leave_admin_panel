import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; // For Secondary App
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../utils/admin_helpers.dart';
import '../../widgets/responsive_container.dart';

class DepartmentAdminsScreen extends StatefulWidget {
  const DepartmentAdminsScreen({super.key});

  @override
  State<DepartmentAdminsScreen> createState() => _DepartmentAdminsScreenState();
}

class _DepartmentAdminsScreenState extends State<DepartmentAdminsScreen> {
  final FirestoreService _fire = FirestoreService();
  bool _loading = false;

  // ---------------------------------------------------------------------------
  // ➕ CREATE DEPARTMENT ADMIN (Secondary App Pattern)
  // ---------------------------------------------------------------------------
  Future<void> _addDepartmentAdmin(
      String username, String recoveryEmail, String password, String department) async {
    setState(() => _loading = true);
    FirebaseApp? secondaryApp;

    try {
      // 1. Initialize Secondary App
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      final auth = FirebaseAuth.instanceFor(app: secondaryApp);
      
      // ⚡ FIX: Set Persistence to NONE so it doesn't conflict with main session or cause browser blocks
      await auth.setPersistence(Persistence.NONE);

      UserCredential? cred;
      String finalAuthEmail = recoveryEmail;

      // 2. Try creating user with REAL Email
      try {
        cred = await auth.createUserWithEmailAndPassword(
          email: recoveryEmail,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // 🔄 Case A: User exists in Auth but maybe missing Firestore record?
          // We can try signing in with the provided password to verify ownership & get UID
          try {
            cred = await auth.signInWithEmailAndPassword(email: recoveryEmail, password: password);
            debugPrint("🔗 Re-using existing Auth account for $recoveryEmail");
          } catch (signInErr) {
             // If sign-in fails, it's either the wrong password or a truly different account.
             // Proceded to Fallback Plus Addressing
             final parts = recoveryEmail.split('@');
             if (parts.length == 2) {
                finalAuthEmail = "${parts[0]}+admin@${parts[1]}";
                cred = await auth.createUserWithEmailAndPassword(
                   email: finalAuthEmail,
                   password: password,
                );
             } else {
               rethrow;
             }
          }
        } else {
          rethrow;
        }
      }

      if (cred == null) throw "Failed to create account";
      final uid = cred.user!.uid;

      // 4. Create Firestore Document
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': finalAuthEmail, // Auth connection
        'recoveryEmail': recoveryEmail, // Contact email
        'username': username,
        'role': 'admin',
        'department': department,
        'name': '$department Admin',
        'employeeId': 'ADMIN-$department',
        'createdAt': FieldValue.serverTimestamp(),
        'approved': true,
      });

      if (mounted) {
        Navigator.pop(context); // Close Dialog
        
        String msg = "Created Admin: $username";
        if (finalAuthEmail != recoveryEmail) {
             msg += "\n(Note: Registered as $finalAuthEmail)";
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green, duration: const Duration(seconds: 4)),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showError("Username '$username' is reserved by a previous (or deleted) account. Please use a different username.");
      } else {
        _showError(e.message ?? "Auth Error");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      // 4. Cleanup
      await secondaryApp?.delete();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleExistingUser(String email, String department) async {
    // 1. Check if user exists in Firestore
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      _showError("Email taken in Auth but no Firestore record found.");
      return;
    }

    final userDoc = query.docs.first;
    final userData = userDoc.data();
    final currentRole = userData['role'];
    final currentDept = userData['department'];
    final name = userData['name'] ?? 'User';

    if (currentRole == 'admin' || currentRole == 'super_admin') {
      _showError("User is already an Admin ($currentDept).");
      return;
    }

    if (!mounted) return;

    // 2. Confirm Promotion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("User Already Exists"),
        content: Text(
          "User '$name' ($email) already exists in $currentDept.\n\n"
          "Do you want to PROMOTE them to $department Admin?\n"
          "This will change their role to 'admin' and switch their department."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminHelpers.primaryColor, foregroundColor: Colors.white),
            child: const Text("Promote to Admin"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 3. Update Firestore
      await userDoc.reference.update({
        'role': 'admin',
        'department': department,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        Navigator.pop(context); // Close 'Add Admin' Dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User Promoted Successfully!"), backgroundColor: Colors.green),
        );
      }
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 🗑️ DELETE ADMIN (Disable Access)
  // ---------------------------------------------------------------------------
  Future<void> _deleteAdmin(String uid, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Admin Access?"),
        content: Text("Are you sure you want to remove access for $email?\n\nNote: This only deletes the database record. The Auth account remains but will lose access."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        // We delete the user doc, which effectively removes their role and login access (due to rules/logic)
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        if (mounted) _showError("Admin removed (Database only)"); 
        // Note: To delete from Auth, we'd need Cloud Functions or the Secondary App to sign in as them, which is complex.
        // Deleting the doc is usually enough to block 'role' checks.
      } catch (e) {
        _showError("Error: $e");
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🖊️ EDIT ADMIN
  // ---------------------------------------------------------------------------
  Future<void> _editAdmin(String uid, String username, String department) async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'username': username,
        'department': department,
        'name': '$department Admin',
        'employeeId': 'ADMIN-$department',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close Dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Admin Updated Successfully"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _showError("Update Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showEditDialog(String uid, String currentUsername, String currentDept) {
    final usernameCtrl = TextEditingController(text: currentUsername);
    String selectedDept = currentDept;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Department Admin"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Update the details for this department admin.", style: TextStyle(color: AdminHelpers.textMuted, fontSize: 13)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: AdminHelpers.inputDecoration(label: "Username", hint: "e.g. placement_admin"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: AdminHelpers.departments.contains(selectedDept) ? selectedDept : AdminHelpers.departments.firstWhere((d) => d != 'All'),
                    decoration: AdminHelpers.inputDecoration(label: "Department", hint: "Select Department"),
                    items: AdminHelpers.departments
                        .where((d) => d != 'All')
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedDept = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AdminHelpers.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _editAdmin(uid, usernameCtrl.text.trim(), selectedDept);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminHelpers.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ➕ SHOW ADD DIALOG
  // ---------------------------------------------------------------------------
  void _showAddDialog() {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedDept = 'CSE';
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("New Department Admin"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Create a new login for a department-level administrator.", style: TextStyle(color: AdminHelpers.textMuted, fontSize: 13)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: AdminHelpers.inputDecoration(label: "Username", hint: "e.g. cse_admin", icon: Icons.person_outline),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: AdminHelpers.inputDecoration(label: "Recovery Email", hint: "e.g. cse@college.edu", icon: Icons.email_outlined),
                    validator: (v) => !v!.contains('@') ? "Invalid Email" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    decoration: AdminHelpers.inputDecoration(
                      label: "Password", 
                      hint: "Min 6 characters", 
                      icon: Icons.lock_outline
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: AdminHelpers.textMuted, size: 20),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) => v!.length < 6 ? "Min 6 chars" : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDept,
                    decoration: AdminHelpers.inputDecoration(label: "Department", hint: "Select Department", icon: Icons.business_outlined),
                    items: AdminHelpers.departments
                        .where((d) => d != 'All')
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedDept = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AdminHelpers.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _addDepartmentAdmin(
                    usernameCtrl.text.trim(),
                    emailCtrl.text.trim(),
                    passwordCtrl.text.trim(),
                    selectedDept,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminHelpers.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Create Admin"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminHelpers.scaffoldBg,
      appBar: AppBar(
        title: const Text("Department Admins", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
          tooltip: "Back",
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AdminHelpers.border, height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AdminHelpers.secondaryColor : AdminHelpers.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Admin", style: TextStyle(color: Colors.white)),
      ),
      body: ResponsiveContainer(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'admin')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final docs = snapshot.data?.docs ?? [];
                  
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.supervised_user_circle_outlined, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text("No Department Admins yet", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final uid = docs[index].id;
                      final dept = (data['department'] as String?)?.trim() ?? 'Unknown';
                      final username = data['username'] ?? '—';
                      final recoveryEmail = data['recoveryEmail'] ?? data['email'] ?? '—';
                      final Color deptColor = AdminHelpers.getDeptColor(dept);

                      return Container(
                        decoration: AdminHelpers.cardDecoration(context),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // 🎨 Avatar
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: deptColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                dept.isNotEmpty ? dept[0].toUpperCase() : '?',
                                style: TextStyle(color: deptColor, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 📄 Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "$dept Admin",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminHelpers.textMain),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AdminHelpers.scaffoldBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          username,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminHelpers.primaryColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    recoveryEmail,
                                    style: const TextStyle(color: AdminHelpers.textMuted, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            // ⚡ Actions
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: AdminHelpers.primaryColor, size: 22),
                                  onPressed: () => _showEditDialog(uid, username, dept),
                                  tooltip: "Edit Admin",
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                                  onPressed: () => _deleteAdmin(uid, data['email'] ?? ''),
                                  tooltip: "Remove Admin",
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
