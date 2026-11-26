import '../models/adhan_mode.dart';
import '../models/calendar_settings.dart';
import '../models/fasting.dart';
import '../models/hijri_date.dart';
import '../models/night_prayer_settings.dart';
import '../models/notification_settings.dart';
import '../models/prayer_schedule.dart';
import 'fast_calendar.dart';
import 'night_prayer_calculator.dart';

/// Nature d'une notification planifiée.
///
/// [night] : prière de nuit, liée à un [NightSlot] et non à une [Prayer].
/// [fast] : rappel de jeûne la veille, lié à un [FastKind].
enum PlannedKind { prayer, reminder, night, fast }

/// Une notification à programmer, sans dépendance au plugin.
class PlannedNotification {
  final int id;
  final DateTime when;
  final String title;
  final String body;
  final PlannedKind kind;

  /// Prière concernée ; `null` pour [PlannedKind.night].
  final Prayer? prayer;

  /// Créneau de la prière de nuit ; `null` sauf pour [PlannedKind.night].
  final NightSlot? nightSlot;

  /// Jeûne rappelé ; `null` sauf pour [PlannedKind.fast].
  final FastKind? fastKind;

  /// Son à utiliser. Jamais [AdhanMode.off] (filtré par le planificateur).
  final AdhanMode mode;

  const PlannedNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required this.kind,
    required Prayer this.prayer,
    this.mode = AdhanMode.notification,
  })  : nightSlot = null,
        fastKind = null;

  /// Notification de prière de nuit (jamais d'adhan).
  const PlannedNotification.night({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required NightSlot slot,
    this.mode = AdhanMode.notification,
  })  : kind = PlannedKind.night,
        prayer = null,
        nightSlot = slot,
        fastKind = null;

  /// Rappel de jeûne (son de notification simple).
  const PlannedNotification.fast({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required FastKind kind,
  })  : kind = PlannedKind.fast,
        prayer = null,
        nightSlot = null,
        fastKind = kind,
        mode = AdhanMode.notification;

  const PlannedNotification._copy({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required this.kind,
    required this.prayer,
    required this.nightSlot,
    required this.fastKind,
    required this.mode,
  });

  /// Lu au tap sur la notification (voir `NotificationPayload` et
  /// `NightPayload`).
  String get payload => switch (kind) {
        PlannedKind.night => NightPayload(nightSlot!, mode).encode(),
        PlannedKind.fast => FastPayload(fastKind!).encode(),
        _ => NotificationPayload.prayer(prayer!, mode).encode(),
      };

  PlannedNotification withId(int newId) => PlannedNotification._copy(
        id: newId,
        when: when,
        title: title,
        body: body,
        kind: kind,
        prayer: prayer,
        nightSlot: nightSlot,
        fastKind: fastKind,
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

/// Payload d'une notification de prière de nuit (`night:<créneau>:<mode>`).
///
/// Format distinct de `prayer:…` : le routeur ne le reconnaît pas comme
/// une prière, le tap ouvre donc simplement l'app (pas de lecteur d'adhan).
///
/// [🔒 SÉCURITÉ] Même parsing défensif que [NotificationPayload] : toute
/// valeur inattendue donne `null`, jamais d'exception.
class NightPayload {
  final NightSlot slot;
  final AdhanMode mode;

  const NightPayload(this.slot, this.mode);

  static const String _prefix = 'night';

  String encode() => '$_prefix:${slot.name}:${mode.name}';

  static NightPayload? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 3 || parts[0] != _prefix) return null;
    final slot = NightSlot.fromName(parts[1]);
    final mode = AdhanMode.fromName(parts[2]);
    if (slot == null ||
        mode == null ||
        mode == AdhanMode.off ||
        !NightPrayerSettings.allowedModes.contains(mode)) {
      return null;
    }
    return NightPayload(slot, mode);
  }
}

/// Payload d'un rappel de jeûne (`fast:<type>`) : le tap ouvre l'écran
/// « Jeûnes ».
///
/// [🔒 SÉCURITÉ] Parsing défensif : toute valeur inattendue donne `null`.
class FastPayload {
  final FastKind kind;

  const FastPayload(this.kind);

  static const String _prefix = 'fast';

  String encode() => '$_prefix:${kind.name}';

