import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), title: "Romlerk Tasks", countsText: "Loading...")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), title: "Romlerk Tasks", countsText: "Loading...")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        
        let userDefaults = UserDefaults(suiteName: "group.dev.romlerk.app")
        let jsonPayload = userDefaults?.string(forKey: "today_payload")
        
        var titleText = "Romlerk"
        var countsText = "No tasks"
        
        if let payload = jsonPayload, let data = payload.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    let overdue = json["overdueCount"] as? Int ?? 0
                    let today = json["todayCount"] as? Int ?? 0
                    countsText = "\(overdue) overdue, \(today) today"
                    
                    if let topTasks = json["topTasks"] as? [[String: Any]], let firstTask = topTasks.first {
                        titleText = firstTask["title"] as? String ?? titleText
                    }
                }
            } catch {
                // Ignore parse errors
            }
        }
        
        let entry = SimpleEntry(date: Date(), title: titleText, countsText: countsText)
        entries.append(entry)

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let title: String
    let countsText: String
}

struct RomlerkWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(entry.countsText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

@main
struct RomlerkWidget: Widget {
    let kind: String = "RomlerkTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            RomlerkWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Romlerk Today")
        .description("View your top tasks for today.")
    }
}
