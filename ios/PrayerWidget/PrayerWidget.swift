import SwiftUI
import WidgetKit

// Widget d'écran verrouillé « Chronologie des prières ».
//
// Tout le calcul (prochaine prière, avancement sur l'arc) est fait et
// testé côté Dart (`PrayerTimelineBuilder`) ; ce fichier ne fait que
// choisir l'entrée courante et dessiner.

private let appGroup = "group.com.elboazzati.muslimapp"
private let timelineKey = "prayer_timeline_v1"
private let supportedVersion = 1

// MARK: - Données (JSON écrit par l'app)

struct TimelineData: Decodable {
  let v: Int
  let city: String
  let days: [Day]
  let entries: [Entry]

  struct Day: Decodable {
    let date: String
    let markers: [Marker]
  }

  struct Entry: Decodable {
    let t: TimeInterval
    let day: Int
    let progress: Double
    let current: String?
    let next: String
    let nextKey: String
    let nextAt: TimeInterval
  }
}

struct Marker: Decodable {
  let name: String
  let key: String
  let at: TimeInterval
  let pos: Double
}

struct Snapshot {
  let city: String
  let markers: [Marker]
  let progress: Double
  /// Nombre de prières déjà passées sur l'arc affiché.
  let passed: Int
  let next: String
  let nextKey: String
  let nextAt: Date
}

struct PrayerEntry: TimelineEntry {
  let date: Date
  /// `nil` : aucune donnée (widget désactivé dans l'app, ou périmé).
  let snapshot: Snapshot?

  static let sample: PrayerEntry = {
    let now = Date()
    let markers = [
      Marker(name: "Fajr", key: "fajr", at: 0, pos: 0),
      Marker(name: "Dhuhr", key: "dhuhr", at: 0, pos: 0.47),
      Marker(name: "Asr", key: "asr", at: 0, pos: 0.66),
      Marker(name: "Maghrib", key: "maghrib", at: 0, pos: 0.88),
      Marker(name: "Isha", key: "isha", at: 0, pos: 1),
    ]
    return PrayerEntry(
      date: now,
      snapshot: Snapshot(
        city: "Paris", markers: markers, progress: 0.55, passed: 2,
        next: "Asr", nextKey: "asr", nextAt: now.addingTimeInterval(4800)))
  }()
}

// MARK: - Fournisseur

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> PrayerEntry { .sample }

  func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
    if context.isPreview {
      completion(.sample)
    } else {
      completion(entries(now: Date()).first ?? PrayerEntry(date: Date(), snapshot: nil))
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
    let now = Date()
    let list = entries(now: now)
    if list.isEmpty {
      // Rien à afficher : on revérifie dans une heure (l'app a pu écrire).
      completion(Timeline(
        entries: [PrayerEntry(date: now, snapshot: nil)],
        policy: .after(now.addingTimeInterval(3600))))
    } else {
      completion(Timeline(entries: list, policy: .atEnd))
    }
  }

  /// [⚡ PERF] Entrées des 24 prochaines heures seulement (~100) : iOS
  /// redemande la suite à la fin (`.atEnd`).
  private func entries(now: Date) -> [PrayerEntry] {
    guard let raw = UserDefaults(suiteName: appGroup)?.string(forKey: timelineKey),
          let data = raw.data(using: .utf8),
          let timeline = try? JSONDecoder().decode(TimelineData.self, from: data),
          timeline.v == supportedVersion else {
      return []
    }
    let nowTs = now.timeIntervalSince1970
    let horizon = nowTs + 24 * 3600
    // Jamais une « prochaine prière » déjà passée : sans données à jour,
    // le widget invite à ouvrir l'app plutôt que d'afficher du faux.
    let upcoming = timeline.entries.filter { $0.nextAt > nowTs && $0.t <= horizon }
    guard !upcoming.isEmpty else { return [] }
    let start = upcoming.lastIndex(where: { $0.t <= nowTs }) ?? 0

    return upcoming[start...].compactMap { e -> PrayerEntry? in
      guard timeline.days.indices.contains(e.day) else { return nil }
      let markers = timeline.days[e.day].markers
      let passed = e.current.flatMap { key in
        markers.firstIndex(where: { $0.key == key }).map { $0 + 1 }
      } ?? 0
      return PrayerEntry(
        date: Date(timeIntervalSince1970: max(e.t, nowTs)),
        snapshot: Snapshot(
          city: timeline.city, markers: markers, progress: e.progress,
          passed: passed, next: e.next, nextKey: e.nextKey,
          nextAt: Date(timeIntervalSince1970: e.nextAt)))
    }
  }
}

// MARK: - Vues

private func symbol(for key: String) -> String {
  switch key {
  case "fajr": return "sunrise"
  case "dhuhr": return "sun.max"
  case "asr": return "sun.min"
  case "maghrib": return "sunset"
  default: return "moon.stars"
  }
}

