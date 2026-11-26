import 'prayer_schedule.dart';

/// Comportement d'une prière à son heure.
enum AdhanMode {
  off('Désactivé', 'Aucune notification'),
  silent('Silencieux', 'Notification sans son ni vibration'),
  notification('Notification', 'Son de notification habituel'),
  adhanShort('Adhan court', '« Allahu akbar, Allahu akbar »'),
  adhanFull('Adhan', 'Extrait de 30 s · version intégrale dans l’app');

  const AdhanMode(this.label, this.description);

  final String label;
  final String description;

  /// Joue un enregistrement de l'adhan (et non un son système).
  bool get playsAdhan => this == adhanShort || this == adhanFull;

  static AdhanMode? fromName(String name) {
    for (final m in AdhanMode.values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// Profils prêts à l'emploi : un appui règle les 5 prières d'un coup.
///
/// L'idée : la plupart des gens ont le même besoin (être réveillé au Fajr,
/// rester discret au travail, entendre l'appel le soir). Le profil donne un
/// point de départ, chaque prière reste ensuite réglable une par une.
enum AdhanPreset {
  balanced(
    'Équilibré',
    'Adhan au Fajr et au Maghrib, discret en journée',
    {
      Prayer.fajr: AdhanMode.adhanFull,
      Prayer.dhuhr: AdhanMode.notification,
      Prayer.asr: AdhanMode.notification,
      Prayer.maghrib: AdhanMode.adhanFull,
      Prayer.isha: AdhanMode.adhanShort,
    },
  ),
  adhanEverywhere(
    'Adhan partout',
    'L’adhan pour chaque prière',
    {
      Prayer.fajr: AdhanMode.adhanFull,
      Prayer.dhuhr: AdhanMode.adhanFull,
      Prayer.asr: AdhanMode.adhanFull,
      Prayer.maghrib: AdhanMode.adhanFull,
      Prayer.isha: AdhanMode.adhanFull,
    },
  ),
  discreet(
    'Discret',
    'Notifications silencieuses uniquement',
    {
      Prayer.fajr: AdhanMode.silent,
      Prayer.dhuhr: AdhanMode.silent,
      Prayer.asr: AdhanMode.silent,
      Prayer.maghrib: AdhanMode.silent,
      Prayer.isha: AdhanMode.silent,
    },
  );

  const AdhanPreset(this.label, this.description, this.modes);

  final String label;
  final String description;
  final Map<Prayer, AdhanMode> modes;

  /// Profil correspondant exactement à [modes], `null` = personnalisé.
  static AdhanPreset? matching(Map<Prayer, AdhanMode> modes) {
    for (final preset in AdhanPreset.values) {
      if (Prayer.values.every((p) => preset.modes[p] == modes[p])) {
        return preset;
      }
    }
    return null;
  }
}
