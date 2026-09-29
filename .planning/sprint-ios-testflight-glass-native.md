# Sprint - iOS TestFlight avec UI Flutter glass native-like

## Objectifs

- Produire un build iOS TestFlight fonctionnel.
- Conserver Flutter comme base UI principale.
- Rendre l'experience iOS plus native visuellement : transitions, status bar, safe areas, navigation, feedbacks, permissions, polish glassmorphism.
- Ajouter uniquement les bridges Swift/iOS necessaires au build, aux permissions, aux notifications, au splash/app icon, ou a des integrations que Flutter ne gere pas proprement.
- Utiliser le projet Firebase actuel, avec verification stricte de la configuration iOS et du comportement en prod/TestFlight.
- Stabiliser la chaine de verification : analyse Flutter, tests, build iOS, controle manuel sur simulateur/appareil.

## Constat Existant

- Le projet est une app Flutter, pas une app SwiftUI native.
- Le glassmorphism existe deja cote Flutter :
  - `lib/widgets/glass_widgets.dart`
  - `lib/widgets/floating_navbar.dart`
  - `lib/utils/app_theme.dart`
  - `lib/navigation/main_navigation.dart`
- L'identite actuelle semble orientee "Sakina", mais le nom public final sera decide plus tard lors de la preparation Apple Developer/TestFlight.
- Firebase est deja integre cote Dart via `firebase_core` et `cloud_firestore`.
- Firestore est utilise pour charger du contenu dynamique :
  - hadiths valides,
  - questions de quiz validees,
  - potentiellement donnees Quran.
- Les regles Firestore actuelles bloquent les ecritures cote app et autorisent surtout la lecture du contenu valide.
- Le workspace contient beaucoup de modifications preexistantes. Elles ne doivent pas etre annulees sans validation explicite.

## Ce Qui Manque / Bloque TestFlight

- Le dossier iOS est incomplet pour un build App Store/TestFlight :
  - pas de `ios/Runner.xcodeproj`,
  - pas de `ios/Runner.xcworkspace`,
  - pas de `ios/Podfile`,
  - pas de `ios/Runner/AppDelegate.swift`,
  - pas d'assets iOS visibles pour app icon/splash,
  - pas de `ios/Runner/GoogleService-Info.plist`.
- Les tests Flutter ne se lancent pas actuellement car le fichier de test s'appelle `unit_tests.dart` au lieu de respecter le pattern `*_test.dart`.
- `flutter analyze` a ete lance mais est reste bloque longtemps sur l'analyse. Il faudra le refaire apres stabilisation.
- Plusieurs dependances ont des versions plus recentes hors contraintes. Ce n'est pas bloquant immediatement, mais c'est un risque de maintenance.
- `Info.plist` forcait `UIUserInterfaceStyle` a `Dark`; corrige en phase 4 vers `Light` pour l'UI claire iridescente.
- Des permissions iOS semblent trop larges ou mal justifiees :
  - localisation always presente alors que l'app semble surtout avoir besoin de when-in-use,
  - microphone declare alors que non necessaire,
  - background modes a verifier pour eviter un rejet ou une justification faible.

## Interet Produit / UX / Operationnel

L'approche retenue a un vrai interet : elle permet de sortir un TestFlight plus vite sans jeter l'UI Flutter existante. Le gain produit vient surtout de la stabilisation iOS, de la coherence visuelle avec iOS, et de la fiabilite du build.

Une reecriture SwiftUI complete n'est pas retenue pour ce sprint : elle augmenterait fortement le cout, le risque, et le delai. Les bridges Swift natifs seront limites aux besoins iOS concrets.

## Pourquoi Firestore ?

Firestore sert ici a separer le contenu de l'application :

- modifier les hadiths, quiz ou contenus valides sans publier une nouvelle version iOS ;
- filtrer cote serveur les contenus `reviewed == true` ;
- garder l'app en lecture seule pour les utilisateurs ;
- permettre plus tard un workflow admin sans reconstruire l'app mobile.

