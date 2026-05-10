import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _googleSignInInitialized = false;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;

    if (user != null) {
      await user.updateDisplayName(name.trim());

      await _createUserDocumentIfNeeded(
        user: user,
        fallbackName: name.trim(),
        provider: 'password',
      );
    }

    return credential;
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      return _signInWithGoogleWeb();
    }

    return _signInWithGoogleNative();
  }

  Future<UserCredential> _signInWithGoogleWeb() async {
    final googleProvider = GoogleAuthProvider();

    googleProvider.addScope('email');
    googleProvider.addScope('profile');

    final credential = await _auth.signInWithPopup(googleProvider);

    final user = credential.user;

    if (user != null) {
      await _createUserDocumentIfNeeded(
        user: user,
        fallbackName: user.displayName ?? 'Utente PocketPlan',
        provider: 'google',
      );
    }

    return credential;
  }

  Future<UserCredential> _signInWithGoogleNative() async {
    await _initializeGoogleSignInIfNeeded();

    final googleUser = await GoogleSignIn.instance.authenticate(
      scopeHint: const <String>[
        'email',
        'profile',
      ],
    );

    final googleAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    final user = userCredential.user;

    if (user != null) {
      await _createUserDocumentIfNeeded(
        user: user,
        fallbackName: googleUser.displayName ?? 'Utente PocketPlan',
        provider: 'google',
      );
    }

    return userCredential;
  }

  Future<void> _initializeGoogleSignInIfNeeded() async {
    if (_googleSignInInitialized) return;

    await GoogleSignIn.instance.initialize();

    _googleSignInInitialized = true;
  }

  Future<void> _createUserDocumentIfNeeded({
    required User user,
    required String fallbackName,
    required String provider,
  }) async {
    final userRef = _db.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    final existingData = userDoc.data();

    final cleanName = fallbackName.trim().isNotEmpty
        ? fallbackName.trim()
        : user.displayName?.trim();

    if (!userDoc.exists) {
      await userRef.set({
        'uid': user.uid,
        'name': cleanName ?? 'Utente PocketPlan',
        'email': user.email ?? '',
        'photo_url': user.photoURL,
        'role': 'user',
        'currency': 'EUR',
        'provider': provider,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return;
    }

    await userRef.set({
      'uid': user.uid,
      'name': cleanName ?? existingData?['name'] ?? 'Utente PocketPlan',
      'email': user.email ?? existingData?['email'] ?? '',
      'photo_url': user.photoURL ?? existingData?['photo_url'],
      'provider': existingData?['provider'] ?? provider,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logout() async {
    await _auth.signOut();

    if (!kIsWeb) {
      try {
        await _initializeGoogleSignInIfNeeded();
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Evita blocchi sul logout se Google Sign-In non era inizializzato.
      }
    }
  }
}