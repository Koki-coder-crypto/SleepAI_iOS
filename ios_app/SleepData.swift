import Foundation

struct SleepSession: Identifiable, Codable {
    var id = UUID()
    let bedtime: Date
    let wakeTime: Date
    var actualWakeTime: Date?
    var quality: Int  // 1-5
    var aiAnalysis: String
    var notes: String
    let createdAt: Date

    var durationHours: Double {
        let end = actualWakeTime ?? wakeTime
        return end.timeIntervalSince(bedtime) / 3600
    }

    var durationString: String {
        let h = Int(durationHours)
        let m = Int((durationHours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }

    enum CodingKeys: String, CodingKey {
        case id, bedtime, wakeTime, actualWakeTime, quality, aiAnalysis, notes, createdAt
    }
}

struct SleepTip: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let category: String
}

class SleepStore: ObservableObject {
    @Published var sessions: [SleepSession] = []
    @Published var isTrackingActive = false
    @Published var trackingStartTime: Date?

    private let saveKey = "sleep_sessions_v1"

    init() { load() }

    func startTracking(bedtime: Date) {
        isTrackingActive = true; trackingStartTime = bedtime
        UserDefaults.standard.set(bedtime.timeIntervalSince1970, forKey: "tracking_bedtime")
    }

    func stopTracking() {
        isTrackingActive = false; trackingStartTime = nil
        UserDefaults.standard.removeObject(forKey: "tracking_bedtime")
    }

    func addSession(_ session: SleepSession) {
        sessions.insert(session, at: 0)
        if sessions.count > 365 { sessions = Array(sessions.prefix(365)) }
        save()
    }

    func averageDuration(last n: Int = 7) -> Double {
        let recent = Array(sessions.prefix(n))
        guard !recent.isEmpty else { return 0 }
        return recent.map { $0.durationHours }.reduce(0, +) / Double(recent.count)
    }

    func averageQuality(last n: Int = 7) -> Double {
        let recent = Array(sessions.prefix(n))
        guard !recent.isEmpty else { return 0 }
        return recent.map { Double($0.quality) }.reduce(0, +) / Double(recent.count)
    }

    private func save() { if let d = try? JSONEncoder().encode(sessions) { UserDefaults.standard.set(d, forKey: saveKey) } }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: saveKey), let v = try? JSONDecoder().decode([SleepSession].self, from: d) { sessions = v }
        // Restore active tracking
        if let t = UserDefaults.standard.object(forKey: "tracking_bedtime") as? TimeInterval {
            isTrackingActive = true; trackingStartTime = Date(timeIntervalSince1970: t)
        }
    }
}
