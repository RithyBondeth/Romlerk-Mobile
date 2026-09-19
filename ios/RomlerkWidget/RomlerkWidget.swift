import SwiftUI
import WidgetKit

// Today widget (FR-22). Reads the JSON that `WidgetSyncService` writes to the
// shared App Group under `today_payload`; the `kind` below must match
// `WidgetSyncService.iOSWidgetKind`.
//
// When the user hides task text or turns on App Lock, the app sends counts
// with an empty `topTasks`, and this shows counts only. Wording is in
// en.lproj / km.lproj Localizable.strings.

private let appGroup = "group.dev.romlerk.app"
private let payloadKey = "today_payload"

struct TodayEntry: TimelineEntry {
  let date: Date
  let overdueCount: Int
  let todayCount: Int
  /// Nil when there is nothing due, or when titles are hidden.
  let topTitle: String?
}

struct TodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayEntry {
    TodayEntry(date: Date(), overdueCount: 1, todayCount: 3, topTitle: "Call David")
  }

  func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : readPayload())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
    // The app pushes a reload whenever tasks change; the hourly refresh only
    // keeps "overdue" honest as the day moves on.
    let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    completion(Timeline(entries: [readPayload()], policy: .after(next)))
  }

  private func readPayload() -> TodayEntry {
    guard
      let raw = UserDefaults(suiteName: appGroup)?.string(forKey: payloadKey),
      let data = raw.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return TodayEntry(date: Date(), overdueCount: 0, todayCount: 0, topTitle: nil)
    }
    let first = (json["topTasks"] as? [[String: Any]])?.first
    return TodayEntry(
      date: Date(),
      overdueCount: json["overdueCount"] as? Int ?? 0,
      todayCount: json["todayCount"] as? Int ?? 0,
      topTitle: first?["title"] as? String
    )
  }
}

struct TodayWidgetView: View {
  var entry: TodayEntry

  private var total: Int { entry.overdueCount + entry.todayCount }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("TODAY")
          .font(.caption2)
          .fontWeight(.bold)
          .foregroundStyle(.secondary)
        Spacer()
        if total > 0 {
          Text("\(total) due")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
      }

      Spacer(minLength: 0)

      Text(headline)
        .font(.headline)
        .lineLimit(2)

      if entry.overdueCount > 0 {
        Text("\(entry.overdueCount) overdue")
          .font(.caption)
          .foregroundStyle(.red)
      } else if total > 0 {
        Text("\(entry.todayCount) left today")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .widgetBackground()
  }

  /// Literal Text("...") strings are looked up in Localizable.strings
  /// automatically; this one is computed, so it is looked up explicitly.
  private var headline: String {
    if total == 0 { return String(localized: "Nothing due today") }
    return entry.topTitle ?? String(localized: "Open Romlerk to see them")
  }
}

private extension View {
  /// iOS 17 requires a container background; earlier versions reject it.
  @ViewBuilder
  func widgetBackground() -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(.fill.tertiary, for: .widget)
    } else {
      padding()
    }
  }
}

struct RomlerkTodayWidget: Widget {
  let kind = "RomlerkTodayWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
      TodayWidgetView(entry: entry)
    }
    .configurationDisplayName("Today")
    .description("What's due today and anything overdue.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
