/// Signature ajoutée aux contenus partagés (hadiths, scores du quiz).
///
/// Un seul endroit à modifier pour changer le message ou ajouter le lien.
class ShareConfig {
  const ShareConfig._();

  static const String appName = 'Deen';

  /// Lien App Store de Deen, sans pays ni nom : Apple redirige chacun vers
  /// la boutique de son pays (le lien en « /us/ » ouvrait la fiche
  /// américaine aux utilisateurs français).
  static const String? appStoreUrl = 'https://apps.apple.com/app/id6817428500';

  /// « Partagé depuis Deen, l’app pour la prière, le Coran et les hadiths
  /// (lien) ».
  static String signature({String? url = appStoreUrl}) =>
      '— Partagé depuis $appName, l’app pour la prière, le Coran et les '
      'hadiths${url == null || url.isEmpty ? '.' : ' : $url'}';
}