Pour TestFlight, Firestore n'est pas obligatoire pour tout. Si une fonctionnalite peut etre fiable avec des assets locaux, on peut garder un fallback local. Mais comme le code actuel depend deja de Firebase/Firestore, le sprint doit au minimum rendre cette integration propre sur iOS, ou documenter clairement les modes offline/fallback.

## Phases

### Phase 1 - Fondations iOS et inventaire release

- Reconstituer ou generer proprement la structure iOS Flutter manquante.
- Verifier que les fichiers iOS generes correspondent au projet Flutter actuel.
- Ajouter/configurer les fichiers iOS necessaires sans exposer de secrets dans Git.
- Verifier Bundle ID, Team ID, signing local et compatibilite TestFlight.
- Identifier les fichiers generes a ignorer dans Git.
- Ne pas changer l'UX produit dans cette phase.

### Phase 2 - Configuration Firebase iOS et comportement prod

- Integrer `GoogleService-Info.plist` localement pour iOS.
- Verifier que `lib/firebase_options.dart` correspond au projet Firebase actuel.
- Auditer l'initialisation Firebase et les fallbacks.
- Desactiver ou encadrer le seeding automatique en contexte release/TestFlight si necessaire.
- Verifier les regles Firestore pour lecture seule et contenu valide.
- Clarifier le comportement attendu si Firebase est indisponible.

### Phase 3 - Permissions, securite et conformite iOS

- Nettoyer `Info.plist` :
  - localisation strictement necessaire,
  - notifications,
  - suppression des permissions inutiles si confirme,
  - justification claire pour chaque permission.
- Verifier notifications locales iOS.
- Verifier que la localisation Qibla et horaires de priere demandent la permission au bon moment.
- Reduire les risques de rejet TestFlight/App Review.

### Phase 4 - UX iOS native-like et glassmorphisme Flutter

- Harmoniser safe areas, status bar, navigation bar, bottom nav et gestures avec les attentes iOS.
- Corriger l'incoherence theme clair vs `UIUserInterfaceStyle`.
- Optimiser les zones utilisant `BackdropFilter` pour limiter le cout GPU.
- Adapter les transitions, feedbacks tactiles et etats permissions.
- Garder une UX simple : pas d'ecrans inutiles, permissions demandees au moment utile.

### Phase 5 - Bridges Swift natifs cibles

- Ajouter ou ajuster `AppDelegate.swift` si necessaire pour :
  - plugins Flutter,
  - notifications,
  - configuration iOS specifique,
  - eventuels hooks systeme.
- Eviter tout bridge Swift non indispensable.
- Documenter chaque bridge cree et son utilite.

### Phase 6 - Tests et fiabilite

- Corriger la decouverte des tests Flutter (`*_test.dart`).
- Ajouter ou adapter les tests utiles pour les services critiques :
  - Qibla/calculs,
  - helpers date/time,
  - fallback Firebase,
  - parsing modeles,
  - onboarding/preferences si touche.
- Relancer `flutter analyze`.
- Relancer `flutter test`.
- Verifier build iOS en mode release/TestFlight.

### Phase 7 - Packaging TestFlight

- Verifier version `pubspec.yaml` : build number et version.
- Preparer app icon, splash, display name temporaire si necessaire.
- Generer archive iOS.
- Documenter les etapes restantes dans Apple Developer / App Store Connect.
- Ne pas envoyer ni pousser sans validation explicite.

## Criteres D'Acceptation

- Un build iOS TestFlight peut etre produit localement.
- Les fichiers iOS necessaires existent et sont coherents avec Flutter.
- Firebase iOS fonctionne avec le projet actuel, ou degrade proprement si indisponible.
- Aucune permission iOS inutile n'est demandee.
- L'UI reste Flutter, mais l'experience iOS est plus native et coherente.
- Les tests Flutter sont decouverts et executables.
- `flutter analyze` passe ou les ecarts restants sont documentes.
- Aucun commit ni push n'est effectue sans feu vert explicite.

