import 'secure_firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

/// Configuration Firebase sécurisée pour toutes les plateformes
class FirebaseConfig {
  static Future<void> initialize() async {
    // Initialiser les variables d'environnement
    await SecureFirebaseOptions.initialize();
    
    // Initialiser Firebase avec la configuration sécurisée
    await Firebase.initializeApp(
      options: SecureFirebaseOptions.currentPlatform,
    );
  }
}