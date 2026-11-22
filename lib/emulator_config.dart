import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Run against the local Firebase Emulator Suite instead of production:
///
///   flutter run --dart-define=USE_EMULATOR=true
///
/// The Android emulator reaches the host machine at 10.0.2.2. For a physical
/// phone, pass your computer's LAN IP with --dart-define=EMULATOR_HOST=...
const bool kUseEmulator = bool.fromEnvironment('USE_EMULATOR');
const String kEmulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);
const int kAuthEmulatorPort = 9099;
const int kFirestoreEmulatorPort = 8080;

/// Points Auth and Firestore for [app] at the emulators (when enabled).
/// Must run before any other Auth/Firestore call on that app.
Future<void> connectToEmulatorsIfEnabled([FirebaseApp? app]) async {
  if (!kUseEmulator) return;
  final auth = app == null
      ? FirebaseAuth.instance
      : FirebaseAuth.instanceFor(app: app);
  final db = app == null
      ? FirebaseFirestore.instance
      : FirebaseFirestore.instanceFor(app: app);
  await auth.useAuthEmulator(kEmulatorHost, kAuthEmulatorPort);
  db.useFirestoreEmulator(kEmulatorHost, kFirestoreEmulatorPort);
}
