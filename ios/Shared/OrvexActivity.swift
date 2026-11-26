import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// بيانات الجزيرة التفاعلية (Live Activity)
struct OrvexActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var kind: String          // status | task | alert
        var title: String
        var detail: String
        var level: String         // ok | warn | bad | info
        var endsAt: Date?
        var startedAt: Date?
        var progress: Double?
        var live: Int?
    }
    var topic: String
}
#endif
