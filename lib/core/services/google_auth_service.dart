import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:roamly/models/user_profile_model.dart';

/// Service to handle Google Sign-In authentication
class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sign in with Google (popup on web, native on mobile)
  /// Returns the [UserCredential] on success, null if cancelled.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential credential;

      if (kIsWeb) {
        // Web: use Firebase popup flow
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        credential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile: use google_sign_in package
        final googleSignIn = GoogleSignIn();
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) return null; // user cancelled

        final googleAuth = await googleUser.authentication;
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        credential = await _auth.signInWithCredential(oauthCredential);
      }

      // Create or update user profile in Firestore
      await _ensureUserProfile(credential);

      return credential;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Creates a UserProfile in Firestore if one doesn't already exist.
  /// Updates photoUrl on existing profiles if it changed.
  Future<void> _ensureUserProfile(UserCredential credential) async {
    final user = credential.user;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      final profile = UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? 'Rider',
        phoneNumber: user.phoneNumber ?? '',
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
      );
      await docRef.set(profile.toMap());
      debugPrint('Created new user profile for Google user: ${user.email}');
    } else {
      // Update photo URL if it changed (e.g., user updated their Google profile)
      final existingData = doc.data();
      if (existingData != null && existingData['photoUrl'] != user.photoURL && user.photoURL != null) {
        await docRef.update({'photoUrl': user.photoURL});
        debugPrint('Updated photoUrl for: ${user.email}');
      }
    }
  }
}
