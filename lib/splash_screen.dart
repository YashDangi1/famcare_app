import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'main_app_shell.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _loadingText = 'Loading...';
  @override
  void initState() {
    super.initState();
    _startAuthRouting();
  }

  Future<void> _startAuthRouting() async {
    // 1. Wait for 2.5 seconds to show the beautiful splash UI
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    // 2. Guard: wait for Supabase to be ready (may not be in alarm mode)
    int attempts = 0;
    while (attempts < 150) { // Wait up to 30 seconds
      try {
        Supabase.instance.client;
        break;
      } catch (_) {
        if (attempts == 15 && mounted) {
          setState(() {
             _loadingText = 'Connecting to securely restore session...';
          });
        }
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
    }

    if (!mounted) return;

    // 3. Check if user is already logged in
    Session? session;
    try {
      session = Supabase.instance.client.auth.currentSession;
    } catch (e) {
      debugPrint("Supabase init timed out or failed: $e");
    }

    // 3. Navigate based on auth state
    if (session != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainAppShell()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0EA5E9), // Solid brand color
      body: SafeArea(
        child: Stack(
          children: [
            // Center Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.heartPulse,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'FamCare',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Family Health Tracker',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Progress Indicator
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _loadingText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
