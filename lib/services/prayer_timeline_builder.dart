import 'dart:convert';

import '../models/prayer_schedule.dart';

/// Position d'une prière sur l'arc d'une journée.
class TimelineMarker {
  final Prayer prayer;
  final DateTime at;

  /// 0 = Fajr (début de l'arc), 1 = Isha (fin), proportionnel au temps.
  final double position;

  const TimelineMarker(this.prayer, this.at, this.position);

  Map<String, dynamic> toJson() => {
        'name': prayer.label,
        'key': prayer.name,
        'at': at.millisecondsSinceEpoch ~/ 1000,
        'pos': _round(position),
      };
}

/// Un état du widget, valable à partir de [start] jusqu'à l'entrée suivante.
class TimelineEntry {
  final DateTime start;

  /// Indice (dans `days`) de la journée affichée sur l'arc : celle de la
  /// prochaine prière.
  final int dayIndex;

  /// Avancement sur l'arc (0 avant le Fajr, 1 à l'Isha).
  final double progress;

  /// Dernière prière passée de la journée affichée, `null` avant le Fajr.
  final Prayer? current;

  final Prayer next;
  final DateTime nextAt;

  const TimelineEntry({
    required this.start,
    required this.dayIndex,
    required this.progress,
    required this.current,
    required this.next,
    required this.nextAt,
  });

  Map<String, dynamic> toJson() => {
        't': start.millisecondsSinceEpoch ~/ 1000,
        'day': dayIndex,
        'progress': _round(progress),
        'current': current?.name,
        'next': next.label,
        'nextKey': next.name,
        'nextAt': nextAt.millisecondsSinceEpoch ~/ 1000,
      };
}

/// Données lues par le widget d'écran verrouillé (iOS, WidgetKit).
///
/// Tout le calcul est fait ici, en Dart pur et testé : le code Swift ne
/// fait que choisir l'entrée courante et dessiner. Une seule source de
/// vérité pour « quelle est la prochaine prière ».
class PrayerTimeline {
  /// Version du format : le widget ignore un format qu'il ne connaît pas.
  static const int version = 1;

  final String cityName;
  final DateTime generatedAt;
  final List<String> dayKeys;
  final List<List<TimelineMarker>> markers;
  final List<TimelineEntry> entries;

  const PrayerTimeline({
    required this.cityName,
    required this.generatedAt,
    required this.dayKeys,
    required this.markers,
    required this.entries,
  });

  bool get isEmpty => entries.isEmpty;

  /// Fin de validité : après la dernière prière connue, le widget invite
  /// à ouvrir l'app (le calendrier n'est pas deviné).
  DateTime? get validUntil => entries.isEmpty ? null : entries.last.nextAt;

  Map<String, dynamic> toJson() => {
        'v': version,
        'city': cityName,
        'generatedAt': generatedAt.millisecondsSinceEpoch ~/ 1000,
        'validUntil': validUntil == null
            ? null
            : validUntil!.millisecondsSinceEpoch ~/ 1000,
        'days': [
          for (var i = 0; i < dayKeys.length; i++)
            {
              'date': dayKeys[i],
              'markers': markers[i].map((m) => m.toJson()).toList(),
            },
        ],
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  String encode() => json.encode(toJson());
}

/// Construit la chronologie à partir du calendrier.
class PrayerTimelineBuilder {
  const PrayerTimelineBuilder._();

  /// Pas entre deux états du widget : WidgetKit ne redessine qu'aux
  /// entrées, le point avance donc par crans de 15 min (le compte à
  /// rebours, lui, est animé en continu par iOS).
  static const Duration step = Duration(minutes: 15);

  /// [⚡ PERF] Horizon couvert : ~100 entrées par jour, ~700 sur 7 jours
  /// (~45 Ko de JSON). Le widget n'en charge que 24 h à la fois.
  static const int maxDays = 7;

  static PrayerTimeline build({
    required List<PrayerDay> days,
    required DateTime now,
    required String cityName,
  }) {
    final nowUtc = now.toUtc();
    // Journées complètes, dans l'ordre, dont l'Isha n'est pas passé.
    final usable = days
        .where((d) =>
            Prayer.values.every((p) => d.times[p] != null) &&
            d.times[Prayer.isha]!.isAfter(nowUtc))
        .take(maxDays)
        .toList();

    final markers = [for (final d in usable) _markersOf(d)];
    final entries = <TimelineEntry>[];
    if (usable.isNotEmpty) {
      // Instants où l'état change : chaque prière + tous les [step].
      final prayerInstants = <DateTime>[
        for (final d in usable)
          for (final p in Prayer.values) d.times[p]!,
      ];
      final end = prayerInstants.last;
      // 1re entrée à l'instant exact (et non au quart d'heure arrondi) :
      // une prière passée entre les deux serait sinon encore « prochaine ».
      final instants = <DateTime>{
        nowUtc,
        ...prayerInstants.where((t) => t.isAfter(nowUtc)),
      };
      for (var t = _floorTo(nowUtc, step).add(step);
          t.isBefore(end);
          t = t.add(step)) {
        instants.add(t);
      }
      final sorted = instants.toList()..sort();
      for (final t in sorted) {
        final entry = _entryAt(t, usable, markers);
        if (entry != null) entries.add(entry);
      }
    }

    return PrayerTimeline(
      cityName: cityName,
      generatedAt: nowUtc,
      dayKeys: [for (final d in usable) d.dateKey],
      markers: markers,
      entries: entries,
    );
  }

  /// État à l'instant [t] : la journée affichée est celle de la prochaine
  /// prière (après l'Isha, on passe à l'arc du lendemain, point au début).
  static TimelineEntry? _entryAt(
    DateTime t,
    List<PrayerDay> days,
    List<List<TimelineMarker>> markers,
  ) {
    for (var i = 0; i < days.length; i++) {
      for (final m in markers[i]) {
        if (!m.at.isAfter(t)) continue;
        final fajr = markers[i].first.at;
        final isha = markers[i].last.at;
        final span = isha.difference(fajr).inSeconds;
        final progress = m.prayer == Prayer.fajr || span <= 0
            ? 0.0
            : (t.difference(fajr).inSeconds / span).clamp(0.0, 1.0);
        Prayer? current;
        for (final c in markers[i]) {
          if (!c.at.isAfter(t)) current = c.prayer;
        }
        return TimelineEntry(
          start: t,
          dayIndex: i,
          progress: progress,
          current: current,
          next: m.prayer,
          nextAt: m.at,
        );
      }
    }
    return null; // après la dernière prière connue
  }

  static List<TimelineMarker> _markersOf(PrayerDay day) {
    final fajr = day.times[Prayer.fajr]!;
    final span = day.times[Prayer.isha]!.difference(fajr).inSeconds;
    return [
      for (final p in Prayer.values)
        TimelineMarker(
          p,
          day.times[p]!,
          span <= 0
              ? 0
              : (day.times[p]!.difference(fajr).inSeconds / span).clamp(0.0, 1.0),
        ),
    ];
  }

  static DateTime _floorTo(DateTime t, Duration step) {
    final ms = t.millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(ms - ms % step.inMilliseconds,
        isUtc: true);
  }
}

double _round(double v) => (v * 10000).round() / 10000;
