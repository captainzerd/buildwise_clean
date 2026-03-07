import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/login_activity.dart';

/// Single source of truth for authentication state.
/// Firebase.initializeApp() must be called in main.dart BEFORE AuthService.init().
class AuthService extends ChangeNotifier {
  AppUser? _currentUser;
  bool _initialized = false;
  StreamSubscription<User?>? _authSub;

  AppUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  ProfessionalType get role => _currentUser?.role ?? ProfessionalType.homeowner;

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

      // Record login activity
      await _writeLoginActivity(firebaseUser.uid, firebaseUser.providerData);
    } catch (e) {
      debugPrint('AuthService: failed to load user profile – $e');
      _currentUser = null;
    }

    notifyListeners();
  }

  Future<void> _writeLoginActivity(
    String uid,
    List<UserInfo> providerData,
  ) async {
    try {
      String method = 'email';
      if (providerData.any((p) => p.providerId == 'google.com')) {
        method = 'google';
      } else if (providerData.any((p) => p.providerId == 'phone')) {
        method = 'phone';
      }

      String platform = 'other';
      if (!kIsWeb) {
        if (Platform.isAndroid) platform = 'android';
        if (Platform.isIOS) platform = 'ios';
      } else {
        platform = 'web';
      }

      final activity = LoginActivity(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        platform: platform,
        signInMethod: method,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('login_activity')
          .doc(activity.id)
          .set(activity.toMap());
    } catch (e) {
      debugPrint('AuthService._writeLoginActivity: $e');
    }
  }

  AppUser _profileFromFirebaseUser(User u) => AppUser(
        uid: u.uid,
        email: u.email ?? '',
        displayName: u.displayName ?? '',
        role: ProfessionalType.homeowner,
        emailVerified: u.emailVerified,
        createdAt: DateTime.now(),
      );

  // ---- Public API ----

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required ProfessionalType role,
    String? firstName,
    String? lastName,
    String? phone,
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
        firstName: firstName,
        lastName: lastName,
        phone: phone,
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

  // ── Phone OTP ──

  /// Sends an SMS OTP to [phoneE164] (e.g. '+233201234567').
  /// Returns the verificationId needed for [verifyPhoneOtp].
  Future<String> sendPhoneOtp(String phoneE164) async {
    final completer = Completer<String>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneE164,
      verificationCompleted: (_) {},
      verificationFailed: (e) => completer.completeError(e),
      codeSent: (verificationId, _) => completer.complete(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  /// Links phone credential to the current user, then marks phone as verified
  /// in Firestore.
  Future<void> verifyPhoneOtp(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final firebaseUser = FirebaseAuth.instance.currentUser!;
    await firebaseUser.linkWithCredential(credential);

    final uid = firebaseUser.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'phoneVerified': true,
      'phoneVerifiedAt': FieldValue.serverTimestamp(),
    });

    _currentUser = _currentUser?.copyWith(
      phoneVerified: true,
      phoneVerifiedAt: DateTime.now(),
    );
    notifyListeners();
  }

  /// Signs in with a phone credential (for phone-only accounts).
  Future<void> signInWithPhone(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  /// Signs out all other sessions by calling the Cloud Function
  /// `revokeUserSessions`.
  Future<void> revokeAllSessions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('revokeUserSessions')
          .call({'uid': uid});
    } catch (e) {
      debugPrint('AuthService.revokeAllSessions: $e');
      rethrow;
    }
  }

  /// Enrolls the current user in TOTP / phone 2FA.
  Future<void> enrollTwoFactor(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
    // Enroll using Firebase Multi-factor
    await FirebaseAuth.instance.currentUser!.multiFactor.enroll(
      assertion,
      displayName: 'Phone',
    );

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'twoFactorEnabled': true});

    _currentUser = _currentUser?.copyWith(twoFactorEnabled: true);
    notifyListeners();
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
        role: ProfessionalType.homeowner,
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

  /// Updates the user's basic profile fields (name, phone, avatar URL).
  /// Only the non-null fields are written; pass [clearPhoto] to remove the photo.
  Future<void> updateProfile({
    String? displayName,
    String? phone,
    bool clearPhone = false,
    String? photoUrl,
    bool clearPhoto = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (clearPhone) {
      updates['phone'] = FieldValue.delete();
    } else if (phone != null) {
      updates['phone'] = phone;
    }
    if (clearPhoto) {
      updates['photoUrl'] = FieldValue.delete();
    } else if (photoUrl != null) {
      updates['photoUrl'] = photoUrl;
    }
    if (updates.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update(updates);

    if (displayName != null) {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(displayName);
    }

    _currentUser = AppUser(
      uid: _currentUser!.uid,
      email: _currentUser!.email,
      displayName: displayName ?? _currentUser!.displayName,
      role: _currentUser!.role,
      emailVerified: _currentUser!.emailVerified,
      createdAt: _currentUser!.createdAt,
      phone: clearPhone ? null : (phone ?? _currentUser!.phone),
      photoUrl: clearPhoto ? null : (photoUrl ?? _currentUser!.photoUrl),
      subscriptionTier: _currentUser!.subscriptionTier,
    );
    notifyListeners();
  }

  /// Switches the user's role between owner and pm.
  Future<void> updateRole(ProfessionalType role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'role': role.name});
    _currentUser = _currentUser?.copyWith(role: role);
    notifyListeners();
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
