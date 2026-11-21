import 'package:firebase_auth/firebase_auth.dart';

/// Owns every Firebase Authentication call in the app.
///
/// Widgets never touch [FirebaseAuth] directly; they call these methods and
/// let [FirebaseAuthException]s bubble up so the screen can show feedback.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Stable stream (created once) so StreamBuilders don't resubscribe.
  late final Stream<User?> authState = _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();
}

/// Translates Firebase Auth error codes into safe, helpful messages.
/// Raw exception text is never shown to the user.
String friendlyAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return 'That email address is not valid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'email-already-in-use':
      return 'An account already exists for that email. Try signing in.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'Check your connection and try again.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled for this project.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
