import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'board_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Routes by auth state: signed-out users see login/register,
/// signed-in users reach the board. Built only after Firebase initializes.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _auth = AuthService();
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authState,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Cannot read sign-in state. Restart and retry.'),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return _showRegister
              ? RegisterScreen(
                  auth: _auth,
                  onShowLogin: () => setState(() => _showRegister = false),
                )
              : LoginScreen(
                  auth: _auth,
                  onShowRegister: () => setState(() => _showRegister = true),
                );
        }

        // Task 3 inserts ProfileGate here to require the Firestore user record.
        return BoardScreen(key: ValueKey(user.uid), auth: _auth, user: user);
      },
    );
  }
}
