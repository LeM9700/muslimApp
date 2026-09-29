import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

/// Configuration Firebase — délègue à DefaultFirebaseOptions (firebase_options.dart, gitignored).
/// Préférer FirebaseService.initialize() qui inclut la gestion d'erreur et les fallbacks.
class FirebaseConfig {
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
