# Sons de l'adhan

Les fichiers actuels sont des **sons de substitution** (tonalités synthétiques),
signalés par `assets/audio/.placeholder`. `check_release_audio.sh` échoue tant
que ce marqueur existe : à brancher en CI avant tout build de release.

## Tester avec un audio non publiable (ex. sans licence)

Ne **jamais** commiter un audio sans licence (il resterait dans l'historique git).

- **Android, en local** :
  ```bash
  scripts/adhan/prepare_adhan.sh --source adhan.mp3 --short 0:00-0:08 --long-start 0:00 --test
  flutter run --release
  git checkout -- android/app/src/main/res/raw assets/audio && rm -f assets/audio/.test_audio
  ```
  `--test` écrit `assets/audio/.test_audio` : s'il est commité par erreur, les
  builds de release échouent.
- **iPhone, via TestFlight** : GitHub → Actions → *iOS TestFlight* → *Run workflow*,
  remplir `test_audio_url` (URL https directe du fichier) et les repères
  `test_audio_short` / `test_audio_long_start`. Le CI télécharge et convertit
  l'audio dans le runner uniquement, et l'app affiche un bandeau « Build de test »
  dans les réglages des notifications.
  ⚠️ **Ne jamais soumettre ce build à l'App Store** (l'artefact est suffixé `-TEST-AUDIO`).

Sans `test_audio_url`, le workflow (tags `v*` compris) lance
`check_release_audio.sh` et **échoue** tant que les sons sont des sons de substitution
ou de test.

## Remplacer par un vrai enregistrement

1. Trouver **un** enregistrement de l'adhan (et si possible l'adhan du Fajr de
   la même voix) avec une licence compatible avec une app publiée :
   domaine public, CC0, ou CC BY (créditer l'auteur dans l'app).
   ⚠️ Les enregistrements des muezzins de La Mecque / Médine diffusés par les
   chaînes TV sont généralement protégés : pas de copier-coller depuis YouTube.
2. Repérer dans l'audio :
   - le passage « Allahu akbar, Allahu akbar » (adhan court, ~6–10 s) ;
   - le début de l'extrait de 30 s (en général le tout début de l'appel).
3. Lancer :
   ```bash
   scripts/adhan/prepare_adhan.sh \
     --source adhan.mp3 --short 0:00.4-0:08.9 --long-start 0:00.4 \
     --fajr adhan_fajr.mp3
   ```
4. Si des sons avaient déjà été publiés en production :
   - incrémenter `IosSoundInstaller.soundsVersion` ;
   - renommer les canaux `_v1` → `_v2` dans `AdhanSoundResolver`
     (Android ne change jamais le son d'un canal existant).

## Fichiers produits

| Fichier | Usage | Contrainte |
|---|---|---|
| `android/app/src/main/res/raw/adhan_{short,long}.ogg` | son de notification Android | protégé de R8 par `keep.xml` |
| `assets/audio/notification/adhan_{short,long}.caf` | son de notification iOS (copié dans `Library/Sounds`) | < 30 s, IMA4 |
| `assets/audio/adhan_{short,long}.mp3` | aperçu dans les réglages | — |
| `assets/audio/adhan_full.mp3`, `adhan_fajr_full.mp3` | lecteur intégral (appui sur la notification) | Fajr facultatif |