/// Arc de la journée (courbe de Bézier quadratique), du Fajr à l'Isha.
private struct DayArc {
  let size: CGSize

  private var p0: CGPoint { CGPoint(x: 5, y: size.height - 4) }
  private var p2: CGPoint { CGPoint(x: size.width - 5, y: size.height - 4) }
  private var control: CGPoint { CGPoint(x: size.width / 2, y: -size.height + 8) }

  func point(_ t: Double) -> CGPoint {
    let t = CGFloat(min(max(t, 0), 1))
    let u = 1 - t
    return CGPoint(
      x: u * u * p0.x + 2 * u * t * control.x + t * t * p2.x,
      y: u * u * p0.y + 2 * u * t * control.y + t * t * p2.y)
  }

  /// Portion de l'arc de `from` à `to` (échantillonnée, pour rester
  /// cohérente avec la position des points).
  func path(from: Double, to: Double) -> Path {
    var path = Path()
    let steps = 32
    for i in 0...steps {
      let t = from + (to - from) * Double(i) / Double(steps)
      if i == 0 { path.move(to: point(t)) } else { path.addLine(to: point(t)) }
    }
    return path
  }
}

private struct ArcView: View {
  let snapshot: Snapshot

  var body: some View {
    GeometryReader { geo in
      let arc = DayArc(size: geo.size)
      ZStack {
        arc.path(from: 0, to: 1)
          .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
          .opacity(0.3)
        arc.path(from: 0, to: snapshot.progress)
          .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
        ForEach(Array(snapshot.markers.enumerated()), id: \.offset) { index, marker in
          Circle()
            .frame(width: 5, height: 5)
            .opacity(index < snapshot.passed ? 1 : 0.45)
            .position(arc.point(marker.pos))
        }
        Circle()
          .frame(width: 9, height: 9)
          .position(arc.point(snapshot.progress))
      }
    }
  }
}

private struct RectangularView: View {
  let snapshot: Snapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      ArcView(snapshot: snapshot)
        .frame(height: 26)
      HStack(spacing: 4) {
        Image(systemName: symbol(for: snapshot.nextKey))
        Text(snapshot.next).fontWeight(.semibold)
        Text(snapshot.nextAt, style: .time)
        Spacer(minLength: 2)
        Text(snapshot.nextAt, style: .timer)
          .monospacedDigit()
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 58, alignment: .trailing)
      }
      .font(.caption)
      .lineLimit(1)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Prochaine prière : \(snapshot.next)"))
  }
}

private struct CircularView: View {
  let snapshot: Snapshot

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      VStack(spacing: 0) {
        Image(systemName: symbol(for: snapshot.nextKey))
          .font(.system(size: 12))
        Text(snapshot.next)
          .font(.system(size: 10, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text(snapshot.nextAt, style: .time)
          .font(.system(size: 11))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
      .padding(4)
    }
  }
}

private struct InlineView: View {
  let snapshot: Snapshot

  var body: some View {
    Label {
      Text("\(snapshot.next) ") + Text(snapshot.nextAt, style: .time)
    } icon: {
      Image(systemName: symbol(for: snapshot.nextKey))
    }
  }
}

private struct MissingView: View {
  let family: WidgetFamily

  var body: some View {
    switch family {
    case .accessoryInline:
      Text("Deen : ouvrez l’app")
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        Image(systemName: "moon.stars")
      }
    default:
      Text("Activez la chronologie dans Deen")
        .font(.caption)
        .multilineTextAlignment(.leading)
    }
  }
}

struct PrayerWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: PrayerEntry

  var body: some View {
    if let snapshot = entry.snapshot {
      switch family {
      case .accessoryInline: InlineView(snapshot: snapshot)
      case .accessoryCircular: CircularView(snapshot: snapshot)
      default: RectangularView(snapshot: snapshot)
      }
    } else {
      MissingView(family: family)
    }
  }
}

private extension View {
  /// iOS 17 exige un fond de conteneur, sinon le widget affiche un
  /// message d'erreur à la place du contenu.
  @ViewBuilder
  func widgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) { Color.clear }
    } else {
      self
    }
  }
}

// MARK: - Déclaration

struct PrayerTimelineWidget: Widget {
  /// Identique à `PrayerWidgetBridge.widgetKind` (rechargement ciblé).
  let kind = "PrayerTimelineWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      PrayerWidgetView(entry: entry).widgetBackground()
    }
    .configurationDisplayName("Chronologie des prières")
    .description("La prochaine prière et l’avancée de la journée.")
    .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
  }
}

@main
struct PrayerWidgetBundle: WidgetBundle {
  var body: some Widget {
    PrayerTimelineWidget()
  }
}