  static FastPayload? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2 || parts[0] != _prefix) return null;
    final kind = FastKind.fromName(parts[1]);
    return kind == null ? null : FastPayload(kind);
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
/// La prière de nuit ajoute jusqu'à 2 notifications par jour (soir ou
/// Tarawih + dernier tiers) : ~8 jours, ~5 jours avec rappel avant. Le
/// budget est commun et trié par date : on tronque toujours les plus
/// lointaines, quel que soit leur type.
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
    CalendarSettings calendar = const CalendarSettings(),
    int budget = defaultBudget,
    String Function(DateTime instant)? formatTime,
  }) {
    if (budget <= 0) return PrayerPlan.empty;
    final fmt = formatTime ?? _formatLocal;
    final threshold = now.toUtc().add(minimumLead);
    final candidates = <PlannedNotification>[
      if (settings.night.isActive)
        ..._nightCandidates(days, settings.night, calendar, fmt),
      if (settings.fasting.isActive)
        ..._fastCandidates(days, settings.fasting, calendar),
    ];
    final prayersOn = settings.prayersEnabled && settings.prayers.isNotEmpty;

    for (final day in prayersOn ? days : const <PrayerDay>[]) {
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

  /// Notifications de la prière de nuit, pour chaque nuit dont le
  /// lendemain est connu (la dernière nuit du calendrier est ignorée).
  static List<PlannedNotification> _nightCandidates(
    List<PrayerDay> days,
    NightPrayerSettings night,
    CalendarSettings calendar,
    String Function(DateTime) fmt,
  ) {
    final result = <PlannedNotification>[];
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final next = i + 1 < days.length ? days[i + 1] : null;
      final window = NightPrayerCalculator.nightOf(day, next);
      final isha = day.times[Prayer.isha];
      if (window == null || isha == null) continue;

      final lastThird = NightPrayerCalculator.lastThird(window,
          fajrMarginMinutes: night.fajrMarginMinutes);

      // Soirée : Tarawih pendant le Ramadan (s'il est activé), sinon rappel.
      // Le mois suit l'ajustement choisi par le croyant (annonce locale).
      final hijri = NightPrayerCalculator.hijriOfNight(day,
          adjustment: calendar.hijriAdjustment);
      final ramadan = hijri?.isRamadan ?? false;
      if (ramadan && night.tarawih != AdhanMode.off) {
        final at = isha.add(NightPrayerSettings.tarawihDelay);
        result.add(PlannedNotification.night(
          id: 0,
          when: at,
          title: 'Tarawih · ${ramadanNight(hijri!)}',
          body: 'Celui qui prie les nuits de Ramadan avec foi et espérance '
              'voit ses péchés passés pardonnés (Bukhari 37, Muslim 759).',
          slot: NightSlot.tarawih,
          mode: night.tarawih,
        ));
      } else if (night.evening != AdhanMode.off) {
        final at = isha.add(Duration(hours: night.eveningDelayHours));
        // Inutile d'annoncer le dernier tiers s'il a déjà commencé
        // (Isha tardif en été avec un délai de 2 h).
        if (at.isBefore(window.lastThirdStart)) {
          final third = lastThird == null ? '' : ', dès ${fmt(lastThird.at)}';
          result.add(PlannedNotification.night(
            id: 0,
            when: at,
            title: 'Prière de nuit',
            body: 'La meilleure prière après les obligatoires est la prière '
                'de nuit (Muslim 1163). Quelques rak‘as avant de dormir, ou '
                'au dernier tiers$third.',
            slot: NightSlot.evening,
            mode: night.evening,
          ));
        }
      }

      if (lastThird != null && night.lastThird != AdhanMode.off) {
        result.add(PlannedNotification.night(
          id: 0,
          when: lastThird.at,
          title: 'Prière de nuit · ${fmt(lastThird.at)}'
              // Dix dernières nuits : on donne le numéro (Laylat al-Qadr).
              '${ramadan && hijri!.day >= 21 ? ' · ${ramadanNight(hijri)}' : ''}',
          body: lastThird.clampedByMargin
              ? 'Le dernier tiers de la nuit est entamé, Fajr à '
                  '${fmt(window.fajrNext)}. Notre Seigneur descend au ciel le '
                  'plus proche : « Qui M’invoque, que Je lui réponde ? »'
              : 'Le dernier tiers de la nuit commence. Notre Seigneur descend '
                  'au ciel le plus proche : « Qui M’invoque, que Je lui '
                  'réponde ? »',
          slot: NightSlot.lastThird,
          mode: night.lastThird,
        ));
      }
    }
    return result;
  }

  /// Rappels de jeûne : la veille, 30 min après l'Isha (moment de
  /// l'intention et de prévoir le sahour). Il faut l'Isha de la veille :
  /// sans horaires, pas de rappel (jamais d'heure devinée).
  static List<PlannedNotification> _fastCandidates(
    List<PrayerDay> days,
    FastingSettings fasting,
    CalendarSettings calendar,
  ) {
    final result = <PlannedNotification>[];
    for (final day in days) {
      final isha = day.times[Prayer.isha];
      final eve = DateTime.tryParse(day.dateKey);
      if (isha == null || eve == null) continue;
      final fast = FastCalendar.on(
        DateTime(eve.year, eve.month, eve.day + 1),
        adjustment: calendar.hijriAdjustment,
        kinds: fasting.kinds,
      );
      if (fast == null) continue;
      final main = fast.mainKind;
      result.add(PlannedNotification.fast(
        id: 0,
        when: isha.add(FastingSettings.reminderAfterIsha),
        title: main == FastKind.ramadanStart
            ? 'Le Ramadan commence demain'
            : 'Demain : ${fast.title}',
        body: switch (main) {
          FastKind.ramadanStart => '${_cited(main)} '
              'Formulez l’intention du jeûne et pensez au sahour.',
          FastKind.shawwal when fast.hijri.day != 2 =>
            'Il reste la moitié du mois pour jeûner les 6 jours de Chawwal '
                '(${main.reference}).',
          _ => '${_cited(main)} Pensez à l’intention et au sahour.',
        },
        kind: main,
      ));
    }
    return result;
  }

  /// « Mérite du jeûne (Référence). »
  static String _cited(FastKind kind) {
    final virtue = kind.virtue.endsWith('.')
        ? kind.virtue.substring(0, kind.virtue.length - 1)
        : kind.virtue;
    return '$virtue (${kind.reference}).';
  }

  /// « 1re nuit de Ramadan », « 27e nuit de Ramadan ».
  static String ramadanNight(HijriDate date) =>
      '${date.day == 1 ? '1re' : '${date.day}e'} nuit de Ramadan';

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
