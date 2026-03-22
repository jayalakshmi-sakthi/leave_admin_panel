import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notification_service.dart';

class AdminSignupScreen extends StatefulWidget {
  const AdminSignupScreen({super.key});

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _deptController = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;

  static const Color primaryBlue = Color(0xFF001C3D);
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color softText = Color(0xFF64748B);
  static const Color cardBg = Colors.white;
  static const Color scaffoldBg = Color(0xFFF8FAFC);

  Future<void> _signup() async {
    final username = _usernameController.text.trim().toLowerCase();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    final name = _nameController.text.trim();
    final dept = _deptController.text.trim();

    if (username.isEmpty || password.isEmpty || name.isEmpty) {
      _showError("Please fill in the required fields.");
      return;
    }

    if (password != confirm) {
      _showError("Passwords do not match.");
      return;
    }

    if (password.length < 6) {
      _showError("Password must be at least 6 characters.");
      return;
    }

    setState(() => _loading = true);

    try {
      // 1. Check if Username is taken
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
      
      if (existing.docs.isNotEmpty) {
        throw "Username '$username' is already taken. Try another.";
      }

      // 2. Use real email or fallback shadow email
      final emailToUse = email.isNotEmpty ? email : "$username@leavex.admin";

      // 3. Create Auth Account
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailToUse, 
        password: password,
      );

      final uid = cred.user!.uid;

      // 4. Create Firestore Document
      // Note: First user in the system could be Super Admin
      final adminsSnap = await FirebaseFirestore.instance.collection('users')
          .where('role', whereIn: ['admin', 'super_admin']).limit(1).get();
      
      final String role = adminsSnap.docs.isEmpty ? 'super_admin' : 'admin';

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'username': username,
        'email': emailToUse,
        'role': role,
        'department': dept.isNotEmpty ? dept : 'General',
        'isApproved': true, // Auto-approve first admin, others might need super-admin approval
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account Created! You can now log in."), backgroundColor: Colors.green),
      );
      Navigator.pop(context); // Back to login

    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 450,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Create Admin Profile", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkSlate)),
                const SizedBox(height: 8),
                const Text("Enter your details to register as a console admin.", style: TextStyle(color: softText, fontSize: 13)),
                const SizedBox(height: 32),

                _buildInputField(controller: _nameController, label: "Full Name", hint: "e.g. John Doe", icon: Icons.person_outline),
                const SizedBox(height: 16),
                _buildInputField(controller: _usernameController, label: "Admin Username", hint: "e.g. cse_admin", icon: Icons.alternate_email),
                const SizedBox(height: 16),
                _buildInputField(controller: _deptController, label: "Department", hint: "e.g. CSE or MECH", icon: Icons.business_outlined),
                const SizedBox(height: 16),
                _buildInputField(controller: _passwordController, label: "Password", hint: "••••••••", icon: Icons.lock_outline, obscureText: true),
                const SizedBox(height: 16),
                _buildInputField(controller: _confirmPasswordController, label: "Confirm Password", hint: "••••••••", icon: Icons.lock_reset_outlined, obscureText: true),
                
                const SizedBox(height: 32),
                _buildSignupButton(),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Back to Login", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: darkSlate)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: primaryBlue, size: 20),
            filled: true,
            fillColor: scaffoldBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupButton() => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _loading ? null : _signup,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading 
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : const Text("Register Admin", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );
}
