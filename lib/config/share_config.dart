/// Signature ajoutée aux contenus partagés (hadiths, scores du quiz).
///
/// Un seul endroit à modifier pour changer le message ou ajouter le lien.
class ShareConfig {
  const ShareConfig._();

  static const String appName = 'Deen';

  /// Lien App Store de Deen. [⚠️ PROD] À renseigner dès que possible
  /// (App Store Connect → l'app → Informations sur l'app → lien
  /// « Voir sur l'App Store ») : sans lien, la signature reste sans URL.
  static const String? appStoreUrl = null;

  /// « Partagé depuis Deen, l’app pour la prière, le Coran et les hadiths
  /// (lien) ».
  static String signature({String? url = appStoreUrl}) =>
      '— Partagé depuis $appName, l’app pour la prière, le Coran et les '
      'hadiths${url == null || url.isEmpty ? '.' : ' : $url'}';
}
