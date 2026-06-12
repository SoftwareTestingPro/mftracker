import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth_android/local_auth_android.dart';
import '../../data/services/auth_service.dart';

final securityProvider = NotifierProvider<SecurityNotifier, SecurityState>(() {
  return SecurityNotifier();
});

class SecurityState {
  final bool isEnabled;
  final bool isLocked;
  final bool canCheckBiometrics;
  final List<BiometricType> availableBiometrics;

  SecurityState({
    this.isEnabled = false,
    this.isLocked = false,
    this.canCheckBiometrics = false,
    this.availableBiometrics = const [],
  });

  SecurityState copyWith({
    bool? isEnabled,
    bool? isLocked,
    bool? canCheckBiometrics,
    List<BiometricType>? availableBiometrics,
  }) {
    return SecurityState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      canCheckBiometrics: canCheckBiometrics ?? this.canCheckBiometrics,
      availableBiometrics: availableBiometrics ?? this.availableBiometrics,
    );
  }
}

class SecurityNotifier extends Notifier<SecurityState> {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  SecurityState build() {
    // Watch auth state to re-initialize when user changes
    final userAsync = ref.watch(authStateProvider);
    
    // Default state
    final initialState = SecurityState();
    
    userAsync.whenData((user) {
      if (user != null) {
        _init(user.id);
      }
    });

    return initialState;
  }

  Future<void> _init(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('mft_app_security_enabled_$userId') ?? false;
    
    bool canCheckBiometrics = false;
    List<BiometricType> availableBiometrics = [];
    
    try {
      canCheckBiometrics = await _auth.canCheckBiometrics;
      availableBiometrics = await _auth.getAvailableBiometrics();
    } catch (e) {
      print('Error checking biometrics: $e');
    }

    state = state.copyWith(
      isEnabled: isEnabled,
      isLocked: isEnabled, // If enabled, start locked
      canCheckBiometrics: canCheckBiometrics,
      availableBiometrics: availableBiometrics,
    );
  }

  Future<void> toggleSecurity(bool enable) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mft_app_security_enabled_${user.id}', enable);
    state = state.copyWith(isEnabled: enable);
  }

  Future<bool> authenticate() async {
    if (!state.isEnabled) return true;

    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to access your portfolio',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allows PIN/Pattern fallback
        ),
        authMessages: [
          AndroidAuthMessages(
            signInTitle: 'App Security',
            biometricHint: 'Verify identity',
          ),
        ],
      );

      if (didAuthenticate) {
        state = state.copyWith(isLocked: false);
      }
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }

  void lock() {
    if (state.isEnabled) {
      state = state.copyWith(isLocked: true);
    }
  }
}
