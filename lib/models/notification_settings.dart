import 'prayer_schedule.dart';

/// Réglages des notifications, modifiables par l'utilisateur.
///
/// Les rappels de prière sont désactivés par défaut : l'utilisateur les
/// active lui-même (c'est aussi à ce moment qu'iOS demande l'autorisation).
class NotificationSettings {
  final bool prayersEnabled;

  /// Prières pour lesquelles une notification est envoyée.
  final Set<Prayer> prayers;

  /// Rappel supplémentaire avant l'heure (0 = uniquement à l'heure).
  final int reminderMinutes;

  /// Méthode de calcul ; `null` = automatique.
  final int? methodId;

  final bool hadithDaily;
  final bool quizDaily;

  const NotificationSettings({
    this.prayersEnabled = false,
    this.prayers = const {...Prayer.values},
    this.reminderMinutes = 0,
    this.methodId,
    this.hadithDaily = true,
    this.quizDaily = true,
  });

  static const List<int> reminderChoices = [0, 10, 15, 30];

  NotificationSettings copyWith({
    bool? prayersEnabled,
    Set<Prayer>? prayers,
    int? reminderMinutes,
    int? Function()? methodId,
    bool? hadithDaily,
    bool? quizDaily,
  }) {
    return NotificationSettings(
      prayersEnabled: prayersEnabled ?? this.prayersEnabled,
      prayers: prayers ?? this.prayers,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      methodId: methodId != null ? methodId() : this.methodId,
      hadithDaily: hadithDaily ?? this.hadithDaily,
      quizDaily: quizDaily ?? this.quizDaily,
    );
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final prayers = (json['prayers'] as List<dynamic>?)
        ?.map((e) => Prayer.fromName('$e'))
        .whereType<Prayer>()
        .toSet();
    final reminder = json['reminderMinutes'] as int? ?? 0;
    return NotificationSettings(
      prayersEnabled: json['prayersEnabled'] as bool? ?? false,
      prayers: prayers ?? const {...Prayer.values},
      reminderMinutes: reminderChoices.contains(reminder) ? reminder : 0,
      methodId: json['methodId'] as int?,
      hadithDaily: json['hadithDaily'] as bool? ?? true,
      quizDaily: json['quizDaily'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'prayersEnabled': prayersEnabled,
        'prayers': prayers.map((p) => p.name).toList(),
        'reminderMinutes': reminderMinutes,
        'methodId': methodId,
        'hadithDaily': hadithDaily,
        'quizDaily': quizDaily,
      };
}
