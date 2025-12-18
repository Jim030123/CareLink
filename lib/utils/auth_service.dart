// lib/utils/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:carelink_mobile/utils/fcm.dart';

class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email & password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign in with email & password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final uc = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Fire-and-forget: register device FCM token with backend after login


    return uc;
  }


  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Sign out (also sign out from Google if used)
  // Future<void> signOut() async {
  //   try {
  //     // Try to sign out GoogleSignIn (no-op if not signed in with Google)
  //     await GoogleSignIn().signOut();
  //   } catch (_) {}
  //   await _auth.signOut();
  // }

  // // Sign in with Google (works for web & mobile)
  // Future<UserCredential> signInWithGoogle() async {
  //   if (kIsWeb) {
  //     final provider = GoogleAuthProvider();
  //     provider.addScope('email');
  //     return await _auth.signInWithPopup(provider);
  //   } else {
  //     final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
  //     if (googleUser == null) {
  //       throw FirebaseAuthException(
  //         code: 'ERROR_ABORTED_BY_USER',
  //         message: 'Sign in aborted by user',
  //       );
  //     }
  //     final GoogleSignInAuthentication googleAuth =
  //         await googleUser.authentication;
  //     final credential = GoogleAuthProvider.credential(
  //       accessToken: googleAuth.accessToken,
  //       idToken: googleAuth.idToken,
  //     );
  //     return await _auth.signInWithCredential(credential);
  //   }
  // }

  // Reauthenticate user with password (useful before sensitive operations)
  Future<UserCredential> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'NO_CURRENT_USER',
        message: 'No user is currently signed in.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    return await user.reauthenticateWithCredential(credential);
  }

  // Update display name and optionally photoURL
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(displayName);
    if (photoURL != null) {
      await user.updatePhotoURL(photoURL);
    }
    await user.reload();
  }

  // // Update email
  // Future<void> updateEmail(String newEmail) async {
  //   final user = _auth.currentUser;
  //   if (user == null) return;
  //   await user.updateEmail(newEmail);
  //   await user.reload();
  // }

  // // Delete account
  // Future<void> deleteAccount() async {
  //   final user = _auth.currentUser;
  //   if (user == null) return;
  //   await user.delete();
  // }

  // Get ID token (optionally force refresh)
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken(forceRefresh);
  }
}