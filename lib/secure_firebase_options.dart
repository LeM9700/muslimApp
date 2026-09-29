// Fichier conservé pour compatibilité — redirige vers DefaultFirebaseOptions.
// La logique a été migrée vers lib/firebase_options.dart (gitignored).
// Ne plus utiliser SecureFirebaseOptions dans le nouveau code.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'firebase_options.dart';

export 'firebase_options.dart' show DefaultFirebaseOptions;

/// @deprecated Utiliser DefaultFirebaseOptions depuis firebase_options.dart.
class SecureFirebaseOptions {
  SecureFirebaseOptions._();

  /// Redirige vers DefaultFirebaseOptions.currentPlatform.
  static FirebaseOptions get currentPlatform =>
      DefaultFirebaseOptions.currentPlatform;

  /// No-op : la validation se fait maintenant au moment de Firebase.initializeApp().
  static void initialize() {}
}
