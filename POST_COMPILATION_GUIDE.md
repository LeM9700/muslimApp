# 📝 Guide Post-Compilation - Muslim App

## ✅ Étapes Complétées
- [x] Correction SDK Android 35
- [x] Suppression temporaire police arabe
- [x] Application compilée avec succès
- [x] Correction problème splash screen bloquant
- [x] Firebase rendu optionnel avec gestion d'erreurs
- [x] Données de test (mock) si Firebase indisponible
- [x] Widgets avec états de chargement/erreur/retry

## 📋 Actions Post-Lancement

### 1. 🔤 Ajouter la Police Arabe Noto Naskh

**Étapes :**
1. Téléchargez `NotoNaskhArabic-Regular.ttf` depuis :
   - Google Fonts : https://fonts.google.com/noto/specimen/Noto+Naskh+Arabic
   - GitHub : https://github.com/googlefonts/noto-fonts

2. Placez le fichier dans : `assets/fonts/NotoNaskhArabic-Regular.ttf`

3. Décommentez dans `pubspec.yaml` :
   ```yaml
   fonts:
     - family: NotoNaskhArabic
       fonts:
         - asset: assets/fonts/NotoNaskhArabic-Regular.ttf
   ```

4. Décommentez dans `lib/utils/app_theme.dart` :
   ```dart
   fontFamily: 'NotoNaskhArabic',
   ```

5. Relancez : `flutter pub get` puis `flutter run`

### 2. 🔥 Configuration Firebase (Optionnel)

Pour tester avec des données réelles :

1. **Créer projet Firebase :**
   - Console Firebase : https://console.firebase.google.com/
   - Nouveau projet → Ajouter Android app

2. **Télécharger fichiers config :**
   - `google-services.json` → `android/app/`
   - Package name : `com.example.muslim_app`

3. **Firestore Database :**
   - Mode test (30 jours)
   - Importer `firestore_example_data.json`
   - Appliquer `firestore.rules`

4. **Redémarrer l'app** pour voir les données Firebase

### 3. 🎨 Améliorations Futures

- **Icon App** : Remplacer icône vectorielle par vraie icône
- **Splash Screen** : Personnaliser écran de démarrage
- **API Horaires** : Connecter Aladhan/IslamicFinder
- **Audio Coran** : Héberger fichiers MP3 sur Firebase Storage

## 🐛 Dépannage

**Si l'app ne se lance pas :**
```bash
flutter clean
flutter pub get
flutter run -d emulator-5554
```

**Si erreurs Firebase :**
- Vérifiez que `google-services.json` est dans `android/app/`
- Package name doit correspondre exactement

**Performance lente :**
- Première compilation = 5-10 minutes normal
- Hot reload ensuite = 2-3 secondes

---

**L'application devrait maintenant fonctionner sur votre émulateur Android !** 🎉