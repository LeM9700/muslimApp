# Widget d'écran verrouillé : configuration Apple (une seule fois)

Le widget est une **extension** de l'app : il a son propre identifiant
(`com.elboazzati.muslimapp.PrayerWidget`) et lit les horaires dans un
**App Group** partagé avec l'app (`group.com.elboazzati.muslimapp`).
Sans les étapes ci-dessous, le build TestFlight s'arrête avec un message
explicite (signature).

Portail : developer.apple.com → Certificates, Identifiers & Profiles.

## 1. Créer l'App Group

Identifiers → **+** → **App Groups** → Continue
- Description : `Deen`
- Identifier : `group.com.elboazzati.muslimapp`

## 2. Ajouter l'App Group et « Time Sensitive » à l'app

Identifiers → `com.elboazzati.muslimapp` :
- cocher **App Groups** → **Configure** → cocher `group.com.elboazzati.muslimapp` ;
- cocher **Time Sensitive Notifications** (le rappel du dernier tiers de
  la nuit et l'adhan passent alors les modes Concentration, comme
  « Sommeil ») ;
- Save.

⚠️ Cela invalide le profil App Store actuel de l'app (étape 4).

## 3. Créer l'identifiant de l'extension

Identifiers → **+** → **App IDs** → **App** → Continue
- Description : `Deen Prayer Widget`
- Bundle ID (Explicit) : `com.elboazzati.muslimapp.PrayerWidget`
- Capabilities : cocher **App Groups** → Configure → `group.com.elboazzati.muslimapp`

## 4. Régénérer le profil de l'app

Profiles → le profil **App Store** de `com.elboazzati.muslimapp` (marqué
« Invalid ») → **Edit** → **Save** → **Download**.

## 5. Créer le profil de l'extension

Profiles → **+** → **App Store Connect** (Distribution) → Continue
- App ID : `com.elboazzati.muslimapp.PrayerWidget`
- Certificat : le même certificat **Apple Distribution** que l'app
- Nom : `Deen Widget AppStore` → Generate → **Download**

## 6. Mettre à jour les secrets GitHub

Pour chaque fichier téléchargé, encoder en base64 **sur une seule ligne** :

```bash
# Linux (-w 0 : sans retour à la ligne, sinon le secret peut être corrompu)
base64 -w 0 <fichier>.mobileprovision > profil.b64      # puis copier le contenu
base64 -w 0 <fichier>.mobileprovision | xclip -selection clipboard   # X11
base64 -w 0 <fichier>.mobileprovision | wl-copy                      # Wayland

# macOS
base64 -i <fichier>.mobileprovision | pbcopy
```

Vérifier avant de coller (Linux ou macOS) :

```bash
openssl smime -inform der -verify -noverify -in <fichier>.mobileprovision 2>/dev/null \
  | grep -A3 -E "application-groups|time-sensitive"
```

Les deux profils doivent contenir `group.com.elboazzati.muslimapp`, celui de
l'app aussi `usernotifications.time-sensitive`. Supprimer ensuite les
fichiers `.b64` (ce sont vos profils de signature).

GitHub → Settings → Secrets and variables → Actions :
- **mettre à jour** `IOS_PROVISIONING_PROFILE_BASE64` (profil de l'étape 4) ;
- **ajouter** `IOS_WIDGET_PROVISIONING_PROFILE_BASE64` (profil de l'étape 5).

Le certificat (`IOS_DIST_CERT_P12_BASE64`) ne change pas.

## 7. Lancer le build

Actions → **iOS TestFlight** → Run workflow → choisir la branche, remplir
`test_audio_url` tant que les sons d'adhan sont de substitution.

Le CI vérifie que **les deux profils** contiennent l'App Group (sinon le
widget resterait vide sans aucune erreur visible) et que celui de l'app
contient « Time Sensitive » (sinon l'archive échouerait à la signature).

## Vérifier sur l'iPhone (iOS 16 ou plus)

1. Deen → Notifications → **Écran verrouillé** → activer « Chronologie des prières ».
2. Verrouiller, toucher longuement l'écran → Personnaliser → Écran verrouillé.
3. Toucher la zone des widgets → **Deen** → choisir un format :
   rectangulaire (arc + prochaine prière + compte à rebours), rond, ou
   en ligne (au-dessus de l'heure).
