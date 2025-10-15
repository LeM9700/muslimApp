# Muslim App 🕌

Une application Flutter moderne pour la communauté musulmane avec design glassmorphism et système de quiz interactif.

## � Configuration sécurisée

### Variables d'environnement

Ce projet utilise des variables d'environnement pour protéger les clés API sensibles.

1. **Copiez le fichier d'exemple** :
   ```bash
   cp .env.example .env
   ```

2. **Remplissez vos clés Firebase** dans le fichier `.env` :
   ```env
   FIREBASE_API_KEY=votre_cle_api_firebase
   FIREBASE_AUTH_DOMAIN=votre_projet.firebaseapp.com
   FIREBASE_PROJECT_ID=votre_projet_id
   FIREBASE_STORAGE_BUCKET=votre_projet.firebasestorage.app
   FIREBASE_MESSAGING_SENDER_ID=votre_sender_id
   FIREBASE_APP_ID=votre_app_id
   ```

3. **⚠️ Important** : Le fichier `.env` ne doit JAMAIS être committé dans Git (il est dans .gitignore)

## �🚀 Fonctionnalités

### ✅ Implémentées
- **Dashboard** : Vue d'ensemble avec tous les services
- **Horaires de prière** : Affichage des 5 prières quotidiennes
- **Hadith du jour** : Récupération depuis Firestore (reviewed == true)
- **Boussole Qibla** : Direction vers la Kaaba avec géolocalisation
- **Quiz islamique** : Questions depuis Firestore (reviewed == true)
- **Lecture du Coran** : Navigation par sourates avec audio
- **Bookmarking** : Reprise de lecture sauvegardée localement
- **Notifications** : Hadith (10h) et Quiz (20h) quotidiens
- **Profil** : Statistiques et gestion des données