## Verifications Prevues

- `git status --short --branch`
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build ios --release` ou equivalent adapte a l'environnement macOS/Xcode
- Verification manuelle iOS :
  - lancement,
  - navigation,
  - permissions localisation,
  - notifications,
  - chargement Firebase,
  - mode offline/fallback,
  - rendu glass sur appareils recents et plus anciens.

## Risques

- L'environnement actuel est Windows ; l'archive TestFlight finale necessite macOS + Xcode.
- Le dossier iOS actuel est incomplet et peut necessiter une regeneration prudente.
- Le workspace contient beaucoup de modifications preexistantes, donc attention a ne pas melanger les changements.
- Firestore et Firebase doivent etre configures pour iOS avec les bons fichiers locaux.
- Les effets glass peuvent impacter les performances sur certains appareils.
- Les permissions iOS mal justifiees peuvent bloquer la review plus tard.

## Hors Sprint Volontaire

- Soumission App Store finale.
- Choix final du nom public, screenshots marketing et metadata App Store.
- Reecriture SwiftUI complete.
- Refonte backend/admin complete.
- Migration massive de dependances.
- Nouveau systeme de contenu ou CMS.
- Push vers depot distant.
- Commit Git sans validation explicite.

## Etat D'Avancement

- 2026-09-29 : Audit initial effectue.
- 2026-09-29 : Decision produit prise : conserver Flutter, polish iOS native-like, bridges Swift cibles.
- 2026-09-29 : Plan de sprint cree.
- 2026-09-29 : Phase 1 commencee apres feu vert utilisateur.
- 2026-09-29 : Phase 1 completee.
- 2026-09-29 : Phase 2 commencee apres feu vert utilisateur.
- 2026-09-29 : Phase 2 completee cote code et documentation.
- 2026-09-29 : Phase 3 commencee apres feu vert utilisateur.
- 2026-09-29 : Phase 3 completee cote code et documentation.
- 2026-09-29 : Phase 4 commencee apres feu vert utilisateur.
- 2026-09-29 : Phase 4 completee cote code et documentation.
- 2026-09-29 : Phase 5 commencee apres feu vert utilisateur.
- 2026-09-29 : Phase 5 completee cote Swift et documentation.
- 2026-09-29 : Phase 6 commencee apres feu vert utilisateur.
- 2026-09-29 : Phase 6 completee cote tests, analyse Dart et documentation.
- 2026-09-29 : Phase 7 commencee apres feu vert utilisateur.
- 2026-09-29 : Phase 7 completee cote packaging local et checklist TestFlight.

## Phase 1 - Resultats

### Fait

- Structure iOS Flutter regeneree/reparee avec `flutter create --platforms=ios --org com.elboazzati --project-name muslim_app --no-pub .`.
- Fichiers iOS manquants ajoutes :
  - `ios/Runner.xcodeproj/`
  - `ios/Runner.xcworkspace/`
  - `ios/Runner/AppDelegate.swift`
  - `ios/Runner/SceneDelegate.swift`
  - `ios/Runner/Runner-Bridging-Header.h`
  - `ios/Runner/Base.lproj/LaunchScreen.storyboard`
  - `ios/Runner/Base.lproj/Main.storyboard`
  - `ios/Runner/Assets.xcassets/`
  - `ios/RunnerTests/`
  - `ios/Flutter/Debug.xcconfig`
  - `ios/Flutter/Release.xcconfig`
  - `ios/Flutter/AppFrameworkInfo.plist`
  - `ios/.gitignore`
- Bundle ID iOS corrige pour rester coherent avec Android :
  - app : `com.elboazzati.muslimapp`
  - tests : `com.elboazzati.muslimapp.RunnerTests`
- `flutter pub get` execute pour preparer les artefacts Flutter, notamment `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage`.
- Test Flutter template cree automatiquement par `flutter create` supprime, car hors phase et incorrect pour cette app.

### Verification Phase 1

- `flutter doctor -v` : aucun probleme detecte sur l'environnement Windows.
- Swift Package Manager Flutter est active dans l'environnement Flutter.
- Le projet Xcode reference `FlutterGeneratedPluginSwiftPackage`.
- `ios/.gitignore` ignore les artefacts generes attendus :
  - `Flutter/ephemeral/`
  - `Flutter/Generated.xcconfig`
  - `Flutter/flutter_export_environment.sh`
  - `Runner/GeneratedPluginRegistrant.*`
  - `Pods/`
  - `DerivedData/`
- `flutter build ios --config-only` tente, mais l'option n'existe pas dans Flutter 3.44.7.

### Points Restants Pour Phases Suivantes

- Aucun `DEVELOPMENT_TEAM` n'est configure dans le projet Xcode. A renseigner sur macOS/Xcode avec le compte Apple Developer.
- `ios/Runner/GoogleService-Info.plist` est toujours absent. Il doit etre genere depuis Firebase Console et place localement.
- Aucun `Podfile` n'a ete genere par ce template Flutter recent. Le projet utilise la voie Swift Package Manager de Flutter ; a confirmer sur macOS/Xcode pendant la validation build.
- L'archive TestFlight ne peut pas etre verifiee sur Windows. Elle devra etre generee sur macOS avec Xcode.
- Le workspace avait deja beaucoup de modifications preexistantes ; elles n'ont pas ete annulees.

## Phase 2 - Resultats

### Fait

- Audit de la configuration Firebase locale :
  - `lib/firebase_options.dart` existe localement mais contient encore des valeurs `REPLACE_*`.
  - `ios/Runner/GoogleService-Info.plist` est absent.
  - `android/app/google-services.json` existe localement.
  - Bundle ID iOS attendu confirme : `com.elboazzati.muslimapp`.
- Ajout d'un garde-fou dans `FirebaseService.initialize()` :
  - detection des options Firebase placeholder ;
  - Firebase marque comme indisponible sans tenter une initialisation invalide ;
  - raison exposee via `FirebaseService.unavailableReason`.
- Correction du health check Firestore :
  - ancienne lecture `test` supprimee ;
  - nouvelle lecture `hadiths where reviewed == true limit 1`, compatible avec `firestore.rules`.
- Encadrement du seeding :
  - appel automatique limite au mode debug dans `main.dart` ;
  - `FirebaseDataSeeder.seedAllData()` refuse aussi de tourner en release/TestFlight via `kReleaseMode`.
- Ajout de `.planning/firebase-ios-testflight-checklist.md` pour documenter :
  - creation app iOS Firebase ;
  - placement local du `GoogleService-Info.plist` ;
  - regeneration FlutterFire ;
  - comportement attendu online/offline.

### Verification Phase 2

- `dart format lib/services/firebase_service.dart lib/services/firebase_data_seeder.dart lib/main.dart`
- `dart analyze lib/services/firebase_service.dart lib/services/firebase_data_seeder.dart lib/main.dart`
  - aucune erreur ;
  - aucune alerte bloquante ;
  - infos restantes : `avoid_print` et `prefer_const_constructors`, deja presentes dans le style actuel et non traitees dans cette phase.

### Limites / Actions Externes

- Le vrai `GoogleService-Info.plist` doit etre genere depuis Firebase Console et place localement dans `ios/Runner/GoogleService-Info.plist`.
- `lib/firebase_options.dart` doit etre regenere avec les vraies valeurs du projet Firebase actuel.
- Ces fichiers restent volontairement ignores par Git et ne doivent pas etre commites.
- La verification iOS complete devra etre faite sur macOS/Xcode pendant les phases suivantes.

## Phase 3 - Resultats

### Fait

- Nettoyage de `ios/Runner/Info.plist` :
  - conservation de `NSLocationWhenInUseUsageDescription` uniquement ;
  - suppression de `NSLocationAlwaysAndWhenInUseUsageDescription` ;
  - suppression de `NSMicrophoneUsageDescription` ;
  - suppression de `UIBackgroundModes`.
- Description localisation remplacee par une justification plus precise :
  - Qibla ;
  - horaires de priere locaux ;
  - uniquement quand l'app est ouverte.
- Notifications iOS rendues moins intrusives :
  - `DarwinInitializationSettings` n'affiche plus le prompt automatiquement au demarrage ;
  - ajout de `NotificationService.areNotificationsEnabled()` ;
  - programmation des notifications quotidiennes uniquement si l'autorisation existe deja.
- Localisation rendue moins intrusive :
  - les horaires de priere automatiques ne demandent plus la permission au demarrage ;
  - ils utilisent la position seulement si elle est deja autorisee ;
  - la demande explicite reste concentree sur la Qibla.
- La demande explicite `NotificationService.requestNotificationPermissions()` reste disponible pour un futur ecran de reglages/onboarding.
- Ajout de `.planning/ios-permissions-audit.md`.

### Verification Phase 3

- `dart format lib/main.dart lib/services/notification_service.dart lib/services/prayer_service.dart`
- `dart analyze ios/Runner/Info.plist lib/main.dart lib/services/notification_service.dart lib/services/prayer_service.dart`
  - aucune erreur ;
  - infos restantes : `avoid_print` et style mineur, deja presentes dans le style actuel.
- Parse XML de `ios/Runner/Info.plist` : OK.
- Scan permissions :
  - plus de `NSLocationAlways...` ;
  - plus de `NSMicrophone...` ;
  - plus de `UIBackgroundModes` ;
  - `NSLocationWhenInUseUsageDescription` conserve.

### Limites / Actions Externes

- Le comportement iOS reel des prompts doit etre verifie sur appareil ou simulateur iOS.
- `UIUserInterfaceStyle` a ete harmonise en phase 4.
- Un vrai point d'entree UX pour activer les notifications reste a concevoir plus tard.

## Phase 4 - Resultats

### Fait

- UX localisation des horaires de priere :
  - ajout d'un CTA glass sur l'accueil quand les horaires utilisent un fallback faute de position ;
  - bouton `Activer la position` qui declenche la permission au bon moment ;
  - bouton `Ouvrir les reglages` si la localisation iOS est desactivee ou refusee definitivement ;
  - les horaires automatiques restent non intrusifs au lancement.
- Experience iOS native-like :
  - scroll principal de l'accueil passe en `BouncingScrollPhysics` avec pull-to-refresh conserve ;
  - `UIUserInterfaceStyle` passe de `Dark` a `Light` pour correspondre au theme clair iridescent ;
  - CTA construit en glassmorphisme avec `GlassContainer`, icone ronde et bouton iOS-friendly.

### Verification Phase 4

- `dart format lib/screens/home_screen.dart`
- Parse XML de `ios/Runner/Info.plist` : OK.
- `dart analyze lib/screens/home_screen.dart lib/services/prayer_service.dart lib/main.dart lib/services/notification_service.dart`
  - aucune erreur apres correction ;
  - warnings restants : champs preexistants non utilises dans `home_screen.dart` et infos de lint (`print`, style mineur).

### Limites / Actions Externes

- Le rendu du glass et le prompt localisation doivent etre verifies sur simulateur/appareil iOS.
- Les warnings preexistants de `home_screen.dart` restent a traiter dans une phase tests/fiabilite ou cleanup dediee.

### Prochaine Etape

- Phase 5 autorisee par l'utilisateur et executee.

## Phase 5 - Resultats

### Fait

- Audit des bridges iOS existants :
  - `AppDelegate.swift` existait mais ne contenait aucun hook natif specifique ;
  - `SceneDelegate.swift` reste minimal, sans besoin d'ajout pour ce sprint ;
  - `GeneratedPluginRegistrant.m` enregistre deja les plugins iOS critiques : Firebase, Firestore, geolocator, geocoding, compass, audio, notifications, preferences.
- Bridge notifications iOS ajoute dans `ios/Runner/AppDelegate.swift` :
  - import du module `flutter_local_notifications` ;
  - import de `UserNotifications` ;
  - ajout du callback `FlutterLocalNotificationsPlugin.setPluginRegistrantCallback` ;
  - ajout du delegate `UNUserNotificationCenter.current().delegate` pour iOS 10+.
- Aucun `MethodChannel` custom ajoute :
  - localisation couverte par `geolocator_apple` ;
  - Qibla/boussole couverte par `flutter_compass` ;
  - Firebase couvert par `firebase_core` et `cloud_firestore` ;
  - UI conservee en Flutter.
- Ajout de `.planning/ios-native-bridges-audit.md`.

### Verification Phase 5

- Verification statique des fichiers iOS :
  - `AppDelegate.swift` est reference dans le projet Xcode ;
  - `GeneratedPluginRegistrant.m` contient bien `FlutterLocalNotificationsPlugin` ;
  - `Runner-Bridging-Header.h` expose `GeneratedPluginRegistrant.h`.
- Verification documentaire locale :
  - la configuration ajoutee suit la recommandation du package `flutter_local_notifications` installe localement.

### Limites / Actions Externes

- La compilation Swift ne peut pas etre verifiee sur Windows.
- Sur macOS/Xcode, verifier :
  - resolution Swift Package Manager de `flutter_local_notifications` ;
  - lancement iOS ;
  - notification locale en foreground ;
  - comportement au tap sur notification.

### Prochaine Etape

- Phase 6 autorisee par l'utilisateur et executee.

## Phase 6 - Resultats

### Fait

- Decouverte des tests Flutter corrigee :
  - ancien fichier non detecte `test/unit_tests.dart` supprime ;
  - nouveau fichier detecte `test/unit_test.dart` ajoute.
- Tests unitaires ajoutes ou remplaces pour couvrir :
  - calcul Qibla via le vrai `QiblaService` ;
  - formatage date/heure et detection texte arabe via `Helpers` ;
  - parsing et comportements des modeles `Hadith`, `QuizQuestion`, `PrayerData` ;
  - helper pur `PrayerService.formatDuration` ;
  - persistance locale onboarding via `SharedPreferences` mocke ;
  - fallbacks Firebase sans reseau quand Firebase est indisponible.
- `QiblaService` expose maintenant `calculateBearingFromCoordinates()` :
  - methode pure ;
  - testable sans demander la permission localisation ;
  - reutilise la formule privee existante.
- Corrections d'erreurs bloquantes trouvees par l'analyse globale :
  - structure de parentheses reparee dans `lib/screens/quiz_screen.dart` ;
  - `lib/secure_firebase_options.dart` importe maintenant `firebase_options.dart` et type `currentPlatform` en `FirebaseOptions`.

### Verification Phase 6

- `dart format lib/services/qibla_service.dart test/unit_test.dart`
- `dart format lib/screens/quiz_screen.dart lib/secure_firebase_options.dart`
- `flutter test`
  - 13 tests passes.
- `dart analyze lib/screens/quiz_screen.dart lib/secure_firebase_options.dart lib/services/qibla_service.dart test/unit_test.dart`
  - aucune erreur ;
  - warnings/lints restants non bloquants dans `quiz_screen.dart` et `qibla_service.dart`.
- `flutter analyze`
  - aucune erreur bloquante apres corrections ;
  - sortie encore en echec par defaut a cause de 269 warnings/infos existants.
- `flutter analyze --no-fatal-infos --no-fatal-warnings`
  - passe avec code 0.
- `flutter build ios --release`
  - impossible dans l'environnement Windows : la commande iOS n'est pas disponible ici.
- `flutter build ios -h`
  - confirme que les sous-commandes disponibles dans cet environnement sont Android/Web/assets, pas iOS.

### Limites / Actions Externes

- Les warnings/lints restants sont majoritairement hors scope de cette phase :
  - `avoid_print` ;
  - `withOpacity` deprecie ;
  - `prefer_const_constructors` ;
  - champs inutilises existants ;
  - petits lints de style.
- La validation build iOS release/TestFlight doit etre faite sur macOS avec Xcode.
- Les tests ajoutes restent des tests unitaires/fallback ; les flows iOS reels devront etre verifies sur simulateur ou appareil.

### Prochaine Etape

- Attendre le feu vert utilisateur pour commencer la Phase 7 - Packaging TestFlight.

## Phase 7 - Resultats

### Fait

- Version Flutter verifiee :
  - `pubspec.yaml` : `1.0.0+1`.
  - iOS utilise `$(FLUTTER_BUILD_NAME)` et `$(FLUTTER_BUILD_NUMBER)` dans `Info.plist`.
- Identite iOS alignee :
  - `CFBundleDisplayName` passe a `Sakina`.
  - `MaterialApp.title` et les fichiers l10n utilisent deja `Sakina`.
- Bundle ID confirme :
  - app : `com.elboazzati.muslimapp`.
  - tests : `com.elboazzati.muslimapp.RunnerTests`.
- Signing audite :
  - aucun `DEVELOPMENT_TEAM` configure dans le projet Xcode.
  - action restante : renseigner la Team Apple Developer sur macOS/Xcode.
- Firebase packaging audite :
  - `ios/Runner/GoogleService-Info.plist` absent ;
  - `lib/firebase_options.dart` existe localement mais contient encore `REPLACE_*` ;
  - les fichiers Firebase sensibles restent bien ignores par Git.
- Assets iOS audites :
  - AppIcon existe techniquement ;
  - icone actuelle = icone Flutter par defaut, a remplacer avant beta externe/release publique ;
  - launch image present via template Flutter.
- Ajout de `.planning/testflight-packaging-checklist.md` :
  - commandes macOS ;
  - etapes Xcode ;
  - etapes App Store Connect ;
  - verifications manuelles TestFlight ;
  - sources officielles Apple/Flutter.

### Verification Phase 7

- Parse XML de `ios/Runner/Info.plist` : OK.
- `flutter pub get` : OK.
- `flutter test` : 13 tests passes.
- `flutter analyze --no-fatal-infos --no-fatal-warnings` : OK.
- `flutter build ipa --release` :
  - impossible dans cet environnement Windows ;
  - la cible iOS/IPA n'est pas disponible ici.
- Documentation officielle consultee :
  - Apple App Store Connect - upload builds ;
  - Apple App Store Connect - internal testers ;
  - Flutter - build and release an iOS app.

### Limites / Actions Externes

- Pour produire le vrai build TestFlight :
  - utiliser macOS + Xcode ;
  - ajouter `ios/Runner/GoogleService-Info.plist` ;
  - regenerer `lib/firebase_options.dart` avec FlutterFire ;
  - configurer `DEVELOPMENT_TEAM` / signing ;
  - remplacer l'icone Flutter par une icone Sakina ;
  - executer `flutter build ipa --release` ou archiver depuis Xcode ;
  - uploader vers App Store Connect ;
  - ajouter le build a un groupe TestFlight interne.

### Etat Sprint

- Les phases 1 a 7 sont executees cote workspace local.
- Le dernier blocage pour un build TestFlight reel n'est pas le code local mais l'environnement macOS/Xcode et les fichiers/secrets de deploiement.
