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

  const PlannedNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required this.kind,
    required this.prayer,
  });

  String get payload => 'prayer:${prayer.name}';
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
        ));
      }
    }

    final upcoming = candidates.where((n) => n.when.isAfter(threshold)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    final kept = upcoming.take(budget).toList();

    // Une prière couverte sans son rappel (budget épuisé entre les deux)
    // compte quand même : « couvert jusqu'à » = dernière notification.
    final notifications = [
      for (var i = 0; i < kept.length; i++)
        PlannedNotification(
          id: firstId + i,
          when: kept[i].when,
          title: kept[i].title,
          body: kept[i].body,
          kind: kept[i].kind,
          prayer: kept[i].prayer,
        ),
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
