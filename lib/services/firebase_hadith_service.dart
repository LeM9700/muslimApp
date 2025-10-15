import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/hadith.dart';

/// Service pour récupérer les hadiths depuis Firestore
/// Avec gestion des erreurs et fallback vers données de test
class FirebaseHadithService {
  static const String _collection = 'hadiths';

  /// Récupère le hadith du jour depuis Firestore avec fallback
  /// Utilise des données de test si Firebase indisponible
  Future<Hadith?> getDailyHadith() async {
    try {
      // Vérifier si Firebase est initialisé
      if (Firebase.apps.isEmpty) {
        print('⚠️ Firebase non initialisé, utilisation des données de test');
        return _getMockHadith();
      }
      
      // Tentative d'accès à Firestore avec timeout
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection(_collection)
          .where('reviewed', isEqualTo: true)
          .limit(1)
          .get()
          .timeout(Duration(seconds: 5));

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return Hadith.fromFirestore(doc.data(), doc.id);
      }

      return _getMockHadith();
    } catch (e) {
      print('⚠️ Firestore indisponible, utilisation des données de test');
      print('Erreur: $e');
      return _getMockHadith();
    }
  }
  
  /// Méthode pour obtenir le compte de hadiths validés
  /// Retourne un nombre fixe en mode test
  Future<int> getValidatedHadithsCount() async {
    try {
      if (Firebase.apps.isEmpty) {
        return 42; // Nombre de test
      }
      
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection(_collection)
          .where('reviewed', isEqualTo: true)
          .count()
          .get()
          .timeout(Duration(seconds: 5));
      
      return querySnapshot.count ?? 42;
    } catch (e) {
      print('⚠️ Erreur comptage hadiths: $e');
      return 42; // Fallback
    }
  }
  
  /// Données de test si Firebase non disponible
  static Hadith _getMockHadith() {
    return Hadith(
      id: 'mock_hadith_001',
      text: "إنما الأعمال بالنيات وإنما لكل امرئ ما نوى",
      source: "صحيح البخاري",
      reviewed: true,
    );
  }
}