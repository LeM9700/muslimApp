import 'package:flutter/foundation.dart';

import '../models/prayer_schedule.dart';
import '../services/adhan_audio.dart';

/// État du lecteur d'adhan intégral (écran ouvert depuis la notification).
class AdhanPlayerController extends ChangeNotifier {
  AdhanPlayerController({required this.prayer, AdhanPlayback? playback})
      : _playback = playback ?? JustAudioAdhanPlayback() {
    _playback.isPlaying.addListener(notifyListeners);
  }

  final Prayer prayer;
  final AdhanPlayback _playback;

  bool _unavailable = false;
  bool _disposed = false;

  bool get isPlaying => _playback.isPlaying.value;

  /// Aucun enregistrement lisible (fichier manquant dans le build).
  bool get unavailable => _unavailable;

  /// Lance ou arrête l'adhan intégral.
  Future<void> toggle() async {
    if (isPlaying) {
      await _playback.stop();
      return;
    }
    try {
      await _playback.playFirstAvailable(AdhanAudioCatalog.fullFor(prayer));
      _unavailable = false;
    } on AdhanPlaybackException {
      _unavailable = true;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _playback.isPlaying.removeListener(notifyListeners);
    _playback.dispose();
    super.dispose();
  }
}
