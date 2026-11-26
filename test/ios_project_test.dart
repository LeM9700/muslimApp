import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le CI signe en manuel en ajoutant des lignes aux fichiers .xcconfig.
/// [⚠️ PROD] Un réglage de signature écrit dans une cible du projet Xcode
/// l'emporterait sur ces fichiers et casserait l'archive (« conflicting
/// provisioning settings », vu en CI le 26/11/2026).
void main() {
  final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  /// Blocs de configuration (Debug/Release/Profile) d'une cible, repérés
  /// par son identifiant de bundle.
  List<String> configsOf(String bundleId) => pbxproj
      .split('isa = XCBuildConfiguration;')
      .where((b) => b.contains('PRODUCT_BUNDLE_IDENTIFIER = $bundleId;'))
      .toList();

  for (final bundleId in [
    'com.elboazzati.muslimapp',
    'com.elboazzati.muslimapp.PrayerWidget',
  ]) {
    test('$bundleId : aucun réglage de signature dans la cible', () {
      final configs = configsOf(bundleId);
      expect(configs, hasLength(3), reason: 'Debug, Release, Profile');
      for (final block in configs) {
        for (final key in [
          'CODE_SIGN_STYLE',
          'PROVISIONING_PROFILE_SPECIFIER',
          'DEVELOPMENT_TEAM',
          'CODE_SIGN_IDENTITY',
        ]) {
          expect(block, isNot(contains(key)), reason: '$bundleId : $key');
        }
      }
    });
  }

  test('xcconfig Release de l’extension : include d’abord, le CI ajoute après', () {
    final release = File('ios/PrayerWidget/PrayerWidgetRelease.xcconfig').readAsStringSync();
    expect(release.trimLeft(), startsWith('#include "PrayerWidget.xcconfig"'));
    expect(File('ios/PrayerWidget/PrayerWidget.xcconfig').readAsStringSync(),
        contains('CODE_SIGN_STYLE = Automatic'));
  });
}
