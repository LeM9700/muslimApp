import '../models/adhan_mode.dart';
import '../models/notification_settings.dart';
import '../models/prayer_schedule.dart';

enum PlannedKind { prayer, reminder }

/// Une notification à programmer, sans dépendance au plugin.
class PlannedNotification {
  final int id;
  final DateTime when;
  final String title;
  final String body;
  final PlannedKind kind;
  final Prayer prayer;

  /// Son à utiliser. Jamais [AdhanMode.off] (filtré par le planificateur).
  final AdhanMode mode;

  const PlannedNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required this.kind,
    required this.prayer,
    this.mode = AdhanMode.notification,
  });

  /// Lu au tap sur la notification (voir `NotificationPayload`).
  String get payload => NotificationPayload.prayer(prayer, mode).encode();

  PlannedNotification withId(int newId) => PlannedNotification(
        id: newId,
        when: when,
        title: title,
        body: body,
        kind: kind,
        prayer: prayer,
        mode: mode,
      );
}

/// Contenu transporté par une notification de prière, relu quand
/// l'utilisateur appuie dessus (`prayer:<prière>:<mode>`).
///
/// [🔒 SÉCURITÉ] Le payload revient du système : on le parse de façon
/// défensive, toute valeur inattendue donne `null` (jamais d'exception).
class NotificationPayload {
  final Prayer prayer;
  final AdhanMode mode;

  const NotificationPayload.prayer(this.prayer, this.mode);

  static const String _prefix = 'prayer';

  String encode() => '$_prefix:${prayer.name}:${mode.name}';

  static NotificationPayload? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2 || parts.length > 3 || parts[0] != _prefix) {
      return null;
    }
    final prayer = Prayer.fromName(parts[1]);
    if (prayer == null) return null;
    // Format v1.2.0 (`prayer:fajr`) : notifications programmées avant la
    // mise à jour, encore en attente dans le système.
    final mode = parts.length == 3
        ? AdhanMode.fromName(parts[2])
        : AdhanMode.notification;
    if (mode == null || mode == AdhanMode.off) return null;
    return NotificationPayload.prayer(prayer, mode);
  }
}

/// Résultat de la planification : les notifications et la date jusqu'à
/// laquelle les rappels sont garantis (affichée à l'utilisateur).
class PrayerPlan {
  final List<PlannedNotification> notifications;
  final DateTime? coveredUntil;

  const PrayerPlan(this.notifications, this.coveredUntil);

  static const empty = PrayerPlan([], null);
}

/// Construit la liste des notifications de prière à programmer.
///
/// [⚠️ PROD] iOS ne conserve que les 64 notifications locales les plus
/// proches et ignore silencieusement les suivantes. On reste donc sous un
/// budget explicite et on reprogramme à chaque ouverture de l'app : avec
/// 5 prières par jour, cela couvre ~11 jours (~5 jours avec rappel avant).
class PrayerNotificationPlanner {
  const PrayerNotificationPlanner._();

  /// Identifiants réservés aux prières : 100 à 100 + budget.
  static const int firstId = 100;

  /// Marge sous la limite iOS (64) : 2 notifications quotidiennes
  /// (hadith, quiz) et une réserve pour une notification de test.
  static const int defaultBudget = 60;

  /// Ne pas programmer ce qui tombe dans moins d'une minute : iOS pourrait
  /// la délivrer en retard ou pas du tout.
  static const Duration minimumLead = Duration(minutes: 1);

  static PrayerPlan plan({
    required List<PrayerDay> days,
    required NotificationSettings settings,
    required DateTime now,
    required String cityName,
    int budget = defaultBudget,
    String Function(DateTime instant)? formatTime,
  }) {
    if (!settings.prayersEnabled || settings.prayers.isEmpty || budget <= 0) {
      return PrayerPlan.empty;
    }
    final fmt = formatTime ?? _formatLocal;
    final threshold = now.toUtc().add(minimumLead);
    final candidates = <PlannedNotification>[];

    for (final day in days) {
      for (final prayer in Prayer.values) {
        if (!settings.prayers.contains(prayer)) continue;
        final at = day.times[prayer];
        if (at == null) continue;
        final time = fmt(at);
        final mode = settings.modeOf(prayer);

        if (settings.reminderMinutes > 0) {
          final before = at.subtract(Duration(minutes: settings.reminderMinutes));
          candidates.add(PlannedNotification(
            id: 0,
            when: before,
            title: '${prayer.label} dans ${settings.reminderMinutes} min',
            body: 'La prière du ${prayer.label} est à $time'
                '${cityName.isEmpty ? '' : ' ($cityName)'}.',
            kind: PlannedKind.reminder,
            prayer: prayer,
            // Le rappel avant n'est qu'une annonce : jamais d'adhan, mais
            // il reste silencieux si la prière l'est.
            mode: mode == AdhanMode.silent
                ? AdhanMode.silent
                : AdhanMode.notification,
          ));
        }
        candidates.add(PlannedNotification(
          id: 0,
          when: at,
          title: '${prayer.label} · $time',
          body: 'C’est l’heure de la prière du ${prayer.label}'
              '${cityName.isEmpty ? '' : ' à $cityName'}.',
          kind: PlannedKind.prayer,
          prayer: prayer,
          mode: mode,
        ));
      }
    }

    final upcoming = candidates.where((n) => n.when.isAfter(threshold)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    final kept = upcoming.take(budget).toList();

    // Une prière couverte sans son rappel (budget épuisé entre les deux)
    // compte quand même : « couvert jusqu'à » = dernière notification.
    final notifications = [
      for (var i = 0; i < kept.length; i++) kept[i].withId(firstId + i),
    ];
    return PrayerPlan(
      notifications,
      notifications.isEmpty ? null : notifications.last.when,
    );
  }

  /// Nombre de jours restant couverts par [days] à partir de [now] :
  /// sert à décider s'il faut retélécharger le calendrier.
  static int daysAhead(List<PrayerDay> days, DateTime now) {
    final nowUtc = now.toUtc();
    return days
        .where((d) => d.times[Prayer.isha]?.isAfter(nowUtc) ?? false)
        .length;
  }

  static String _formatLocal(DateTime instant) {
    final local = instant.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
