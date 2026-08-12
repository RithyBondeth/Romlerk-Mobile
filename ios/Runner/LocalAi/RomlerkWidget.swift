import WidgetKit
import SwiftUI

struct RomlerkWidgetEntry: TimelineEntry {
    let date: Date
    let overdueCount: Int
    let todayCount: Int
    let totalCount: Int
    let topTaskTitle: String
}

struct RomlerkWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> RomlerkWidgetEntry {
        RomlerkWidgetEntry(
            date: Date(),
            overdueCount: 1,
            todayCount: 3,
            totalCount: 4,
            topTaskTitle: "Call David"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RomlerkWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RomlerkWidgetEntry>) -> Void) {
        let entry = readSharedPayload()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readSharedPayload() -> RomlerkWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.dev.romlerk.app")
        let overdue = defaults?.integer(forKey: "overdueCount") ?? 0
        let today = defaults?.integer(forKey: "todayCount") ?? 0
        let topTitle = defaults?.string(forKey: "topTaskTitle") ?? "No tasks due today"
        
        return RomlerkWidgetEntry(
            date: Date(),
            overdueCount: overdue,
            todayCount: today,
            totalCount: overdue + today,
            topTaskTitle: topTitle
        )
    }
}

struct RomlerkWidgetView : View {
    var entry: RomlerkWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("ROMLERK")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(entry.totalCount) due")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(4)
            }

            Spacer()

            Text(entry.topTaskTitle)
                .font(.headline)
                .lineLimit(2)

            if entry.overdueCount > 0 {
                Text("\(entry.overdueCount) overdue task\(entry.overdueCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("\(entry.todayCount) remaining today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

@main
struct RomlerkWidget: Widget {
    let kind: String = "RomlerkWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RomlerkWidgetProvider()) { entry in
            RomlerkWidgetView(entry: entry)
        }
        .configurationDisplayName("Romlerk Today")
        .description("Keep track of Today's task commitments.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
