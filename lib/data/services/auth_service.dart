import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Account management. The app signs in anonymously by default; the user can
/// upgrade to a Google account so their journal survives reinstalls and syncs
/// across devices. Linking preserves the entries already written anonymously.
class AuthService {
  final _auth = FirebaseAuth.instance;

  /// Sign in with Google. If the current user is anonymous, LINK the Google
  /// credential to keep existing entries. If that Google account is already in
  /// use elsewhere, sign into it instead.
  /// Returns the signed-in user, or null if the user cancelled.
  Future<User?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final current = _auth.currentUser;
    User? user;
    if (current != null && current.isAnonymous) {
      try {
        final result = await current.linkWithCredential(credential);
        user = result.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          // That Google account already has its own data — switch to it.
          final result = await _auth.signInWithCredential(credential);
          user = result.user;
        } else {
          rethrow;
        }
      }
    } else {
      final result = await _auth.signInWithCredential(credential);
      user = result.user;
    }

    // Linking doesn't copy the Google name/photo onto the Firebase user —
    // pull them straight from the Google account and persist them.
    if (user != null) {
      if ((user.displayName == null || user.displayName!.isEmpty) &&
          googleUser.displayName != null) {
        await user.updateDisplayName(googleUser.displayName);
      }
      if ((user.photoURL == null || user.photoURL!.isEmpty) &&
          googleUser.photoUrl != null) {
        await user.updatePhotoURL(googleUser.photoUrl);
      }
      await user.reload();
      user = _auth.currentUser;
    }
    return user;
  }

  /// Update the display name on the current account (manual edit from Profile).
  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await user.reload();
  }

  /// Sign out, then immediately sign back in anonymously so the app keeps
  /// working (a fresh anonymous session, separate from the Google account).
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
    await _auth.signInAnonymously();
  }
}
