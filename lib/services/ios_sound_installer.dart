import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'adhan_sound_resolver.dart';

/// Installe les sons d'adhan là où iOS sait les lire pour une notification.
///
/// iOS cherche le son d'une notification locale dans le bundle de l'app
/// **ou** dans `<conteneur>/Library/Sounds`. On utilise ce second
/// emplacement, alimenté depuis les assets Flutter :
/// - aucune modification du projet Xcode (fragile, oubliée facilement) ;
/// - une seule source de vérité pour les fichiers (`assets/audio/`) ;
/// - possibilité future de télécharger d'autres voix au même endroit.
///
/// [⚠️ PROD] Contraintes iOS : 30 s maximum, formats Linear PCM / IMA4 /
/// µLaw / aLaw dans un conteneur .caf, .aiff ou .wav. Au-delà de 30 s,
/// iOS joue le son par défaut sans aucune erreur.
class IosSoundInstaller {
  IosSoundInstaller({
    Future<Directory> Function()? libraryDirectory,
    Future<ByteData> Function(String key)? loadAsset,
    bool? isIos,
  })  : _libraryDirectory = libraryDirectory ?? getLibraryDirectory,
        _loadAsset = loadAsset ?? rootBundle.load,
        _isIos = isIos ?? (!kIsWeb && Platform.isIOS);

  final Future<Directory> Function() _libraryDirectory;
  final Future<ByteData> Function(String key) _loadAsset;
  final bool _isIos;

  /// À incrémenter quand les fichiers audio changent : force la recopie.
  /// (Sans ça, un utilisateur garderait l'ancien son après mise à jour.)
  static const int soundsVersion = 1;

  static const String assetDirectory = 'assets/audio/notification';

  static const List<String> soundFiles = [
    '${AdhanSoundResolver.shortSoundName}.caf',
    '${AdhanSoundResolver.longSoundName}.caf',
  ];

  static const String _versionFile = '.adhan_sounds_version';

  /// Idempotent et silencieux en cas d'échec : au pire, iOS jouera le son
  /// par défaut, ce qui vaut mieux qu'une app qui plante au démarrage.
  Future<void> install() async {
    if (!_isIos) return;
    try {
      final library = await _libraryDirectory();
      final sounds = Directory('${library.path}/Sounds');
      final marker = File('${sounds.path}/$_versionFile');
      if (await _isUpToDate(marker, sounds)) return;

      await sounds.create(recursive: true);
      for (final name in soundFiles) {
        final data = await _loadAsset('$assetDirectory/$name');
        await File('${sounds.path}/$name').writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      // Marqueur écrit en dernier : une copie interrompue sera refaite.
      await marker.writeAsString('$soundsVersion', flush: true);
    } on Object catch (e) {
      debugPrint('Sons d’adhan non installés ($e)');
    }
  }

  Future<bool> _isUpToDate(File marker, Directory sounds) async {
    if (!await marker.exists()) return false;
    if ((await marker.readAsString()).trim() != '$soundsVersion') return false;
    for (final name in soundFiles) {
      if (!await File('${sounds.path}/$name').exists()) return false;
    }
    return true;
  }
}
