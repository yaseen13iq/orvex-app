import WidgetKit
import SwiftUI
import ActivityKit

struct StatusEntry: TimelineEntry { let date: Date; let text: String }

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry { StatusEntry(date: .now, text: "يعمل") }
    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .after(.now.addingTimeInterval(900))))
    }
}

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "status", provider: StatusProvider()) { e in
            Text(e.text).containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("حالة الموقع")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct OrvexLive: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrvexActivityAttributes.self) { ctx in
            Text(ctx.state.title).padding()
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(ctx.state.title) }
                DynamicIslandExpandedRegion(.bottom) {
                    if let e = ctx.state.endsAt { Text(timerInterval: Date.now...e, countsDown: true) }
                }
            } compactLeading: { Image(systemName: "circle.fill") } compactTrailing: { Text("OK") } minimal: { Image(systemName: "circle") }
        }
    }
}

@main
struct OrvexWidgetBundle: WidgetBundle {
    var body: some Widget { StatusWidget(); OrvexLive() }
}
