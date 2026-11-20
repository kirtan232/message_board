import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MessageBoardApp());
}

Future<void> initializeFirebase() async {
  // Firebase.initializeApp is safe to call again after a failed attempt.
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class MessageBoardApp extends StatelessWidget {
  const MessageBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Message Board',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: SplashScreen(
        initialize: initializeFirebase,
        // Task 2 replaces this placeholder with the AuthGate.
        onReady: (_) => const _FirebaseReadyPlaceholder(),
      ),
    );
  }
}

class _FirebaseReadyPlaceholder extends StatelessWidget {
  const _FirebaseReadyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Firebase initialized ✔')),
    );
  }
}
