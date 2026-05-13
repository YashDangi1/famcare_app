import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- States ---
  bool _isSigningIn = true; // Toggle between Login and Signup
  bool _loading = false;
  bool _obscurePassword = true;

  // --- Controllers & Form Key ---
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Auth Logic (Email Standard) ---
  Future<void> _submit() async {
    // Form validate karo (jaisa normal apps mein hota hai)
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final scaffold = ScaffoldMessenger.of(context);

    try {
      if (_isSigningIn) {
        // Login Logic
        await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
        // `main.dart` ka AuthCheck automatically dashboard par bhej dega success hone par
      } else {
        // Sign Up Logic
        await Supabase.instance.client.auth.signUp(email: email, password: password);
        scaffold.showSnackBar(const SnackBar(content: Text('Verification email sent! Please check your inbox.'), backgroundColor: Colors.green));
        setState(() => _isSigningIn = true); // Switch back to login after signup
      }
    } on AuthException catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Auth Error: ${e.message}'), backgroundColor: Colors.red));
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Unexpected Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- UI Sections (Inspired by WhatsApp Examples) ---

  Widget _buildTopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // space like WhatsApp top
        const SizedBox(height: 60), 
        Text(
          _isSigningIn ? 'Welcome back!' : 'Create an account',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSigningIn 
              ? 'Sign in to continue tracking your family health vault.'
              : 'Join FamCare to securely manage your family\'s health prescriptions and vitals.',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        // Email Input
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email Address',
            prefixIcon: const Icon(LucideIcons.mail, color: Color(0xFF0EA5E9), size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          validator: (val) {
            if (val == null || val.isEmpty) return 'Please enter your email';
            if (!val.contains('@')) return 'Enter a valid email address';
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Password Input
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(LucideIcons.lock, color: Color(0xFF0EA5E9), size: 20),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff, size: 20, color: Colors.grey),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          validator: (val) {
            if (val == null || val.isEmpty) return 'Please enter your password';
            if (val.length < 6) return 'Password must be at least 6 characters';
            return null;
          },
        ),
        if (_isSigningIn)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {}, // Future feature: Forgot password
              child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 13)),
            ),
          ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // MAIN SUBMIT BUTTON (like WhatsApp 'Next')
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 2,
            ),
            child: _loading 
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    _isSigningIn ? 'Sign In' : 'Sign Up',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        // TOGGLE TEXT (Bottom like WhatsApp 'Resend' but standard style)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_isSigningIn ? "Don't have an account?" : "Already have an account?"),
            TextButton(
              onPressed: () {
                setState(() => _isSigningIn = !_isSigningIn);
                _emailController.clear();
                _passwordController.clear();
              },
              child: Text(
                _isSigningIn ? 'Sign Up' : 'Sign In',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopSection(),
                _buildInputFields(),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}