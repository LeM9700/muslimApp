import Flutter
import UIKit
import WidgetKit

/// Pont Flutter → widget d'écran verrouillé (canal `deen/prayer_widget`).
///
/// Écrit la chronologie (JSON calculé et testé côté Dart) dans l'App Group
/// partagé avec l'extension `PrayerWidget`, puis demande à iOS de la
/// redessiner. Aucune logique métier ici : uniquement du transport.
final class PrayerWidgetBridge: NSObject, FlutterPlugin {
  /// [⚠️ PROD] Doit correspondre à l'App Group des deux profils de
  /// provisionnement (app et extension) et à `PrayerWidget.swift`.
  static let appGroup = "group.com.elboazzati.muslimapp"
  static let timelineKey = "prayer_timeline_v1"
  static let widgetKind = "PrayerTimelineWidget"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "deen/prayer_widget",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(PrayerWidgetBridge(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let defaults = UserDefaults(suiteName: Self.appGroup) else {
      result(FlutterError(code: "no_app_group", message: "App Group indisponible", details: nil))
      return
    }
    switch call.method {
    case "publish":
      guard let args = call.arguments as? [String: Any],
            let timeline = args["timeline"] as? String else {
        result(FlutterError(code: "bad_args", message: "timeline manquant", details: nil))
        return
      }
      // [⚡ PERF] Rien à redessiner si la chronologie n'a pas changé.
      if defaults.string(forKey: Self.timelineKey) != timeline {
        defaults.set(timeline, forKey: Self.timelineKey)
        reloadWidgets()
      }
      result(nil)
    case "clear":
      if defaults.string(forKey: Self.timelineKey) != nil {
        defaults.removeObject(forKey: Self.timelineKey)
        reloadWidgets()
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// WidgetKit est lié en « weak » : l'app accepte encore iOS 13.
  private func reloadWidgets() {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
    }
  }
}
