import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

const String kOwnerEmail      = 'owner@e2e.test';
const String kContractorEmail = 'contractor@e2e.test';
const String kUnverifiedEmail = 'unverified@e2e.test';
const String kTestPassword    = 'Test1234!';
const String _kProjectId      = 'building-estimator';
const String _kEmulatorAuthBase = 'http://localhost:9099';

/// Sets custom claims on a user via the Auth emulator REST API.
Future<void> _setCustomClaims(String uid, Map<String, dynamic> claims) async {
  final url = Uri.parse(
    '$_kEmulatorAuthBase/emulator/v1/projects/$_kProjectId/accounts/$uid',
  );
  final response = await http.patch(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'customAttributes': jsonEncode(claims)}),
  );
  if (response.statusCode != 200) {
    throw Exception(
      'Failed to set custom claims for $uid: ${response.statusCode} ${response.body}',
    );
  }
}

/// Creates fixture users in the emulator Auth instance and assigns custom claims.
/// Idempotent: tries sign-in first; creates if not found.
Future<void> seedFixtureUsers() async {
  final auth = FirebaseAuth.instance;

  Future<String> ensureUser(String email) async {
    try {
      final cred = await auth.signInWithEmailAndPassword(email: email, password: kTestPassword);
      await auth.signOut();
      return cred.user!.uid;
    } catch (_) {
      final cred = await auth.createUserWithEmailAndPassword(email: email, password: kTestPassword);
      await auth.signOut();
      return cred.user!.uid;
    }
  }

  final ownerUid      = await ensureUser(kOwnerEmail);
  final contractorUid = await ensureUser(kContractorEmail);
  await ensureUser(kUnverifiedEmail);

  await _setCustomClaims(ownerUid,      {'email_verified': true, 'subscriptionTier': 'pro'});
  await _setCustomClaims(contractorUid, {'email_verified': true, 'role': 'contractor'});

  final contractorCred = await auth.signInWithEmailAndPassword(
    email: kContractorEmail, password: kTestPassword,
  );
  await contractorCred.user!.getIdToken(true);
  await auth.signOut();
}

/// Signs in as owner and seeds a test project document.
Future<String> seedTestProject() async {
  final auth = FirebaseAuth.instance;
  final cred = await auth.signInWithEmailAndPassword(
    email: kOwnerEmail, password: kTestPassword,
  );
  final uid = cred.user!.uid;

  final ref = await FirebaseFirestore.instance.collection('projects').add({
    'ownerUid':        uid,
    'title':           'E2E Seeded Project',
    'status':          'active',
    'teamMemberUids':  <String>[],
    'collaboratorUids': <String>[],
    'observerUids':    <String>[],
    'assignedPmUid':   null,
    'budget':          100000,
    'amountSpent':     0,
    'updateFrequencyDays': 7,
    'createdAt':       DateTime.now(),
  });

  await auth.signOut();
  return ref.id;
}
