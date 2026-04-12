import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habit_tracker_ios/core/services/firestore_sync_service.dart';
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
  final Ref _ref;
  AuthNotifier(this._ref) : super(const AuthState(status: AuthStatus.unauthenticated)) {
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
      // Start real-time listeners on session restore
      FirestoreSyncService.startListeners(
        firebaseUser.uid,
        _ref.read(syncRefreshProvider.notifier),
      );
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
      // Start real-time listeners even for cached session
      FirestoreSyncService.startListeners(
        uid,
        _ref.read(syncRefreshProvider.notifier),
      );
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
      // Start real-time Firestore listeners for this uid
      FirestoreSyncService.startListeners(
        authUser.uid,
        _ref.read(syncRefreshProvider.notifier),
      );
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
    } catch (e, stack) {
      // Log the real error for debugging
      // ignore: avoid_print
      print('[AuthService] Unexpected sign-in error: $e\n$stack');

      String msg = 'Sign-in failed. Please try again.';
      final eStr = e.toString().toLowerCase();
      if (eStr.contains('simulator') || eStr.contains('platform') || eStr.contains('not supported')) {
        msg = 'Google Sign-In is not supported on the iOS Simulator. Please test on a real device.';
      }
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: msg,
      );
    }
  }

  /// Sign-in anonymously — for simulator/debug testing only.
  /// Use this when Google Sign-In is unavailable (e.g. iOS 26 beta simulator).
  Future<void> signInAnonymously() async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Anonymous sign-in failed.',
        );
        return;
      }
      final authUser = AuthUser.fromFirebase(firebaseUser);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUid, authUser.uid);
      await prefs.setString(_kEmail, authUser.email);
      await HiveService.init(authUser.uid);
      state = AuthState(status: AuthStatus.authenticated, user: authUser);
      FirestoreSyncService.startListeners(
        authUser.uid,
        _ref.read(syncRefreshProvider.notifier),
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Dev sign-in failed: $e',
      );
    }
  }


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

    // Stop all Firestore listeners before clearing session
    FirestoreSyncService.stopListeners();
    await HiveService.closeAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authProvider).user;
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).user?.uid;
});
