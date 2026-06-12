import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/theme.dart';
import '../providers/security_provider.dart';

class SecurityWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const SecurityWrapper({super.key, required this.child});

  @override
  ConsumerState<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends ConsumerState<SecurityWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial authentication attempt if already locked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(securityProvider.notifier).lock();
    } else if (state == AppLifecycleState.resumed) {
      _checkAuth();
    }
  }

  void _checkAuth() {
    final securityState = ref.read(securityProvider);
    if (securityState.isLocked) {
      ref.read(securityProvider.notifier).authenticate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final securityState = ref.watch(securityProvider);

    return Stack(
      children: [
        // The main application content
        // We keep it in the tree to preserve state, but ignore interactions when locked
        IgnorePointer(
          ignoring: securityState.isLocked,
          child: widget.child,
        ),
        
        // The lock screen overlay
        if (securityState.isLocked)
          _buildLockScreen(context),
      ],
    );
  }

  Widget _buildLockScreen(BuildContext context) {
    return Material(
      color: AppTheme.bgPrimary,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.bgPrimary,
              AppTheme.bgSecondary.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Security Icon
              Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.brandPrimary.withValues(alpha: 0.2), width: 2),
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  size: 60,
                  color: AppTheme.brandPrimary,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Portfolio Locked',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please verify your identity to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 60),
              // Unlock Button
              ElevatedButton.icon(
                onPressed: () => ref.read(securityProvider.notifier).authenticate(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 8,
                  shadowColor: AppTheme.brandPrimary.withValues(alpha: 0.4),
                ),
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text(
                  'Unlock App',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
