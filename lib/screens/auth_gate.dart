import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'login_screen.dart';
import 'profile_gate.dart';
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
  final UserService _users = UserService();
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
                  users: _users,
                  onShowLogin: () => setState(() => _showRegister = false),
                )
              : LoginScreen(
                  auth: _auth,
                  onShowRegister: () => setState(() => _showRegister = true),
                );
        }

        // The board stays behind a complete Firestore user record.
        return ProfileGate(
          key: ValueKey(user.uid),
          user: user,
          auth: _auth,
          users: _users,
        );
      },
    );
  }
}
