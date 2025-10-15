import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Configuration Firebase sécurisée utilisant les variables d'environnement
class SecureFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'SecureFirebaseOptions have not been configured for linux',
        );
      default:
        throw UnsupportedError(
          'SecureFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Configuration Web avec variables d'environnement
  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _getEnvVar('FIREBASE_API_KEY'),
    appId: _getEnvVar('FIREBASE_APP_ID'),
    messagingSenderId: _getEnvVar('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _getEnvVar('FIREBASE_PROJECT_ID'),
    authDomain: _getEnvVar('FIREBASE_AUTH_DOMAIN'),
    storageBucket: _getEnvVar('FIREBASE_STORAGE_BUCKET'),
  );

  /// Configuration Android avec variables d'environnement
  static FirebaseOptions get android => FirebaseOptions(
    apiKey: _getEnvVar('FIREBASE_API_KEY'),
    appId: _getEnvVar('FIREBASE_APP_ID'),
    messagingSenderId: _getEnvVar('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _getEnvVar('FIREBASE_PROJECT_ID'),
    storageBucket: _getEnvVar('FIREBASE_STORAGE_BUCKET'),
  );

  /// Configuration iOS avec variables d'environnement
  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: _getEnvVar('FIREBASE_API_KEY'),
    appId: _getEnvVar('FIREBASE_APP_ID'),
    messagingSenderId: _getEnvVar('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _getEnvVar('FIREBASE_PROJECT_ID'),
    storageBucket: _getEnvVar('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: 'com.example.muslimApp',
  );

  /// Configuration macOS avec variables d'environnement
  static FirebaseOptions get macos => FirebaseOptions(
    apiKey: _getEnvVar('FIREBASE_API_KEY'),
    appId: _getEnvVar('FIREBASE_APP_ID'),
    messagingSenderId: _getEnvVar('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _getEnvVar('FIREBASE_PROJECT_ID'),
    storageBucket: _getEnvVar('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: 'com.example.muslimApp',
  );

  /// Configuration Windows avec variables d'environnement
  static FirebaseOptions get windows => FirebaseOptions(
    apiKey: _getEnvVar('FIREBASE_API_KEY'),
    appId: _getEnvVar('FIREBASE_APP_ID'),
    messagingSenderId: _getEnvVar('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _getEnvVar('FIREBASE_PROJECT_ID'),
    authDomain: _getEnvVar('FIREBASE_AUTH_DOMAIN'),
    storageBucket: _getEnvVar('FIREBASE_STORAGE_BUCKET'),
  );

  /// Récupère une variable d'environnement avec validation
  static String _getEnvVar(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw Exception(
        'Variable d\'environnement manquante: $key\n'
        'Assurez-vous que le fichier .env existe et contient toutes les clés nécessaires.',
      );
    }
    return value;
  }

  /// Initialise les variables d'environnement et valide la configuration
  static Future<void> initialize() async {
    await dotenv.load();
    _validateConfiguration();
  }

  /// Valide que toutes les variables d'environnement nécessaires sont présentes
  static void _validateConfiguration() {
    final requiredVars = [
      'FIREBASE_API_KEY',
      'FIREBASE_AUTH_DOMAIN', 
      'FIREBASE_PROJECT_ID',
      'FIREBASE_STORAGE_BUCKET',
      'FIREBASE_MESSAGING_SENDER_ID',
      'FIREBASE_APP_ID',
    ];

    final missingVars = <String>[];
    for (final varName in requiredVars) {
      if (dotenv.env[varName]?.isEmpty ?? true) {
        missingVars.add(varName);
      }
    }

    if (missingVars.isNotEmpty) {
      throw Exception(
        'Variables d\'environnement manquantes: ${missingVars.join(', ')}\n'
        'Copiez .env.example vers .env et remplissez vos clés Firebase.',
      );
    }
  }
}