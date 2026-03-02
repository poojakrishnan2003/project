import 'package:firebase_auth/firebase_auth.dart';

Future<UserCredential?> signInWithGoogleNative(FirebaseAuth auth) async {
  throw UnsupportedError('Native Google Sign In is not supported on web.');
}
