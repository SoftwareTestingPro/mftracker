import 'package:google_sign_in/google_sign_in.dart' as gsis;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authStateProvider = StreamProvider<gsis.GoogleSignInAccount?>((ref) async* {
  final auth = ref.watch(authServiceProvider);
  // Yield initial value immediately to prevent 'forever loading'
  yield auth.user;
  // Yield subsequent changes
  yield* auth.onUserChanged;
});

class AuthService {
  final gsis.GoogleSignIn _googleSignIn = gsis.GoogleSignIn(
    clientId: '942132460645-c5j53hi4gh0dnonl1cakkubp5lfmvi1v.apps.googleusercontent.com',
    serverClientId: '942132460645-c5j53hi4gh0dnonl1cakkubp5lfmvi1v.apps.googleusercontent.com',
    scopes: [
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  gsis.GoogleSignInAccount? _user;
  gsis.GoogleSignInAccount? get user => _user;
  String? _token;
  String? get token => _token;

  /// Stream of user changes, used to react to sign-ins from the official button.
  Stream<gsis.GoogleSignInAccount?> get onUserChanged => _googleSignIn.onCurrentUserChanged;

  /// Initializes the auth state.
  Future<gsis.GoogleSignInAccount?> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      if (isLoggedIn) {
        // Attempt to restore the session without showing the UI
        _user = await _googleSignIn.signInSilently();
        
        if (_user != null) {
          final auth = await _user!.authentication;
          _token = auth.accessToken;
        } else {
          // If silent sign-in returns null, the session is likely expired
          await prefs.setBool('is_logged_in', false);
        }
      }
    } catch (e) {
      print('Auth initialization error: $e');
    }
    return _user;
  }

  /// Signs in the user, triggering the interactive sign-in popup with all requested scopes.
  Future<gsis.GoogleSignInAccount?> signIn() async {
    try {
      // Force a TOTAL disconnection to ensure the Account Picker MUST appear.
      // disconnect() is much stronger than signOut() on Android.
      await _googleSignIn.disconnect().catchError((_) {});
      
      _user = await _googleSignIn.signIn();
      
      if (_user != null) {
        final auth = await _user!.authentication;
        _token = auth.accessToken;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
      }
      
      return _user;
    } catch (error) {
      print('Sign-in error: $error');
      rethrow;
    }
  }

  /// Signs out the user and clears the local state.
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      
      final keys = prefs.getKeys().where((k) => 
        k.startsWith('drive_cache_') || 
        k.startsWith('cached_holdings_') ||
        k == 'cached_holdings'
      ).toList();
      for (var k in keys) await prefs.remove(k);

      await _googleSignIn.signOut();
      _user = null;
      _token = null;
    } catch (e) {
      print('Sign-out error: $e');
    }
  }

  /// Deletes the user account by disconnecting from Google Sign-In and wiping all local data.
  Future<void> deleteAccount() async {
    try {
      // 1. Wipe ALL local data (settings, cache, session info)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. Revoke Google OAuth permissions to ensure a fresh start
      await _googleSignIn.disconnect();
      
      // 3. Clear in-memory state
      _user = null;
      _token = null;
    } catch (e) {
      print('Delete account error: $e');
    }
  }

  bool get isSignedIn => _user != null;
}
