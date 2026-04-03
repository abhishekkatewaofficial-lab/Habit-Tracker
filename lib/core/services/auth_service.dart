import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_sync_service.dart';
import 'hive_service.dart';

// ── User Model ───────────────────────────────────────────────────────────────
class AuthUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  factory AuthUser.fromFirebase(User user) {
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}

// ── Auth State ────────────────────────────────────────────────────────────────
enum AuthStatus { unauthenticated, loading, authenticated }

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? errorMessage;

  const AuthState({required this.status, this.user, this.errorMessage});

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

// ── SharedPreferences Keys ────────────────────────────────────────────────────
const _kUid = 'auth_uid';
const _kEmail = 'auth_email';
const _kName = 'auth_name';
const _kPhoto = 'auth_photo';

// ── Notifier ──────────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(status: AuthStatus.unauthenticated)) {
    _init();
  }

  Future<void> _init() async {
    // Initialize Google Sign-In v7 singleton FIRST
    await GoogleSignIn.instance.initialize();

    // Then restore any existing session
    await _restoreSession();
  }

  /// Restore from a previous Firebase session on app launch
  Future<void> _restoreSession() async {
    // Priority 1: Check Firebase current user (real Auth session)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      await HiveService.init(firebaseUser.uid);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser.fromFirebase(firebaseUser),
      );
      // Trigger background hydration on existing session
      CloudSyncService.pullHydration();
      return;
    }

    // Priority 2: Fall back to SharedPreferences cache for quick rendering
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_kUid);
    if (uid != null) {
      await HiveService.init(uid);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser(
          uid: uid,
          email: prefs.getString(_kEmail) ?? '',
          displayName: prefs.getString(_kName),
          photoUrl: prefs.getString(_kPhoto),
        ),
      );
      // Even if fallback, wait for internet and pull eventually, but we only strictly pull if firebaseUser is present.
      // But we can trigger it anyway.
      CloudSyncService.pullHydration();
    }
  }

  /// Trigger REAL Google Sign-In via Firebase Auth (google_sign_in v7)
  Future<void> signInWithGoogle() async {
    state = const AuthState(status: AuthStatus.loading);

    try {
      // Step 1: Trigger the Google Account picker
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      // Step 2: Get the ID token from the account
      // In google_sign_in v7, authentication only provides idToken.
      // Firebase Auth can be signed in with just the idToken.
      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      // Step 3: Build Firebase credential using the idToken
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign into Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Authentication failed. Please try again.',
        );
        return;
      }

      final authUser = AuthUser.fromFirebase(firebaseUser);

      // Persist for fast cold-start session restoration
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUid, authUser.uid);
      await prefs.setString(_kEmail, authUser.email);
      if (authUser.displayName != null) {
        await prefs.setString(_kName, authUser.displayName!);
      }
      if (authUser.photoUrl != null) {
        await prefs.setString(_kPhoto, authUser.photoUrl!);
      }

      await HiveService.init(authUser.uid);
      state = AuthState(status: AuthStatus.authenticated, user: authUser);
      // Force immediate hydration on fresh sign in
      await CloudSyncService.pullHydration();
    } on GoogleSignInException catch (e) {
      // User cancelled — not an actual error
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Google Sign-In failed. Please try again.',
      );
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message ?? 'Firebase authentication error.',
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Sign out from Firebase and Google + clear local cache
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Silently continue — clear local session regardless
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUid);
    await prefs.remove(_kEmail);
    await prefs.remove(_kName);
    await prefs.remove(_kPhoto);

    await HiveService.closeAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authProvider).user;
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).user?.uid;
});
