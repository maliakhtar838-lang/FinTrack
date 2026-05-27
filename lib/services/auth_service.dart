import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/app_models.dart';

class AuthService {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();

  fb.User? get currentUser => _auth.currentUser;

  Future<fb.UserCredential> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;

    if (user != null) {
      final profile = UserProfile(
        uid: user.uid,
        email: user.email ?? email.trim(),
        totalBalance: 0,
      );

      await _firestore.collection('users').doc(user.uid).set(
            profile.toMap(),
            SetOptions(merge: true),
          );
    }

    return credential;
  }

  Future<fb.UserCredential> login({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<void> logout() => _auth.signOut();
}
