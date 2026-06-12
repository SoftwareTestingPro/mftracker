import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../widgets/google_sign_in_button.dart';
import '../../core/theme.dart';
import '../../data/services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = true;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _checkInitialAuth() async {
    final auth = ref.read(authServiceProvider);
    final user = await auth.init();
    
    // Listen for auth changes (triggered by the official Google button)
    // We do this after init() to ensure the plugin is initialized on Web.
    _authSubscription = auth.onUserChanged.listen((user) {
      if (user != null && mounted) {
        _navigateToHome();
      }
    });
    
    if (user != null && mounted) {
      _navigateToHome();
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool _isNavigating = false;

  Future<void> _navigateToHome() async {
    if (_isNavigating) return;
    _isNavigating = true;
    
    // Give the Google Picker a moment to fully dismiss its animation
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: Stack(
        children: [
          // Subtle glow effect
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.brandPrimary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Center(
            child: _isLoading 
              ? const CircularProgressIndicator(color: AppTheme.brandPrimary)
              : _buildLoginCard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary.withAlpha(200),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mutual Fund Tracker',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [Color(0xFFF8FAFC), Color(0xFF94A3B8)],
                    ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Track your mutual fund investments securely with private Google Drive storage.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 32),
          
          // Why Choose Section
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          const Text(
            'WHY MF TRACKER?',
            style: TextStyle(color: AppTheme.brandPrimary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          _buildUspRow(Icons.visibility_off_outlined, '100% Anonymous', 'No PAN card, phone number, or personal info required.'),
          const SizedBox(height: 12),
          _buildUspRow(Icons.insights, 'Professional Stats', 'Get high-precision XIRR & CAGR missing in other apps.'),
          const SizedBox(height: 12),
          _buildUspRow(Icons.cloud_done_outlined, 'Private Storage', 'Your data stays in your Google Drive, not our servers.'),
          
          const SizedBox(height: 32),
          
          // Official Google Sign-In Button (Industry Standard)
          SizedBox(
            width: double.infinity,
            child: buildGoogleSignInButton(
              onPressed: () async {
                try {
                  final user = await ref.read(authServiceProvider).signIn();
                  // If user is null, they cancelled the picker. 
                  // No error message needed for a deliberate user action.
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Login failed: $e. Please check your internet or Google Cloud SHA-1 configuration.'),
                        backgroundColor: AppTheme.dangerColor,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 32),
          
          // Legal Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegalLink(context, 'Privacy Policy', 'assets/PRIVACY_POLICY.md'),
              const Text(' • ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              _buildLegalLink(context, 'Terms', 'assets/TERMS_OF_SERVICE.md'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegalLink(BuildContext context, String title, String assetPath) {
    return GestureDetector(
      onTap: () => _showDocumentModal(context, title, assetPath),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _showDocumentModal(BuildContext context, String title, String assetPath) async {
    final content = await DefaultAssetBundle.of(context).loadString(assetPath);
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Using a simple Text view for login screen to avoid heavy dependencies 
                      // if markdown isn't already here, but since it is in project, I can use it.
                      // Wait, I need to import it.
                      Text(content, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUspRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

