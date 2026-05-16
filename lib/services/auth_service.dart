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

        // Onboarding AI
        'onboarding_completed': false,
        'ai_profile': {
          'main_goal': null,
          'interests': <String>[],
          'money_feeling': null,
          'advice_style': null,
          'ai_frequency': null,
          'created_at': null,
          'updated_at': null,
        },

        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return;
    }

    final bool alreadyHasOnboardingField =
        existingData != null && existingData.containsKey('onboarding_completed');

    final bool alreadyHasAiProfileField =
        existingData != null && existingData.containsKey('ai_profile');

    await userRef.set({
      'uid': user.uid,
      'name': cleanName ?? existingData?['name'] ?? 'Utente PocketPlan',
      'email': user.email ?? existingData?['email'] ?? '',
      'photo_url': user.photoURL ?? existingData?['photo_url'],
      'provider': existingData?['provider'] ?? provider,

      if (!alreadyHasOnboardingField) 'onboarding_completed': false,

      if (!alreadyHasAiProfileField)
        'ai_profile': {
          'main_goal': null,
          'interests': <String>[],
          'money_feeling': null,
          'advice_style': null,
          'ai_frequency': null,
          'created_at': null,
          'updated_at': null,
        },

      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> hasCompletedOnboarding() async {
    final user = currentUser;

    if (user == null) {
      return false;
    }

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    return data?['onboarding_completed'] == true;
  }

  Future<void> saveOnboardingProfile({
    required String mainGoal,
    required List<String> interests,
    required String moneyFeeling,
    required String adviceStyle,
    required String aiFrequency,
  }) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Utente non autenticato.');
    }

    await _db.collection('users').doc(user.uid).set({
      'onboarding_completed': true,
      'ai_profile': {
        'main_goal': mainGoal,
        'interests': interests,
        'money_feeling': moneyFeeling,
        'advice_style': adviceStyle,
        'ai_frequency': aiFrequency,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      },
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getAiProfile() async {
    final user = currentUser;

    if (user == null) {
      return null;
    }

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    if (data == null) {
      return null;
    }

    final aiProfile = data['ai_profile'];

    if (aiProfile is Map<String, dynamic>) {
      return aiProfile;
    }

    return null;
  }

  Future<void> resetOnboarding() async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Utente non autenticato.');
    }

    await _db.collection('users').doc(user.uid).set({
      'onboarding_completed': false,
      'ai_profile': {
        'main_goal': null,
        'interests': <String>[],
        'money_feeling': null,
        'advice_style': null,
        'ai_frequency': null,
        'created_at': null,
        'updated_at': FieldValue.serverTimestamp(),
      },
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  dynamic _jsonSafeValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is DocumentReference) {
      return value.path;
    }

    if (value is GeoPoint) {
      return {
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }

    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(
          key.toString(),
          _jsonSafeValue(item),
        ),
      );
    }

    if (value is List) {
      return value.map(_jsonSafeValue).toList();
    }

    return value;
  }

  Map<String, dynamic> _docToExportMap(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return {
      'id': doc.id,
      ...Map<String, dynamic>.from(
        _jsonSafeValue(doc.data()) as Map,
      ),
    };
  }

  Future<List<Map<String, dynamic>>> _exportUserSubCollection({
    required String userId,
    required String collectionName,
  }) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection(collectionName)
        .get();

    return snapshot.docs.map(_docToExportMap).toList();
  }

  Future<List<Map<String, dynamic>>> _exportUserSupportTickets({
    required String userId,
  }) async {
    final ticketsSnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('support_tickets')
        .orderBy('updated_at', descending: true)
        .get();

    final tickets = <Map<String, dynamic>>[];

    for (final ticketDoc in ticketsSnapshot.docs) {
      final messagesSnapshot = await ticketDoc.reference
          .collection('messages')
          .orderBy('created_at', descending: false)
          .get();

      tickets.add({
        'id': ticketDoc.id,
        ...Map<String, dynamic>.from(
          _jsonSafeValue(ticketDoc.data()) as Map,
        ),
        'messages': messagesSnapshot.docs.map(_docToExportMap).toList(),
      });
    }

    return tickets;
  }

  Future<Map<String, dynamic>> exportCurrentUserData() async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Utente non autenticato.');
    }

    final userDoc = await _db.collection('users').doc(user.uid).get();

    return {
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'PocketPlan',
      'user_id': user.uid,
      'email': user.email,
      'profile': userDoc.exists
          ? _jsonSafeValue(userDoc.data() ?? <String, dynamic>{})
          : <String, dynamic>{},

      /*
        Queste sono le collection utente più probabili.
        Se nel tuo FinanceService usi nomi diversi, correggili qui.
      */
      'incomes': await _exportUserSubCollection(
        userId: user.uid,
        collectionName: 'incomes',
      ),
      'expenses': await _exportUserSubCollection(
        userId: user.uid,
        collectionName: 'expenses',
      ),
      'goals': await _exportUserSubCollection(
        userId: user.uid,
        collectionName: 'goals',
      ),
      'bank_accounts': await _exportUserSubCollection(
        userId: user.uid,
        collectionName: 'bank_accounts',
      ),
      'bank_transfers': await _exportUserSubCollection(
        userId: user.uid,
        collectionName: 'bank_transfers',
      ),
      'watch_summary': await _exportUserSubCollection(
        userId: user.uid,
        collectionName: 'watch_summary',
      ),
      'ai_insights': await _exportUserSubCollection(
        userId: user.uid,
        collectionName: 'ai_insights',
      ),
      'support_tickets': await _exportUserSupportTickets(
        userId: user.uid,
      ),
    };
  }

  Future<void> _deleteQuerySnapshotInChunks(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    const int chunkSize = 450;

    for (var i = 0; i < snapshot.docs.length; i += chunkSize) {
      final batch = _db.batch();
      final chunk = snapshot.docs.skip(i).take(chunkSize);

      for (final doc in chunk) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }

  Future<void> _deleteUserCollection({
    required String userId,
    required String collectionName,
  }) async {
    while (true) {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection(collectionName)
          .limit(450)
          .get();

      if (snapshot.docs.isEmpty) {
        break;
      }

      await _deleteQuerySnapshotInChunks(snapshot);
    }
  }

  Future<void> _deleteUserSupportTickets({
    required String userId,
  }) async {
    while (true) {
      final ticketsSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('support_tickets')
          .limit(100)
          .get();

      if (ticketsSnapshot.docs.isEmpty) {
        break;
      }

      for (final ticketDoc in ticketsSnapshot.docs) {
        while (true) {
          final messagesSnapshot =
              await ticketDoc.reference.collection('messages').limit(450).get();

          if (messagesSnapshot.docs.isEmpty) {
            break;
          }

          await _deleteQuerySnapshotInChunks(messagesSnapshot);
        }

        await ticketDoc.reference.delete();
      }
    }
  }

  Future<void> _deleteTopLevelSupportTickets({
    required String userId,
  }) async {
    while (true) {
      final ticketsSnapshot = await _db
          .collection('support_tickets')
          .where('user_id', isEqualTo: userId)
          .limit(100)
          .get();

      if (ticketsSnapshot.docs.isEmpty) {
        break;
      }

      for (final ticketDoc in ticketsSnapshot.docs) {
        while (true) {
          final messagesSnapshot =
              await ticketDoc.reference.collection('messages').limit(450).get();

          if (messagesSnapshot.docs.isEmpty) {
            break;
          }

          await _deleteQuerySnapshotInChunks(messagesSnapshot);
        }

        await ticketDoc.reference.delete();
      }
    }
  }

  Future<void> deleteCurrentUserAccountAndData() async {
    final user = currentUser;

    if (user == null) {
      throw Exception('Utente non autenticato.');
    }

    final userId = user.uid;

    /*
      Queste sono le collection utente più probabili.
      Se nel tuo progetto hai altre collection sotto users/{uid}, aggiungile qui.
    */
    const userCollections = [
      'incomes',
      'expenses',
      'goals',
      'bank_accounts',
      'bank_transfers',
      'watch_summary',
      'ai_insights',
    ];

    for (final collectionName in userCollections) {
      await _deleteUserCollection(
        userId: userId,
        collectionName: collectionName,
      );
    }

    await _deleteUserSupportTickets(userId: userId);
    await _deleteTopLevelSupportTickets(userId: userId);

    await _db.collection('users').doc(userId).delete();

    /*
      Importante:
      Firebase può bloccare questa operazione se l’utente non ha fatto
      un accesso recente. In quel caso verrà lanciato FirebaseAuthException
      con code = requires-recent-login, che gestiamo nella SettingsPage.
    */
    await user.delete();

    if (!kIsWeb) {
      try {
        await _initializeGoogleSignInIfNeeded();
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Evita blocchi se Google Sign-In non era inizializzato.
      }
    }

    await _auth.signOut();
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