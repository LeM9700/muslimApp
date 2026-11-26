import 'package:flutter/foundation.dart';
import 'package:muslim_app/services/adhan_audio.dart';

/// Faux lecteur : enregistre les demandes, simule les assets absents.
class FakePlayback implements AdhanPlayback {
  FakePlayback({this.available = const {}});

  /// Assets lisibles (les autres lèvent comme un fichier manquant).
  final Set<String> available;
  final List<String> played = [];
  int stops = 0;
  bool disposed = false;
  final ValueNotifier<bool> _playing = ValueNotifier(false);

  @override
  ValueListenable<bool> get isPlaying => _playing;

  @override
  Future<void> playFirstAvailable(List<String> assets) async {
    _playing.value = false;
    for (final a in assets) {
      if (available.contains(a)) {
        played.add(a);
        _playing.value = true;
        return;
      }
    }
    throw const AdhanPlaybackException('absent');
  }

  void finish() => _playing.value = false;

  @override
  Future<void> stop() async {
    stops++;
    _playing.value = false;
  }

  @override
  Future<void> dispose() async => disposed = true;
}
