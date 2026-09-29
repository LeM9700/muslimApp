# Checklist Packaging TestFlight - Sakina

## Etat local prepare

- Version Flutter actuelle : `1.0.0+1`.
- Bundle ID iOS : `com.elboazzati.muslimapp`.
- Display name iOS : `Sakina`.
- Nom app Flutter : `Sakina`.
- Projet iOS present :
  - `ios/Runner.xcodeproj`
  - `ios/Runner.xcworkspace`
  - `ios/Runner/Info.plist`
  - `ios/Runner/Assets.xcassets`
  - `ios/Runner/AppDelegate.swift`
- Les fichiers sensibles Firebase sont ignores par Git :
  - `ios/Runner/GoogleService-Info.plist`
  - `lib/firebase_options.dart`
  - `android/app/google-services.json`

## Bloquants avant upload TestFlight

- `ios/Runner/GoogleService-Info.plist` absent localement.
- `lib/firebase_options.dart` contient encore des valeurs `REPLACE_*`.
- `DEVELOPMENT_TEAM` non configure dans Xcode.
- Archive iOS impossible depuis Windows : macOS + Xcode requis.
- L'icone iOS est encore l'icone Flutter par defaut. Elle peut suffire pour un test interne technique, mais doit etre remplacee avant beta externe ou release publique.

## Commandes macOS recommandees

Depuis la racine du projet sur macOS :

```bash
flutter clean
flutter pub get
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build ipa --release
```

Sorties attendues Flutter :

- archive Xcode : `build/ios/archive/Runner.xcarchive`
- IPA : `build/ios/ipa/*.ipa`

Alternative Xcode :

1. Ouvrir `ios/Runner.xcworkspace`.
2. Selectionner le scheme `Runner`.
3. Configurer `Team` et signing automatique.
4. Choisir un device generic iOS.
5. `Product > Archive`.
6. Dans Organizer : `Validate App`, puis `Distribute App > App Store Connect`.

## App Store Connect

1. Creer l'app dans App Store Connect si elle n'existe pas encore.
2. Utiliser le Bundle ID `com.elboazzati.muslimapp`.
3. Uploader l'archive via Xcode, Transporter ou la commande officielle.
4. Attendre le traitement Apple du build.
5. Ajouter le build a un groupe TestFlight interne.
6. Ajouter les testeurs internes.
7. Remplir `What to Test`.

## Verifications manuelles TestFlight

- Lancement app.
- Nom sous l'icone : `Sakina`.
- Permission position demandee uniquement au bon moment :
  - CTA horaires de priere ;
  - ecran Qibla.
- Qibla fonctionne avec position autorisee.
- Horaires de priere :
  - fallback sans position ;
  - horaires locaux avec position.
- Firebase :
  - mode configure ;
  - fallback propre si indisponible.
- Notifications :
  - pas de prompt automatique au lancement ;
  - affichage local apres autorisation explicite.
- Navigation principale.
- Rendu glassmorphisme sur iPhone recent et appareil plus ancien.

## Sources officielles consultees

- Apple - Upload builds : https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds
- Apple - Add internal testers : https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers
- Flutter - Build and release an iOS app : https://docs.flutter.dev/deployment/ios
