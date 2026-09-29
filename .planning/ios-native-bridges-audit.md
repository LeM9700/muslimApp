# Audit Phase 5 - Bridges Swift natifs cibles

## Objectif

Stabiliser uniquement les hooks iOS natifs utiles au build TestFlight sans transformer l'app Flutter en app native SwiftUI.

## Bridges retenus

### Notifications locales iOS

- Fichier touche : `ios/Runner/AppDelegate.swift`
- Ajout de `import flutter_local_notifications`
- Ajout de `import UserNotifications`
- Ajout du callback `FlutterLocalNotificationsPlugin.setPluginRegistrantCallback`
- Ajout du delegate `UNUserNotificationCenter.current().delegate`

### Pourquoi

- Le package `flutter_local_notifications` recommande ce hook iOS dans `AppDelegate.swift`.
- Le callback permet au plugin de retrouver les plugins Flutter quand iOS traite certains chemins de notification hors flux principal.
- Le delegate permet a l'app de gerer correctement les notifications locales quand l'app est au premier plan.

## Bridges non ajoutes

- Aucun `MethodChannel` custom pour la localisation : `geolocator_apple` couvre deja le besoin.
- Aucun bridge custom pour la boussole/Qibla : `flutter_compass` couvre deja le besoin.
- Aucun bridge SwiftUI pour l'UI : le sprint conserve Flutter comme couche UI principale.
- Aucun bridge Firebase manuel : `firebase_core` et `cloud_firestore` sont deja enregistres par le registrant Flutter.

## Impacts UX

- Les notifications locales iOS sont mieux alignees avec le comportement natif.
- Aucun prompt de notification n'est declenche par ce bridge ; la logique Dart de la phase 3 reste responsable du moment de demande.
- Aucun changement visible immediat hors comportement systeme iOS.

## Impacts securite / permissions

- Aucune nouvelle permission ajoutee a `Info.plist`.
- Le bridge n'elargit pas les droits iOS.
- La demande de permission notification reste explicite cote Dart via `NotificationService.requestNotificationPermissions()`.

## Verification prevue sur macOS

- Ouvrir `ios/Runner.xcworkspace` dans Xcode.
- Verifier que `flutter_local_notifications` est resolu par Swift Package Manager.
- Lancer l'app sur simulateur ou appareil.
- Autoriser les notifications depuis un futur point d'entree UX ou via test manuel.
- Verifier qu'une notification locale peut etre affichee et que le tap revient bien dans l'app.

## Limites

- La compilation Swift et le build iOS ne peuvent pas etre verifies completement depuis Windows.
- Le vrai test foreground notification doit etre fait sur iOS.
