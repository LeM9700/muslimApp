# iOS Permissions Audit

## Etat apres phase 3

## Permissions conservees

- `NSLocationWhenInUseUsageDescription`
  - Usage : calcul de la direction de la Qibla et des horaires de priere locaux.
  - Moment de demande : quand une fonctionnalite qui depend de la localisation est utilisee.
  - Niveau retenu : `when in use`, pas de localisation permanente.

## Permissions retirees de `Info.plist`

- `NSLocationAlwaysAndWhenInUseUsageDescription`
  - Retire car l'app n'a pas besoin de suivre la position en arriere-plan.
- `NSMicrophoneUsageDescription`
  - Retire car aucune fonctionnalite ne demande le micro.
- `UIBackgroundModes`
  - Retire car les notifications locales planifiees ne justifient pas `background-fetch` ou `background-processing`.

## Notifications locales

- L'initialisation iOS ne declenche plus automatiquement le prompt systeme.
- Au demarrage, l'app verifie seulement si les notifications sont deja autorisees.
- Les notifications quotidiennes sont programmees uniquement si l'autorisation existe deja.
- La demande explicite reste disponible via `NotificationService.requestNotificationPermissions()` pour un futur ecran de reglages ou onboarding.

## Points a verifier sur appareil iOS

- Premiere ouverture : aucun prompt notifications ne doit apparaitre automatiquement.
- Premiere ouverture : aucun prompt localisation ne doit apparaitre depuis les horaires de priere automatiques.
- Ouverture Qibla : prompt localisation `When In Use` seulement.
- Refus localisation : l'app doit afficher un etat d'erreur/action comprehensible.
- Notifications deja autorisees : les rappels quotidiens doivent etre programmes.
- Notifications non autorisees : l'app ne doit pas planter et ne doit pas afficher de prompt au lancement.

## Hors phase 3

- Refonte UX de l'ecran d'activation notifications.
- Harmonisation visuelle `UIUserInterfaceStyle`/theme clair, prevue phase 4.
- Validation finale sur Xcode/TestFlight, prevue phases ulterieures.
