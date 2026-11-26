import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/adhan_mode.dart';
import '../models/prayer_schedule.dart';

/// Emplacement des enregistrements de l'adhan dans les assets Flutter.
///
/// Les sons de **notification** vivent ailleurs (res/raw sur Android,
/// Library/Sounds sur iOS) : ceux-ci servent à l'écoute dans l'app
/// (aperçu dans les réglages, adhan intégral dans le lecteur).
class AdhanAudioCatalog {
  const AdhanAudioCatalog._();

  /// Build compilé avec un audio de test non publiable
  /// (`--dart-define=ADHAN_TEST_AUDIO=true`, posé par le CI).
  static const bool isTestAudio = bool.fromEnvironment('ADHAN_TEST_AUDIO');

  static const String shortPreview = 'assets/audio/adhan_short.mp3';
  static const String longPreview = 'assets/audio/adhan_long.mp3';
  static const String full = 'assets/audio/adhan_full.mp3';

  /// Adhan du Fajr (« As-salātu khayrun min an-nawm »), facultatif.
  static const String fajrFull = 'assets/audio/adhan_fajr_full.mp3';

  /// Aperçu du son de notification d'un mode, `null` = son système.
  static String? previewFor(AdhanMode mode) => switch (mode) {
        AdhanMode.adhanShort => shortPreview,
        AdhanMode.adhanFull => longPreview,
        _ => null,
      };

  /// Adhan intégral à proposer pour [prayer], par ordre de préférence.
  /// La phrase propre au Fajr arrive vers la fin de l'appel : elle ne
  /// s'entend que dans la version intégrale, pas dans l'extrait de 30 s.
  static List<String> fullFor(Prayer prayer) =>
      prayer == Prayer.fajr ? const [fajrFull, full] : const [full];
}

/// Lecture d'un enregistrement (frontière avec just_audio, remplaçable en
/// test).
abstract class AdhanPlayback {
  /// Vrai pendant la lecture ; repasse à faux en fin de piste.
  ValueListenable<bool> get isPlaying;

  /// Lit le premier asset lisible de [assets]. Lève [AdhanPlaybackException]
  /// si aucun ne l'est.
  Future<void> playFirstAvailable(List<String> assets);

  Future<void> stop();

  Future<void> dispose();
}

class AdhanPlaybackException implements Exception {
  final String message;
  const AdhanPlaybackException(this.message);

  @override
  String toString() => 'AdhanPlaybackException: $message';
}

/// Implémentation just_audio.
class JustAudioAdhanPlayback implements AdhanPlayback {
  JustAudioAdhanPlayback([AudioPlayer? player])
      : _player = player ?? AudioPlayer() {
    _subscription = _player.playerStateStream.listen((state) {
      final playing = state.playing &&
          state.processingState != ProcessingState.completed &&
          state.processingState != ProcessingState.idle;
      _isPlaying.value = playing;
      if (state.processingState == ProcessingState.completed) {
        // Revenir au début : un nouvel appui relance proprement.
        unawaited(_player.stop());
      }
    });
  }

  final AudioPlayer _player;
  final ValueNotifier<bool> _isPlaying = ValueNotifier(false);
  late final StreamSubscription<PlayerState> _subscription;

  @override
  ValueListenable<bool> get isPlaying => _isPlaying;

  @override
  Future<void> playFirstAvailable(List<String> assets) async {
    await _player.stop();
    for (final asset in assets) {
      try {
        await _player.setAsset(asset);
      } on Object catch (e) {
        // Asset absent (ex. adhan du Fajr non fourni) : on passe au suivant.
        debugPrint('Adhan : $asset illisible ($e)');
        continue;
      }
      // play() ne se termine qu'en fin de piste : on ne l'attend pas.
      unawaited(_player.play());
      return;
    }
    throw const AdhanPlaybackException('Aucun enregistrement disponible');
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    _isPlaying.dispose();
    await _player.dispose();
  }
}
