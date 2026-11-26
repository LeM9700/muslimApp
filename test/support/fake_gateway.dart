import 'package:muslim_app/services/notification_gateway.dart';
import 'package:muslim_app/services/prayer_notification_planner.dart';
import 'package:muslim_app/services/prayer_widget_gateway.dart';

/// Faux système de notifications : enregistre ce qui serait programmé.
class FakeGateway implements NotificationGateway {
  bool permission;
  bool grantOnRequest;
  int requests = 0;
  final List<DailyNotification> daily = [];
  final List<PlannedNotification> prayers = [];
  int tests = 0;

  int prepared = 0;

  FakeGateway({this.permission = true, this.grantOnRequest = true});

  @override
  Future<void> prepare() async => prepared++;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async {
    requests++;
    permission = grantOnRequest;
    return permission;
  }

  @override
  Future<void> cancelAll() async {
    daily.clear();
    prayers.clear();
  }

  @override
  Future<void> scheduleDaily(DailyNotification n) async => daily.add(n);

  @override
  Future<void> schedulePrayer(PlannedNotification n) async => prayers.add(n);

  @override
  Future<void> showTest({required String title, required String body}) async =>
      tests++;
}

/// Faux widget d'écran verrouillé : enregistre les publications.
class FakeWidgetGateway implements PrayerWidgetGateway {
  final List<String> published = [];
  int clears = 0;

  /// Dernière chronologie publiée, `null` si effacée depuis.
  String? current;

  @override
  Future<void> publish(String timelineJson) async {
    published.add(timelineJson);
    current = timelineJson;
  }

  @override
  Future<void> clear() async {
    clears++;
    current = null;
  }
}
