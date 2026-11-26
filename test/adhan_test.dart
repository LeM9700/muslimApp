import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim_app/controllers/adhan_player_controller.dart';
import 'package:muslim_app/models/adhan_mode.dart';
import 'package:muslim_app/models/notification_settings.dart';
import 'package:muslim_app/models/prayer_schedule.dart';
import 'package:muslim_app/repositories/aladhan_repository.dart';
import 'package:muslim_app/services/adhan_audio.dart';
import 'package:muslim_app/services/adhan_sound_resolver.dart';
import 'package:muslim_app/services/ios_sound_installer.dart';
import 'package:muslim_app/services/notification_gateway.dart';
import 'package:muslim_app/services/notification_router.dart';
import 'package:muslim_app/services/prayer_notification_planner.dart';

import 'support/fake_playback.dart';

/// Un jour fictif : Fajr 06:00 … Isha 19:00 (UTC+1), le 20/11/2026.
List<PrayerDay> _oneDay() {
  String at(int h, int m) =>
      '2026-11-20T${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00+01:00';
  return AladhanRepository.parseMonth({
    'code': 200,
    'data': [
      {
        'timings': {
          'Fajr': at(6, 0),
          'Dhuhr': at(12, 30),
          'Asr': at(15, 0),
          'Maghrib': at(17, 30),
          'Isha': at(19, 0),
        },
        'date': {
          'gregorian': {'date': '20-11-2026'},
        },
        'meta': {
          'method': {'id': 12, 'name': 'UOIF'},
        },
      },
    ],
  }).days;
}

