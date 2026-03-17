import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _usernameController = TextEditingController(); // 🔄 Changed from _email
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;

  // 🎨 Theme Colors (Soulful Palette - Matched with User App)
  static const Color primaryBlue = Color(0xFF001C3D); // Navy
  static const Color darkSlate = Color(0xFF1E293B);   // Slate 800 (Softer)
  static const Color softText = Color(0xFF64748B);    // Slate 500
  static const Color cardBg = Colors.white;
  static const Color scaffoldBg = Color(0xFFF8FAFC);  // Slate 50

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // 🔐 ADMIN LOGIN (USERNAME -> EMAIL LOOKUP)
  // --------------------------------------------------
  Future<void> _login() async {
    final input = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _showError("Please enter your admin credentials");
      return;
    }

    setState(() => _loading = true);

    try {
      String? emailToTry;
      
      // 1. Determine Strategy
      if (input.contains('@')) {
        emailToTry = input;
      } else {
        // 🔍 Strategy: Username Lookup in Firestore
        try {
           final snap = await _fire.collection('users')
               .where('username', isEqualTo: input)
               .limit(1)
               .get();
               
           if (snap.docs.isNotEmpty) {
             emailToTry = snap.docs.first.data()['email'];
             debugPrint("🎯 Found mapped email: $emailToTry");
           }
        } catch (e) {
           debugPrint("⚠️ Firestore lookup skipped/failed: $e");
           // If it's a network error here, Firestore usually throws/times out
        }
        
        // 👤 Fallback: Shadow Admin
        if (emailToTry == null) {
          emailToTry = "$input@leavex.admin";
        }
      }

      // 2. Authenticate (Single Attempt)
      final cred = await _auth.signInWithEmailAndPassword(
        email: emailToTry!, 
        password: password,
      );

      final uid = cred.user!.uid;
      debugPrint("✅ Auth Success. UID: $uid (Used: $emailToTry)");

      // 3. Verify Role in Firestore (Isolated Check)
      final userDoc = await _fire.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        // This handles cases where Auth exists but DB record was deleted (Zombie account)
        await _auth.signOut();
        throw "Your admin record was not found in the database. Please contact the Super Admin.";
      }

      final role = userDoc.data()?['role'];
      if (role != 'admin' && role != 'super_admin') {
        await _auth.signOut();
        throw "Access denied. Your account does not have administrator privileges.";
      }

      if (!mounted) return;

      // 🎉 SUCCESS → DASHBOARD
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Successful! Redirecting..."), backgroundColor: Colors.green),
      );
      
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.pushReplacementNamed(context, '/dashboard');

    } on FirebaseAuthException catch (e) {
      debugPrint("❌ Auth Error: ${e.code} - ${e.message}");
      String msg = e.message ?? "Auth Error";
      
      if (e.code == 'network-request-failed') {
        msg = "Network connection failed. If you are using a custom domain, ensure it is whitelisted in Firebase Console (Authentication -> Settings -> Authorized Domains).";
      } else if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        msg = "Invalid credentials. Please check your username and password.";
      }
      
      _showError(msg);
    } catch (e) {
      debugPrint("❌ General Error: $e");
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --------------------------------------------------
  // ❌ ERROR SNACKBAR
  // --------------------------------------------------
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // 🔐 FORGOT PASSWORD (USERNAME SUPPORT)
  // --------------------------------------------------
  void _showForgotPasswordDialog() {
    final resetInputController = TextEditingController();
    bool loading = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            "Reset Password",
            style: TextStyle(fontWeight: FontWeight.bold, color: darkSlate),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter your Username OR Registered Email. We'll find your account and send a reset link.",
                style: TextStyle(color: softText, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: resetInputController,
                decoration: InputDecoration(
                  labelText: "Username or Email",
                  hintText: "e.g. placement_cell",
                  prefixIcon: const Icon(Icons.search, color: primaryBlue),
                  filled: true,
                  fillColor: scaffoldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: softText)),
            ),
            ElevatedButton(
              onPressed: loading ? null : () async {
                final input = resetInputController.text.trim();
                if (input.isEmpty) {
                  _showError("Please enter username or email");
                  return;
                }

                setDialogState(() => loading = true);

                try {
                  String? emailToSend;

                  // 🔍 STEP 1: Smart Lookup
                  QuerySnapshot? snap;
                  
                  if (input.contains('@')) {
                    // Try finding by Recovery Email OR Auth Email
                    snap = await _fire.collection('users')
                        .where('recoveryEmail', isEqualTo: input)
                        .limit(1)
                        .get();
                    
                    if (snap.docs.isEmpty) {
                       snap = await _fire.collection('users')
                         .where('email', isEqualTo: input)
                         .limit(1)
                         .get();
                    }
                  } else {
                    // Try finding by Username
                    snap = await _fire.collection('users')
                        .where('username', isEqualTo: input)
                        .limit(1)
                        .get();
                  }

                  // 🎯 STEP 2: Resolve Email
                  if (snap != null && snap.docs.isNotEmpty) {
                    final data = snap.docs.first.data() as Map<String, dynamic>;
                    // Prefer the Auth Email for reset (Firebase requirement), 
                    // but the ink will arrive at the real inbox due to aliasing/plus-addressing.
                    emailToSend = data['email']; 
                  } else {
                    // If not found in DB but looks like email, try sending directly (legacy/superadmin)
                    if (input.contains('@')) emailToSend = input;
                  }

                  // 📧 STEP 3: Send Reset
                  if (emailToSend != null) {
                    await _auth.sendPasswordResetEmail(email: emailToSend);
                    debugPrint("📧 Reset link sent to: $emailToSend");
                    
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("✅ Reset link sent to: $emailToSend\n(Check Spam folder too!)"),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 8),
                          margin: const EdgeInsets.all(20),
                        ),
                      );
                    }
                  } else {
                     debugPrint("❌ User not found for reset: $input");
                     if (mounted) {
                        // For this internal app, let's be specific
                        _showError("Username '$input' not found within users collection.");
                        setDialogState(() => loading = false); // Stop loading manually since we didn't pop
                     }
                  }
                } catch (e) {
                  debugPrint("❌ Reset Error: $e");
                  _showError("Error: ${e.toString()}");
                } finally {
                  if (mounted) setDialogState(() => loading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: loading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Send Reset Link", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // 🖥 UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 450,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconHeader(),
                const SizedBox(height: 24),
                const Text(
                  "Admin_LeaveX",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: darkSlate,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "LeaveX Management Console",
                  style: TextStyle(color: softText),
                ),
                const SizedBox(height: 40),

                // 👤 Admin ID Input
                _buildInputField(
                  controller: _usernameController,
                  label: "Username or Email",
                  hint: "Username",
                  icon: Icons.admin_panel_settings_outlined,
                  obscureText: false,
                ),

                const SizedBox(height: 20),

                // 🔑 Password
                _buildInputField(
                  controller: _passwordController,
                  label: "Password",
                  hint: "••••••••",
                  icon: Icons.lock_outline,
                  obscureText: !_showPassword,
                  suffix: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: softText,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),

                const SizedBox(height: 12),
                
                // 🔗 Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                _buildLoginButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // 🧩 UI HELPERS
  // --------------------------------------------------
  Widget _buildIconHeader() => Image.asset(
        'assets/logo.png',
        width: 120, // ✅ Slightly smaller for better proportion
        height: 120,
        fit: BoxFit.contain,
      );

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: darkSlate,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          // Removed explicit keyboardType for flexibility with usernames
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: softText.withOpacity(0.5)),
            prefixIcon: Icon(icon, color: primaryBlue),
            suffixIcon: suffix,
            filled: true,
            fillColor: scaffoldBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _loading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _loading
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                )
              : const Text(
                  "Access Dashboard",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      );
}
