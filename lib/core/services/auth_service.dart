import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
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