/// 20/11/2026 04:00 UTC : toutes les prières du jour sont à venir.
final _dawn = DateTime.utc(2026, 11, 20, 4);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdhanSoundResolver', () {
    test('chaque mode programmable a son propre canal Android', () {
      final modes = AdhanMode.values.where((m) => m != AdhanMode.off);
      final channels =
          modes.map((m) => AdhanSoundResolver.resolve(m).androidChannelId);
      expect(channels.toSet(), hasLength(modes.length));
      expect(AdhanSoundResolver.all.map((s) => s.androidChannelId).toSet(),
          channels.toSet());
    });

    test('le canal historique de la v1.2.0 est conservé', () {
      expect(AdhanSoundResolver.resolve(AdhanMode.notification).androidChannelId,
          'prayer_channel');
    });

    test('adhan : son dédié, flux alarme ; silencieux : aucun son', () {
      for (final mode in [AdhanMode.adhanShort, AdhanMode.adhanFull]) {
        final s = AdhanSoundResolver.resolve(mode);
        expect(s.androidRawSound, isNotNull);
        expect(s.iosSound, endsWith('.caf'));
        expect(s.useAlarmStream, isTrue);
      }
      final silent = AdhanSoundResolver.resolve(AdhanMode.silent);
      expect(silent.playSound, isFalse);
      expect(silent.useAlarmStream, isFalse);
      expect(AdhanSoundResolver.resolve(AdhanMode.notification).useAlarmStream,
          isFalse);
    });

    test('les sons iOS sont ceux qu’installe IosSoundInstaller', () {
      final iosSounds = AdhanSoundResolver.all
          .map((s) => s.iosSound)
          .whereType<String>()
          .toSet();
      expect(iosSounds, IosSoundInstaller.soundFiles.toSet());
    });

    test('une prière désactivée ne se programme pas', () {
      expect(() => AdhanSoundResolver.resolve(AdhanMode.off), throwsArgumentError);
    });

    test('les fichiers sonores existent dans le projet', () {
      for (final name in [
        AdhanSoundResolver.shortSoundName,
        AdhanSoundResolver.longSoundName,
      ]) {
        expect(File('android/app/src/main/res/raw/$name.ogg').existsSync(), isTrue,
            reason: '$name.ogg manquant dans res/raw');
        expect(
            File('${IosSoundInstaller.assetDirectory}/$name.caf').existsSync(),
            isTrue,
            reason: '$name.caf manquant');
      }
      final keep = File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
      expect(keep, contains('@raw/${AdhanSoundResolver.shortSoundName}'));
      expect(keep, contains('@raw/${AdhanSoundResolver.longSoundName}'));
    });
  });

  group('LocalNotificationGateway.detailsFor', () {
    test('adhan : son brut, flux alarme et action « Arrêter »', () {
      final d = LocalNotificationGateway.detailsFor(AdhanMode.adhanFull);
      final android = d.android!;
      expect(android.channelId, 'prayer_adhan_v1');
      expect((android.sound! as RawResourceAndroidNotificationSound).sound,
          'adhan_long');
      expect(android.audioAttributesUsage, AudioAttributesUsage.alarm);
      expect(android.actions!.single.id, LocalNotificationGateway.stopAdhanActionId);
      expect(d.iOS!.sound, 'adhan_long.caf');
      expect(d.iOS!.interruptionLevel, InterruptionLevel.timeSensitive);
    });

    test('silencieux : ni son ni vibration, aucune action', () {
      final d = LocalNotificationGateway.detailsFor(AdhanMode.silent);
      expect(d.android!.playSound, isFalse);
      expect(d.android!.enableVibration, isFalse);
      expect(d.android!.actions, isNull);
      expect(d.iOS!.presentSound, isFalse);
      expect(d.iOS!.sound, isNull);
    });
  });

  group('NotificationSettings · modes', () {
    test('nouvel utilisateur : profil Équilibré', () {
      const s = NotificationSettings();
      expect(AdhanPreset.matching(s.modes), AdhanPreset.balanced);
      expect(s.modeOf(Prayer.fajr), AdhanMode.adhanFull);
      expect(s.modeOf(Prayer.dhuhr), AdhanMode.notification);
    });

    test('[⚠️ migration] v1.2.0 : prières cochées → Notification, jamais adhan',
        () {
      final s = NotificationSettings.fromJson({
        'prayersEnabled': true,
        'prayers': ['fajr', 'maghrib'],
      });
      expect(s.modeOf(Prayer.fajr), AdhanMode.notification);
      expect(s.modeOf(Prayer.maghrib), AdhanMode.notification);
      expect(s.modeOf(Prayer.dhuhr), AdhanMode.off);
      expect(s.prayers, {Prayer.fajr, Prayer.maghrib});
    });

    test('la migration est définitive : le format v1.3 est relu tel quel', () {
      final migrated = NotificationSettings.fromJson({'prayers': ['isha']});
      final reread = NotificationSettings.fromJson(migrated.toJson());
      expect(reread.modes, migrated.modes);
      expect(reread.toJson().containsKey('prayers'), isFalse);
    });

    test('mode inconnu (version future) → désactivé', () {
      final s = NotificationSettings.fromJson({
        'modes': {'fajr': 'adhanUltra', 'dhuhr': 'silent'},
      });
      expect(s.modeOf(Prayer.fajr), AdhanMode.off);
      expect(s.modeOf(Prayer.dhuhr), AdhanMode.silent);
    });

    test('withMode ne touche qu’une prière et rend « Personnalisé »', () {
      final s = const NotificationSettings()
          .withMode(Prayer.dhuhr, AdhanMode.adhanShort);
      expect(s.modeOf(Prayer.dhuhr), AdhanMode.adhanShort);
      expect(s.modeOf(Prayer.fajr), AdhanMode.adhanFull);
      expect(AdhanPreset.matching(s.modes), isNull);
    });

    test('les modes sont immuables', () {
      final s = const NotificationSettings()
          .copyWith(modes: {for (final p in Prayer.values) p: AdhanMode.silent});
      expect(() => s.modes[Prayer.fajr] = AdhanMode.off, throwsUnsupportedError);
    });
  });

  group('PrayerNotificationPlanner · modes', () {
    test('chaque notification porte le mode de sa prière', () {
      final plan = PrayerNotificationPlanner.plan(
        days: _oneDay(),
        settings: const NotificationSettings(prayersEnabled: true),
        now: _dawn,
        cityName: '',
      );
      final modes = {for (final n in plan.notifications) n.prayer: n.mode};
      expect(modes, AdhanPreset.balanced.modes);
    });

    test('une prière désactivée n’est pas programmée', () {
      final plan = PrayerNotificationPlanner.plan(
        days: _oneDay(),
        settings: const NotificationSettings(
          prayersEnabled: true,
          modes: {Prayer.asr: AdhanMode.adhanShort, Prayer.isha: AdhanMode.off},
        ),
        now: _dawn,
        cityName: '',
      );
      expect(plan.notifications.map((n) => n.prayer), [Prayer.asr]);
    });

    test('rappel avant : jamais d’adhan, silencieux si la prière l’est', () {
      final plan = PrayerNotificationPlanner.plan(
        days: _oneDay(),
        settings: const NotificationSettings(
          prayersEnabled: true,
          reminderMinutes: 10,
          modes: {Prayer.fajr: AdhanMode.adhanFull, Prayer.dhuhr: AdhanMode.silent},
        ),
        now: _dawn,
        cityName: '',
      );
      final reminders =
          plan.notifications.where((n) => n.kind == PlannedKind.reminder);
      expect({for (final r in reminders) r.prayer: r.mode}, {
        Prayer.fajr: AdhanMode.notification,
        Prayer.dhuhr: AdhanMode.silent,
      });
    });

    test('le payload encode prière et mode', () {
      final plan = PrayerNotificationPlanner.plan(
        days: _oneDay(),
        settings: const NotificationSettings(prayersEnabled: true),
        now: _dawn,
        cityName: '',
      );
      expect(plan.notifications.first.payload, 'prayer:fajr:adhanFull');
    });
  });

  group('NotificationPayload.decode', () {
    test('format courant', () {
      final p = NotificationPayload.decode('prayer:maghrib:adhanShort')!;
      expect(p.prayer, Prayer.maghrib);
      expect(p.mode, AdhanMode.adhanShort);
    });

    test('format v1.2.0 encore en attente dans le système', () {
      expect(NotificationPayload.decode('prayer:asr')!.mode,
          AdhanMode.notification);
    });

    test('[🔒] toute valeur inattendue → null, sans exception', () {
      for (final raw in [
        null,
        '',
        'hadith_daily',
        'prayer:',
        'prayer:dinner:adhanFull',
        'prayer:fajr:nope',
        'prayer:fajr:off',
        'prayer:fajr:adhanFull:extra',
        'other:fajr:adhanFull',
      ]) {
        expect(NotificationPayload.decode(raw), isNull, reason: '$raw');
      }
    });
  });

  group('NotificationRouter', () {
    late GlobalKey<NavigatorState> key;
    late List<Prayer> opened;
    late DateTime now;

    NotificationRouter router() => NotificationRouter(
          navigatorKey: key,
          clock: () => now,
          openPlayer: (_, prayer) => opened.add(prayer),
        );

    setUp(() {
      key = GlobalKey<NavigatorState>();
      opened = [];
      now = DateTime(2026, 11, 20, 18);
    });

    Future<void> mountNavigator(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(navigatorKey: key, home: const SizedBox()));

    testWidgets('ouvre le lecteur pour un adhan uniquement', (tester) async {
      await mountNavigator(tester);
      final r = router();
      expect(r.handle('prayer:maghrib:adhanFull'), isTrue);
      expect(r.handle('prayer:dhuhr:notification'), isFalse);
      expect(r.handle('prayer:isha:silent'), isFalse);
      expect(r.handle('quiz_daily'), isFalse);
      expect(opened, [Prayer.maghrib]);
    });

    testWidgets('ignore un doublon rapproché, pas un nouvel appui plus tard',
        (tester) async {
      await mountNavigator(tester);
      final r = router();
      expect(r.handle('prayer:fajr:adhanShort'), isTrue);
      expect(r.handle('prayer:fajr:adhanShort'), isFalse);
      now = now.add(const Duration(minutes: 1));
      expect(r.handle('prayer:fajr:adhanShort'), isTrue);
      expect(opened, [Prayer.fajr, Prayer.fajr]);
    });

    test('sans navigateur monté : rien, sans planter', () {
      expect(router().handle('prayer:fajr:adhanFull'), isFalse);
      expect(opened, isEmpty);
    });
  });

  group('IosSoundInstaller', () {
    late Directory library;
    late int loads;

    Future<ByteData> fakeAsset(String key) async {
      loads++;
      return ByteData.sublistView(Uint8List.fromList(key.codeUnits));
    }

    IosSoundInstaller installer({bool isIos = true}) => IosSoundInstaller(
          libraryDirectory: () async => library,
          loadAsset: fakeAsset,
          isIos: isIos,
        );

    setUp(() {
      library = Directory.systemTemp.createTempSync('adhan_lib_');
      loads = 0;
    });
    tearDown(() => library.deleteSync(recursive: true));

    test('copie les sons dans Library/Sounds', () async {
      await installer().install();
      for (final name in IosSoundInstaller.soundFiles) {
        final f = File('${library.path}/Sounds/$name');
        expect(f.existsSync(), isTrue);
        expect(f.readAsStringSync(), '${IosSoundInstaller.assetDirectory}/$name');
      }
    });

    test('idempotent : aucune recopie au lancement suivant', () async {
      await installer().install();
      final first = loads;
      await installer().install();
      expect(loads, first);
    });

    test('fichier supprimé ou version changée : recopie', () async {
      await installer().install();
      File('${library.path}/Sounds/${IosSoundInstaller.soundFiles.first}')
          .deleteSync();
      await installer().install();
      expect(loads, IosSoundInstaller.soundFiles.length * 2);

      File('${library.path}/Sounds/.adhan_sounds_version').writeAsStringSync('0');
      await installer().install();
      expect(loads, IosSoundInstaller.soundFiles.length * 3);
    });

    test('hors iOS : ne fait rien', () async {
      await installer(isIos: false).install();
      expect(Directory('${library.path}/Sounds').existsSync(), isFalse);
    });

    test('asset manquant : échec silencieux, pas de marqueur', () async {
      await IosSoundInstaller(
        libraryDirectory: () async => library,
        loadAsset: (_) async => throw FlutterError('absent'),
        isIos: true,
      ).install();
      expect(File('${library.path}/Sounds/.adhan_sounds_version').existsSync(),
          isFalse);
    });
  });

  group('AdhanPlayerController', () {
    test('Fajr : adhan du Fajr si disponible', () async {
      final playback = FakePlayback(available: {
        AdhanAudioCatalog.fajrFull,
        AdhanAudioCatalog.full,
      });
      final c = AdhanPlayerController(prayer: Prayer.fajr, playback: playback);
      await c.toggle();
      expect(playback.played, [AdhanAudioCatalog.fajrFull]);
      expect(c.isPlaying, isTrue);
    });

    test('Fajr sans enregistrement dédié : adhan habituel', () async {
      final playback = FakePlayback(available: {AdhanAudioCatalog.full});
      final c = AdhanPlayerController(prayer: Prayer.fajr, playback: playback);
      await c.toggle();
      expect(playback.played, [AdhanAudioCatalog.full]);
    });

    test('second appui : arrêt', () async {
      final playback = FakePlayback(available: {AdhanAudioCatalog.full});
      final c = AdhanPlayerController(prayer: Prayer.isha, playback: playback);
      await c.toggle();
      await c.toggle();
      expect(playback.stops, 1);
      expect(c.isPlaying, isFalse);
    });

    test('aucun fichier : état « indisponible », pas d’exception', () async {
      final c = AdhanPlayerController(prayer: Prayer.asr, playback: FakePlayback());
      await c.toggle();
      expect(c.unavailable, isTrue);
    });

    test('quitter l’écran libère le lecteur', () {
      final playback = FakePlayback();
      AdhanPlayerController(prayer: Prayer.asr, playback: playback).dispose();
      expect(playback.disposed, isTrue);
    });
  });

  group('AdhanAudioCatalog', () {
    test('aperçu uniquement pour les modes adhan', () {
      expect(AdhanAudioCatalog.previewFor(AdhanMode.adhanShort),
          AdhanAudioCatalog.shortPreview);
      expect(AdhanAudioCatalog.previewFor(AdhanMode.adhanFull),
          AdhanAudioCatalog.longPreview);
      expect(AdhanAudioCatalog.previewFor(AdhanMode.notification), isNull);
    });

    test('les assets du lecteur existent', () {
      for (final asset in [
        AdhanAudioCatalog.shortPreview,
        AdhanAudioCatalog.longPreview,
        AdhanAudioCatalog.full,
      ]) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    });
  });
}
