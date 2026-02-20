import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:roamly/models/user_profile_model.dart';
import 'dart:async';

// Conditional import to prevent GoogleSignIn constructor compilation errors on web
import 'google_auth_web.dart' if (dart.library.io) 'google_auth_mobile.dart';

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
        // Mobile: use google_sign_in package implementation
        final cred = await signInWithGoogleNative(_auth);
        if (cred == null) return null;
        credential = cred;
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
  /// Uses the Google photo URL directly (no mirroring).
  Future<void> _ensureUserProfile(UserCredential credential) async {
    final user = credential.user;
    if (user == null) return;

    try {
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
        // Optional: Update photoUrl if it's missing in Firestore but exists in Auth
        final data = doc.data();
        if (data != null && data['photoUrl'] == null && user.photoURL != null) {
          await docRef.update({'photoUrl': user.photoURL});
          debugPrint('Updated missing photoUrl from Google Auth');
        }
      }
    } catch (e) {
      // Non-blocking error logging
      debugPrint('Error creating/updating user profile: $e');
      // We swallow the error so login can proceed
    }
  }
}
