import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';

/// Single source of truth for authentication state.
/// Firebase.initializeApp() must be called in main.dart BEFORE AuthService.init().
class AuthService extends ChangeNotifier {
  AppUser? _currentUser;
  bool _initialized = false;
  StreamSubscription<User?>? _authSub;

  AppUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  UserRole get role => _currentUser?.role ?? UserRole.owner;

  /// Reflects the Firebase emailVerified flag (may differ from Firestore profile
  /// until refreshEmailVerificationStatus() is called).
  bool get isEmailVerified =>
      FirebaseAuth.instance.currentUser?.emailVerified ?? false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      _onAuthStateChanged,
      onError: (e) => debugPrint('AuthService stream error: $e'),
    );
  }

  // ---- Auth state ----

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null || firebaseUser.isAnonymous) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      _currentUser = doc.exists
          ? AppUser.fromDoc(doc)
          : _profileFromFirebaseUser(firebaseUser);
    } catch (e) {
      debugPrint('AuthService: failed to load user profile – $e');
      _currentUser = null;
    }

    notifyListeners();
  }

  AppUser _profileFromFirebaseUser(User u) => AppUser(
        uid: u.uid,
        email: u.email ?? '',
        displayName: u.displayName ?? '',
        role: UserRole.owner,
        emailVerified: u.emailVerified,
        createdAt: DateTime.now(),
      );

  // ---- Public API ----

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user!;

    try {
      await user.updateDisplayName(displayName);

      final appUser = AppUser(
        uid: user.uid,
        email: email,
        displayName: displayName,
        role: role,
        emailVerified: false,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(appUser.toMap());

      await user.sendEmailVerification();
    } catch (e) {
      // Roll back the Firebase Auth account so the user can try again cleanly.
      await user.delete();
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Force-refresh the ID token so the session immediately picks up any
    // custom claims (role, admin) that were set by the Cloud Function.
    await cred.user?.getIdToken(true);
  }

  /// Sign in or sign up with Google. Creates a Firestore user doc on first sign-in.
  Future<void> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final user = cred.user!;
    // Create Firestore profile on first Google sign-in.
    final db = FirebaseFirestore.instance;
    final docRef = db.collection('users').doc(user.uid);
    final snap = await docRef.get();
    if (!snap.exists) {
      final appUser = AppUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
        role: UserRole.owner,
        emailVerified: true,
        createdAt: DateTime.now(),
      );
      await docRef.set(appUser.toMap());
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> sendEmailVerification() async {
    await FirebaseAuth.instance.currentUser?.sendEmailVerification();
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  /// Changes the current user's password after re-authenticating.
  Future<void> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) {
      throw Exception('No signed-in user.');
    }
    final credential = EmailAuthProvider.credential(
      email: firebaseUser.email!,
      password: currentPassword,
    );
    await firebaseUser.reauthenticateWithCredential(credential);
    await firebaseUser.updatePassword(newPassword);
  }

  /// Permanently deletes the current user's account.
  /// Re-authenticates first (Firebase requirement for sensitive operations).
  Future<void> deleteAccount(String password) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) {
      throw Exception('No signed-in user.');
    }

    final credential = EmailAuthProvider.credential(
      email: firebaseUser.email!,
      password: password,
    );
    await firebaseUser.reauthenticateWithCredential(credential);

    final uid = firebaseUser.uid;
    final db = FirebaseFirestore.instance;

    // Delete Firestore profile docs.
    // Sub-collections (projects, contracts, etc.) are cleaned up by
    // Cloud Functions in production.
    await db.collection('users').doc(uid).delete();
    try {
      await db.collection('pm_profiles').doc(uid).delete();
    } catch (_) {}

    await firebaseUser.delete();
  }

  /// Re-reads Firebase user to pick up emailVerified after the user
  /// has clicked the verification link in their inbox.
  Future<void> refreshEmailVerificationStatus() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    await firebaseUser.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed == null) return;

    if (_currentUser != null &&
        refreshed.emailVerified != _currentUser!.emailVerified) {
      // Update Firestore profile flag
      await FirebaseFirestore.instance
          .collection('users')
          .doc(refreshed.uid)
          .update({'emailVerified': refreshed.emailVerified});

      _currentUser = _currentUser!.copyWith(
        emailVerified: refreshed.emailVerified,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
