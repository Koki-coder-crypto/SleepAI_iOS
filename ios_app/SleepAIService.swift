import Foundation

actor SleepAIService {
    static let shared = SleepAIService()
    private let apiKey = Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String ?? ""

    func analyzeSleep(session: SleepSession, recentSessions: [SleepSession]) async throws -> String {
        let avgDuration = recentSessions.isEmpty ? session.durationHours :
            recentSessions.map { $0.durationHours }.reduce(0, +) / Double(recentSessions.count)
        let avgQuality = recentSessions.isEmpty ? Double(session.quality) :
            recentSessions.map { Double($0.quality) }.reduce(0, +) / Double(recentSessions.count)

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let prompt = """
        Analyze this sleep data and provide personalized coaching:

        Last night:
        - Bedtime: \(formatter.string(from: session.bedtime))
        - Wake time: \(formatter.string(from: session.actualWakeTime ?? session.wakeTime))
        - Duration: \(session.durationString)
        - Quality rating: \(session.quality)/5
        - Notes: \(session.notes.isEmpty ? "None" : session.notes)

        7-day averages:
        - Average duration: \(String(format: "%.1f", avgDuration)) hours
        - Average quality: \(String(format: "%.1f", avgQuality))/5

        Provide a concise, personalized sleep analysis (3-4 sentences) including:
        1. Assessment of last night's sleep
        2. One key observation about their patterns
        3. One actionable tip for tonight

        Keep it warm, encouraging, and science-based.
        """

        let body: [String: Any] = [
            "model": "claude-opus-4-5",
            "max_tokens": 500,
            "messages": [["role": "user", "content": prompt]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw AIError.apiError }

        struct AnthropicResponse: Codable {
            struct Content: Codable { let text: String }
            let content: [Content]
        }
        let resp = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return resp.content.first?.text ?? ""
    }

    func getDailyTip(recentSessions: [SleepSession]) async throws -> SleepTip {
        let tips: [SleepTip] = [
            SleepTip(icon: "moon.stars.fill", title: "Consistent Schedule", description: "Go to bed and wake up at the same time every day, even on weekends. This regulates your circadian rhythm.", category: "Routine"),
            SleepTip(icon: "thermometer.medium", title: "Cool Room", description: "Keep your bedroom between 60-67°F (15-19°C). A cooler room helps your core temperature drop for deeper sleep.", category: "Environment"),
            SleepTip(icon: "iphone.slash", title: "Screen-Free Hour", description: "Avoid screens 1 hour before bed. Blue light suppresses melatonin production and delays sleep onset.", category: "Habits"),
            SleepTip(icon: "sun.max.fill", title: "Morning Light", description: "Get bright light exposure within 30 minutes of waking. This anchors your circadian rhythm for the day.", category: "Morning"),
            SleepTip(icon: "cup.and.saucer.fill", title: "Caffeine Cutoff", description: "Stop caffeine 8 hours before bed. Caffeine has a half-life of 5-6 hours and disrupts deep sleep stages.", category: "Diet"),
            SleepTip(icon: "figure.walk", title: "Evening Walk", description: "A 20-minute walk 2 hours before bed can reduce sleep onset time and improve sleep quality.", category: "Exercise"),
            SleepTip(icon: "wind", title: "4-7-8 Breathing", description: "Inhale for 4 counts, hold for 7, exhale for 8. This activates your parasympathetic nervous system.", category: "Relaxation"),
        ]
        let dayIndex = Calendar.current.component(.weekday, from: Date()) - 1
        return tips[dayIndex % tips.count]
    }

    enum AIError: LocalizedError {
        case apiError
        var errorDescription: String? { "AI service unavailable" }
    }
}
