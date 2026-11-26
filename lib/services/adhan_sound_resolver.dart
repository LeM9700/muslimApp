import '../models/adhan_mode.dart';

/// Ce qu'il faut demander au système pour un mode donné.
///
/// Pur et sans dépendance au plugin : testable unitairement, et seul
/// endroit où le lien « mode ↔ canal Android ↔ son iOS » est défini.
class AdhanSound {
  /// Canal Android. [⚠️ PROD] Le son d'un canal est figé à sa création :
  /// changer de fichier audio impose un nouvel identifiant (`_v2`…).
  final String androidChannelId;
  final String androidChannelName;
  final String androidChannelDescription;

  /// Fichier de `res/raw` (sans extension), `null` = son système.
  final String? androidRawSound;

  /// Fichier de `Library/Sounds` (iOS), `null` = son système.
  final String? iosSound;

  final bool playSound;

  /// [⚠️ PROD] Flux « alarme » sur Android : l'adhan sonne même téléphone
  /// en vibreur, au volume des alarmes (choix produit assumé). Les autres
  /// modes restent sur le flux notification et respectent le silencieux.
  final bool useAlarmStream;

  const AdhanSound({
    required this.androidChannelId,
    required this.androidChannelName,
    required this.androidChannelDescription,
    required this.playSound,
    this.androidRawSound,
    this.iosSound,
    this.useAlarmStream = false,
  });
}

/// Associe chaque [AdhanMode] à son son et à son canal.
class AdhanSoundResolver {
  const AdhanSoundResolver._();

  /// Canal historique (v1.2.0) conservé : les réglages système que
  /// l'utilisateur y a faits (importance, son) ne sont pas perdus.
  static const String notificationChannelId = 'prayer_channel';

  /// Noms des fichiers sonores des notifications, identiques sur les deux
  /// plateformes (extension .ogg dans res/raw, .caf dans Library/Sounds).
  static const String shortSoundName = 'adhan_short';
  static const String longSoundName = 'adhan_long';

  static const silent = AdhanSound(
    androidChannelId: 'prayer_silent_v1',
    androidChannelName: 'Prière · silencieux',
    androidChannelDescription: 'Notification sans son à l’heure de la prière',
    playSound: false,
  );

  static const notification = AdhanSound(
    androidChannelId: notificationChannelId,
    androidChannelName: 'Heures de prière',
    androidChannelDescription: 'Notification à l’heure de chaque prière',
    playSound: true,
  );

  static const adhanShort = AdhanSound(
    androidChannelId: 'prayer_adhan_short_v1',
    androidChannelName: 'Prière · adhan court',
    androidChannelDescription: '« Allahu akbar » à l’heure de la prière',
    androidRawSound: shortSoundName,
    iosSound: '$shortSoundName.caf',
    playSound: true,
    useAlarmStream: true,
  );

  static const adhanFull = AdhanSound(
    androidChannelId: 'prayer_adhan_v1',
    androidChannelName: 'Prière · adhan',
    androidChannelDescription: 'Extrait de 30 s de l’adhan à l’heure de la prière',
    androidRawSound: longSoundName,
    iosSound: '$longSoundName.caf',
    playSound: true,
    useAlarmStream: true,
  );

  /// Sons des 5 prières (un canal par mode).
  static const List<AdhanSound> all = [silent, notification, adhanShort, adhanFull];

  /// Prière de nuit : canaux distincts de ceux des 5 prières, pour que
  /// l'utilisateur puisse les régler séparément dans Android (par ex.
  /// couper le son la nuit sans toucher au Fajr).
  static const nightSilent = AdhanSound(
    androidChannelId: 'night_prayer_silent_v1',
    androidChannelName: 'Prière de nuit · silencieux',
    androidChannelDescription: 'Rappels de la prière de nuit, sans son',
    playSound: false,
  );

  static const nightNotification = AdhanSound(
    androidChannelId: 'night_prayer_v1',
    androidChannelName: 'Prière de nuit',
    androidChannelDescription:
        'Rappel du soir, Tarawih et dernier tiers de la nuit',
    playSound: true,
  );

  static const List<AdhanSound> night = [nightSilent, nightNotification];

  /// Rappels de jeûne (la veille) : canal à part, réglable dans Android.
  static const fasting = AdhanSound(
    androidChannelId: 'fasting_v1',
    androidChannelName: 'Jeûnes',
    androidChannelDescription: 'Rappel la veille des jeûnes surérogatoires',
    playSound: true,
  );

  /// Tous les canaux à créer au démarrage de l'app.
  static const List<AdhanSound> channels = [...all, ...night, fasting];

  /// [AdhanMode.off] n'est jamais programmé : appeler avec ce mode est une
  /// erreur de l'appelant, signalée tôt plutôt que masquée.
  static AdhanSound resolve(AdhanMode mode) => switch (mode) {
        AdhanMode.silent => silent,
        AdhanMode.notification => notification,
        AdhanMode.adhanShort => adhanShort,
        AdhanMode.adhanFull => adhanFull,
        AdhanMode.off => throw ArgumentError.value(
            mode, 'mode', 'une prière désactivée ne se programme pas'),
      };

  /// Son de la prière de nuit : jamais d'adhan (un mode d'adhan reçu par
  /// erreur retombe sur la notification simple).
  static AdhanSound resolveNight(AdhanMode mode) => switch (mode) {
        AdhanMode.silent => nightSilent,
        AdhanMode.off => throw ArgumentError.value(
            mode, 'mode', 'un créneau désactivé ne se programme pas'),
        _ => nightNotification,
      };
}