### 🎨 Interface
- **Thème sombre** : Bleu nuit (#0A1E32) selon les spécifications
- **Typography** : Noto Naskh Arabic pour l'arabe, contraste AA
- **Responsive** : Touch targets 44px+, accessible
- **Animations** : Légères et sobres

## 🛠 Architecture Technique

### Structure des dossiers (respectée à 100%)
```
lib/
├── main.dart                     # Point d'entrée avec Firebase init
├── app.dart                      # MaterialApp + thème + navigatorKey
├── routes/
│   └── app_routes.dart          # Routes nommées
├── screens/                     # Écrans de l'application
├── widgets/                     # Composants réutilisables
├── services/                    # Services Firebase et API
├── models/                      # Modèles de données
├── utils/                       # Utilitaires et helpers
└── data/                        # Données locales (fallback)
```

### Dépendances principales
- **Flutter 3.19+** avec Dart null-safety
- **Firebase** : Core + Firestore pour données dynamiques
- **Audio** : audioplayers pour lecture versets
- **Géolocalisation** : geolocator + flutter_compass
- **Local** : shared_preferences pour bookmarks
- **Notifications** : flutter_local_notifications + timezone

## 🔧 Installation et Setup

### Prérequis
- Flutter 3.19+ installé
- Firebase project configuré
- Android Studio / Xcode pour build

### Étapes d'installation

1. **Cloner et installer les dépendances**
```bash
flutter pub get
```

2. **Configuration Firebase**
- Créer un projet Firebase
- Activer Firestore Database
- Ajouter les règles de sécurité Firestore
- Télécharger `google-services.json` (Android) et `GoogleService-Info.plist` (iOS)

3. **Structure Firestore recommandée**
```javascript
// Collection: hadiths
{
  text: "Texte du hadith...",
  source: "Sahih Bukhari",
  reviewed: true,
  created_at: timestamp
}

// Collection: quiz_questions  
{
  question: "Question du quiz ?",
  options: ["Réponse A", "Réponse B", "Réponse C"],
  answerIndex: 0,
  explanation: "Explication de la réponse...",
  reviewed: true,
  created_at: timestamp
}

// Collection: quran
{
  sura_number: 1,
  name: "Al-Fatiha",
  verses: [
    {
      ayah: 1,
      text: "النص العربي",
      translation_fr: "Traduction française",
      audio_url: "https://example.com/audio.mp3"
    }
  ]
}
```

4. **Permissions Android** (déjà configurées)
- Géolocalisation : `ACCESS_FINE_LOCATION`
- Notifications : `RECEIVE_BOOT_COMPLETED`, `VIBRATE`
- Internet : `INTERNET`, `ACCESS_NETWORK_STATE`

5. **Permissions iOS** (déjà configurées)
- Géolocalisation : `NSLocationWhenInUseUsageDescription`
- Notifications : `UIBackgroundModes`

### Lancement
```bash
flutter run
```

## 📱 Utilisation

### Navigation
- **/** : Dashboard principal
- **/quran** : Liste des sourates
- **/sura** : Détail d'une sourate (avec arguments)
- **/quiz** : Quiz interactif
- **/qibla** : Boussole Qibla
- **/profile** : Profil utilisateur

### Fonctionnalités clés

#### Boussole Qibla
- Demande automatiquement les permissions de géolocalisation
- Calcule la direction vers la Kaaba (21.4225°N, 39.8262°E)
- Boussole en temps réel avec calibrage

#### Lecture du Coran
- Audio par verset via `audioplayers`
- Sauvegarde automatique de la progression
- Reprise de lecture via SharedPreferences

#### Quiz & Hadith
- Contenu dynamique depuis Firestore
- Filtrage automatique `reviewed == true`
- Notifications quotidiennes programmées

## 🔒 Règles de Sécurité Firestore

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Lecture seule pour les contenus validés
    match /hadiths/{document} {
      allow read: if resource.data.reviewed == true;
    }
    match /quiz_questions/{document} {
      allow read: if resource.data.reviewed == true;
    }
    match /quran/{document} {
      allow read: if true;
    }
  }
}
```

## 🚨 Points d'Attention

### TODO Critiques
- [ ] **Assets** : Ajouter app icon et splash screen
- [ ] **API Prières** : Connecter avec vraie API (Aladhan, IslamicFinder)
- [ ] **Audio** : Héberger fichiers audio Coran
- [ ] **Tests** : Ajouter tests unitaires et d'intégration
- [ ] **Localisation** : Support multilingue (FR/AR/EN)

### Limitations MVP
- Horaires de prière : valeurs fixes (TODO: API géolocalisée)
- Audio Coran : URLs placeholder (TODO: vraies sources)
- Rotation quiz/hadith : basée sur jour (TODO: algorithme avancé)

## 📖 Documentation Développeur

### Clés SharedPreferences documentées
- `last_sura_id` (String) : ID Firestore dernière sourate
- `last_sura_name` (String) : Nom dernière sourate  
- `last_ayah` (int) : Numéro dernier verset lu
- `reading_sessions` (int) : Nombre sessions lecture
- `quiz_answered` (int) : Nombre quiz répondus
- `correct_answers` (int) : Nombre bonnes réponses

### Services principaux
- `FirebaseHadithService` : Gestion hadiths Firestore
- `FirebaseQuizService` : Gestion questions Firestore  
- `QiblaService` : Calculs géolocalisation Qibla
- `PrayerService` : Placeholder horaires prière

### Widgets réutilisables
- `PrayerTimesCard` : Affichage horaires
- `HadithCard` : Hadith du jour
- `QuizCard` : Aperçu quiz
- `QiblaCompass` : Boussole complète
- `MiniQiblaCompass` : Version miniature
- `ResumeReadingCard` : Reprise lecture

## 🤝 Contribution

Cette application respecte strictement les spécifications du fichier d'instructions. Toute modification doit :

1. Maintenir l'architecture des dossiers
2. Respecter le thème sombre spécifié
3. Conserver la filtration `reviewed == true`
4. Documenter les nouvelles clés SharedPreferences
5. Suivre les conventions de nommage établies

## 📄 Licence

Open-source pour la communauté musulmane.

---

**Développé selon les spécifications techniques strictes - Aucun écart autorisé**