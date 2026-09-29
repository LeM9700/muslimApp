# Firebase iOS TestFlight Checklist

## Etat actuel

- Bundle ID iOS attendu : `com.elboazzati.muslimapp`.
- `ios/Runner/GoogleService-Info.plist` est absent du workspace.
- `lib/firebase_options.dart` existe localement mais contient encore des valeurs `REPLACE_*`.
- `android/app/google-services.json` existe localement.
- Firestore est configure en lecture seule cote app via `firestore.rules`.

## A faire sur Firebase Console

1. Ouvrir le projet Firebase actuel.
2. Ajouter une app iOS avec le Bundle ID `com.elboazzati.muslimapp`.
3. Telecharger `GoogleService-Info.plist`.
4. Placer le fichier localement dans `ios/Runner/GoogleService-Info.plist`.
5. Ne pas commiter ce fichier : il est ignore par `.gitignore`.
6. Regenerer `lib/firebase_options.dart` avec FlutterFire CLI :

```bash
flutterfire configure --project=<firebase-project-id>
```

## Comportement app attendu

- Si Firebase est configure : l'app initialise Firebase et utilise Firestore pour le contenu valide.
- Si Firebase n'est pas configure : l'app reste utilisable avec les fallbacks locaux/mock et expose la raison via `FirebaseService.unavailableReason`.
- En release/TestFlight : aucun seeding automatique ne doit etre lance au demarrage.
- En debug local : le seeding reste possible si Firebase est disponible.

## Requetes Firestore utilisees pour le health check

La verification de connectivite lit :

```text
hadiths where reviewed == true limit 1
```

Cette requete est alignee avec `firestore.rules`. L'ancienne collection `test` n'est pas utilisee car elle est refusee par les regles.

## Points a verifier sur macOS/Xcode

- `GoogleService-Info.plist` est bien reference dans `Runner`.
- L'app lance sans erreur Firebase au demarrage.
- `FirebaseService.isAvailable == true` avec les vraies options.
- En mode avion ou sans Firebase, l'app degrade proprement vers les fallbacks.
