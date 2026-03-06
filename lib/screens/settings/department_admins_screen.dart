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
          // 🔄 Fallback: Use 'Plus Addressing' (email+admin@domain.com)
          // This creates a unique Firebase account but delivers email to the same inbox.
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
  // 🖊️ SHOW ADD DIALOG
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
                  // Username
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(labelText: "Username", hintText: "e.g. placement_admin"),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 12),
                  // Email
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: "Recovery Email", hintText: "e.g. cse@college.edu"),
                    validator: (v) => !v!.contains('@') ? "Invalid Email" : null,
                  ),
                  const SizedBox(height: 12),
                  // Password
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: "Password",
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) => v!.length < 6 ? "Min 6 chars" : null,
                  ),
                  const SizedBox(height: 12),
                  // Department Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedDept,
                    decoration: const InputDecoration(labelText: "Department"),
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
              child: const Text("Cancel"),
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
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? AdminHelpers.secondaryColor : AdminHelpers.primaryColor,
                foregroundColor: Colors.white,
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
    return ResponsiveContainer(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Department Admins"),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
            onPressed: () => Navigator.pop(context),
          ),
          titleTextStyle: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AdminHelpers.secondaryColor : AdminHelpers.primaryColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("Add Admin", style: TextStyle(color: Colors.white)),
        ),
        body: _loading
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
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final uid = docs[index].id;
                      final dept = data['department'] ?? 'Unknown';
                      final username = data['username'] ?? '—';
                      final email = data['email'] ?? '—'; // Auth email (e.g. user@leavex.admin)
                      final recoveryEmail = data['recoveryEmail'] ?? email; // Real email

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AdminHelpers.getDeptColor(dept).withOpacity(0.1),
                            child: Text(
                              dept.substring(0, 1),
                              style: TextStyle(color: AdminHelpers.getDeptColor(dept), fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text("$dept Admin ($username)", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(recoveryEmail),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteAdmin(uid, email),
                          ),
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
