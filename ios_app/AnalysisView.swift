import SwiftUI
import Charts

struct AnalysisView: View {
    @ObservedObject var sleepStore: SleepStore
    @State private var appeared = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; return f
    }()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    if sleepStore.sessions.isEmpty {
                        emptyState
                    } else {
                        statsCards
                        if sleepStore.sessions.count >= 2 { chartSection }
                        latestAnalysis
                        recentSessions
                    }
                    Spacer(minLength: 100)
                }
                .padding(.top, 20)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true } }
    }

    private var headerSection: some View {
        HStack {
            Text("Analysis")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text("\(sleepStore.sessions.count) nights")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.appMuted)
                .padding(.horizontal, 12).padding(.vertical, 6).background(Color.appSurface, in: Capsule())
        }
        .padding(.horizontal, 20)
    }

    private var statsCards: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Avg Duration",
                value: String(format: "%.1fh", sleepStore.averageDuration()),
                icon: "clock.fill",
                color: Color.appAccent,
                subtitle: "7-day avg"
            )
            statCard(
                title: "Avg Quality",
                value: String(format: "%.1f/5", sleepStore.averageQuality()),
                icon: "star.fill",
                color: Color(hex: "F59E0B"),
                subtitle: "7-day avg"
            )
            statCard(
                title: "Nights Tracked",
                value: "\(sleepStore.sessions.count)",
                icon: "moon.stars.fill",
                color: Color(hex: "A78BFA"),
                subtitle: "total"
            )
        }
        .padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
    }

    private func statCard(title: String, value: String, icon: String, color: Color, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(color)
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.appMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassSurface(cornerRadius: 18)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Sleep Duration (7 days)", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appAccent)

            let recent = Array(sleepStore.sessions.prefix(7).reversed())

            Chart {
                ForEach(Array(recent.enumerated()), id: \.offset) { i, session in
                    BarMark(
                        x: .value("Day", dateFormatter.string(from: session.bedtime)),
                        y: .value("Hours", session.durationHours)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [Color.appAccent, Color.appAccentAlt],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(6)

                    RuleMark(y: .value("Ideal", 8.0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color(hex: "34D399").opacity(0.5))
                }
            }
            .frame(height: 160)
            .chartYAxis {
                AxisMarks(values: [4, 6, 8, 10]) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))h").font(.system(size: 10)).foregroundStyle(Color.appMuted)
                        }
                    }
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) { Text(s).font(.system(size: 9)).foregroundStyle(Color.appMuted) }
                    }
                }
            }
        }
        .padding(18).glassSurface(cornerRadius: 20).padding(.horizontal, 20)
        .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)
    }

    private var latestAnalysis: some View {
        Group {
            if let latest = sleepStore.sessions.first, !latest.aiAnalysis.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Last Night's Analysis", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                    Text(latest.aiAnalysis)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18).glassSurface(cornerRadius: 20).padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
            }
        }
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep History").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 20)

            ForEach(Array(sleepStore.sessions.prefix(10).enumerated()), id: \.element.id) { i, session in
                HStack(spacing: 14) {
                    VStack(alignment: .center, spacing: 2) {
                        Text(dateFormatter.string(from: session.bedtime))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 18)).foregroundStyle(Color.appAccent.opacity(0.7))
                    }
                    .frame(width: 60)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(session.durationString).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            Text("\(timeFormatter.string(from: session.bedtime)) – \(timeFormatter.string(from: session.actualWakeTime ?? session.wakeTime))")
                                .font(.system(size: 11)).foregroundStyle(Color.appMuted)
                        }
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { q in
                                Image(systemName: q <= session.quality ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundStyle(q <= session.quality ? Color(hex: "F59E0B") : Color.appMuted.opacity(0.3))
                            }
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .glassSurface(cornerRadius: 16)
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : 20)
                .animation(.easeOut(duration: 0.35).delay(Double(i) * 0.05 + 0.3), value: appeared)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Color.appAccent.opacity(0.08)).frame(width: 100, height: 100)
                Image(systemName: "chart.xyaxis.line").font(.system(size: 40)).foregroundStyle(Color.appAccent.opacity(0.5))
            }
            Text("No data yet").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
            Text("Track your first night of sleep\nto see your analysis here.").font(.system(size: 14)).foregroundStyle(Color.appMuted).multilineTextAlignment(.center)
            Spacer()
        }
    }
}
