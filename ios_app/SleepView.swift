import SwiftUI
import UserNotifications

struct SleepView: View {
    @EnvironmentObject var store: StoreManager
    @ObservedObject var sleepStore: SleepStore
    @State private var ambientPhase = false
    @State private var bedtime = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date().addingTimeInterval(86400)) ?? Date()
    @State private var showingWakeModal = false
    @State private var sleepQuality: Int = 3
    @State private var sleepNotes = ""
    @State private var isAnalyzing = false
    @State private var dailyTip: SleepTip?
    @State private var showPaywall = false
    @State private var orbPulse = false
    @State private var starsOffset: [CGPoint] = []
    @State private var appeared = false
    @State private var moonScale: CGFloat = 1.0

    // Timer for star animation when tracking
    @State private var starTimer: Timer?
    @State private var animatingStars: [AnimatingStar] = []

    struct AnimatingStar: Identifiable {
        let id = UUID()
        var x: CGFloat; var y: CGFloat; var opacity: Double; var size: CGFloat
    }

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            backgroundGlow

            // Floating stars
            ForEach(animatingStars) { star in
                Image(systemName: "star.fill")
                    .font(.system(size: star.size))
                    .foregroundStyle(Color.appAccent.opacity(star.opacity))
                    .position(x: star.x, y: star.y)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection
                    moonOrbSection
                    if !sleepStore.isTrackingActive {
                        timePickerSection
                        dailyTipSection
                    } else {
                        trackingActiveSection
                    }
                    Spacer(minLength: 100)
                }
                .padding(.top, 20)
            }
        }
        .sheet(isPresented: $showingWakeModal) { wakeUpSheet }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
        .onAppear { ambientPhase = true;
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) { orbPulse = true }
            Task { dailyTip = try? await SleepAIService.shared.getDailyTip(recentSessions: sleepStore.sessions) }
            if sleepStore.isTrackingActive { startStarAnimation() }
        }
        .onDisappear { starTimer?.invalidate() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("SleepAI")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "B0BDD4")], startPoint: .top, endPoint: .bottom))
            Text("Sleep smarter. Wake refreshed.")
                .font(.system(size: 15)).foregroundStyle(Color.appMuted)
        }
    }

    private var moonOrbSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer atmosphere
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.appAccent.opacity(0.15), Color.clear],
                            center: .center, startRadius: 60, endRadius: 130
                        )
                    )
                    .frame(width: 260, height: 260)
                    .scaleEffect(orbPulse ? 1.12 : 1.0)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: orbPulse)

                // Ring 2
                Circle()
                    .stroke(Color.appAccent.opacity(0.1), lineWidth: 1)
                    .frame(width: 200, height: 200)
                    .scaleEffect(orbPulse ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: orbPulse)

                // Main orb
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.appAccent.opacity(sleepStore.isTrackingActive ? 0.4 : 0.2),
                                    Color.appAccentAlt.opacity(0.1)
                                ],
                                center: .topLeading, startRadius: 20, endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(colors: [Color.appAccent.opacity(0.6), Color.appAccent.opacity(0.1)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1.5
                                )
                        )

                    if sleepStore.isTrackingActive {
                        // Active tracking state
                        VStack(spacing: 6) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(LinearGradient(colors: [Color.appAccent, Color(hex: "C4B5FD")],
                                                                startPoint: .top, endPoint: .bottom))
                                .shadow(color: Color.appAccent.opacity(0.5), radius: 12)
                            if let start = sleepStore.trackingStartTime {
                                Text(formatTrackingDuration(since: start))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                    } else {
                        // Idle state
                        VStack(spacing: 6) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(LinearGradient(colors: [Color.appAccent, Color(hex: "C4B5FD")],
                                                                startPoint: .top, endPoint: .bottom))
                                .shadow(color: Color.appAccent.opacity(0.4), radius: 10)
                            Text("Sleep")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                }
                .scaleEffect(moonScale)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: moonScale)
            }
            .frame(height: 260)
            .onTapGesture {
                moonScale = 0.93
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { moonScale = 1.0 }
                Haptics.impact(.medium)
                if sleepStore.isTrackingActive {
                    showingWakeModal = true
                } else {
                    startSleepTracking()
                }
            }

            // Status label
            Text(sleepStore.isTrackingActive ? "Tap to wake up" : "Tap to start sleep tracking")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.appMuted)
        }
    }

    private var timePickerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                timePickerCard(title: "Bedtime", systemImage: "moon.fill", time: $bedtime,
                               color: Color.appAccent)
                timePickerCard(title: "Wake Up", systemImage: "sun.max.fill", time: $wakeTime,
                               color: Color(hex: "F59E0B"))
            }
            .padding(.horizontal, 20)

            // Sleep duration preview
            let duration = wakeTime.timeIntervalSince(bedtime) / 3600
            let clampedDuration = duration < 0 ? duration + 24 : duration
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(clampedDuration >= 7 && clampedDuration <= 9 ? Color(hex: "34D399") : Color(hex: "F59E0B"))
                Text(String(format: "%.1f hours sleep", clampedDuration))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                if clampedDuration < 7 {
                    Text("(too little)").font(.system(size: 12)).foregroundStyle(Color(hex: "F87171"))
                } else if clampedDuration > 9 {
                    Text("(too much)").font(.system(size: 12)).foregroundStyle(Color(hex: "F59E0B"))
                } else {
                    Text("(optimal)").font(.system(size: 12)).foregroundStyle(Color(hex: "34D399"))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func timePickerCard(title: String, systemImage: String, time: Binding<Date>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(color)
                .colorScheme(.dark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassSurface(cornerRadius: 16)
    }

    private var trackingActiveSection: some View {
        VStack(spacing: 16) {
            if let start = sleepStore.trackingStartTime {
                VStack(spacing: 8) {
                    Label("Sleep started at \(formattedTime(start))", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "34D399"))
                    Text("Your sleep is being tracked. Stars will guide you through the night.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .glassSurface(cornerRadius: 18)
                .padding(.horizontal, 20)
            }

            Button {
                Haptics.impact(.medium); showingWakeModal = true
            } label: {
                Label("Wake Up", systemImage: "sun.max.fill")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .buttonStyle(GradientButtonStyle(colors: [Color(hex: "F59E0B"), Color(hex: "D97706")]))
            .padding(.horizontal, 20)
        }
    }

    private var dailyTipSection: some View {
        Group {
            if let tip = dailyTip {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.appAccent.opacity(0.15)).frame(width: 40, height: 40)
                            Image(systemName: tip.icon).font(.system(size: 17)).foregroundStyle(Color.appAccent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tip.category).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.appAccent)
                            Text(tip.title).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        }
                    }
                    Text(tip.description)
                        .font(.system(size: 14)).foregroundStyle(Color(white: 0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .glassSurface(cornerRadius: 20)
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)
            }
        }
    }

    private var wakeUpSheet: some View {
        NavigationStack {
            ZStack {
                Color.appBG.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Text("How did you sleep?")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.top, 20)

                        // Quality selector
                        VStack(spacing: 12) {
                            Text("Sleep Quality")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.appMuted)
                            HStack(spacing: 16) {
                                ForEach(1...5, id: \.self) { q in
                                    Button {
                                        Haptics.selection()
                                        withAnimation(.spring(response: 0.3)) { sleepQuality = q }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: qualityIcon(q))
                                                .font(.system(size: 24))
                                                .foregroundStyle(sleepQuality >= q ? Color.appAccent : Color.appMuted)
                                                .scaleEffect(sleepQuality == q ? 1.2 : 1.0)
                                            Text(qualityLabel(q))
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(sleepQuality == q ? Color.appAccent : Color.appMuted)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: sleepQuality)
                                }
                            }
                        }
                        .padding(18).glassSurface(cornerRadius: 20)

                        // Notes
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Notes (optional)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.appMuted)
                            TextField("Dreams, disturbances, how you feel...", text: $sleepNotes, axis: .vertical)
                                .font(.system(size: 14)).foregroundStyle(.white).tint(Color.appAccent)
                                .padding(14).glassSurface(cornerRadius: 16)
                                .lineLimit(3...6)
                        }

                        Button { Task { await recordWakeUp() } } label: {
                            HStack(spacing: 8) {
                                if isAnalyzing { ProgressView().tint(.white) }
                                else { Label("Get AI Analysis", systemImage: "sparkles").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white) }
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                        }
                        .buttonStyle(GradientButtonStyle()).disabled(isAnalyzing)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { recordWakeUpWithoutAnalysis() }.foregroundStyle(Color.appMuted)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var backgroundGlow: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            Ellipse()
                .fill(Color.appAccent.opacity(0.16))
                .frame(width: 380, height: 280).blur(radius: 80)
                .offset(x: 60, y: -200).offset(y: ambientPhase ? 22 : -22)
                .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: ambientPhase)
            Ellipse()
                .fill(Color(hex: "4F46E5").opacity(0.08))
                .frame(width: 320, height: 220).blur(radius: 70)
                .offset(x: -80, y: 120).offset(x: ambientPhase ? 18 : -18)
                .animation(.easeInOut(duration: 7.5).repeatForever(autoreverses: true), value: ambientPhase)
            Ellipse()
                .fill(Color.appAccent.opacity(0.16).opacity(0.06))
                .frame(width: 220, height: 160).blur(radius: 60)
                .offset(x: 20, y: 340).scaleEffect(ambientPhase ? 1.25 : 1.0)
                .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true), value: ambientPhase)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Logic

    private func startSleepTracking() {
        if !store.isPro {
            let uses = UserDefaults.standard.integer(forKey: "sleep_tracks")
            if uses >= StoreManager.freeUsesPerMonth { showPaywall = true; return }
        }
        sleepStore.startTracking(bedtime: bedtime)
        startStarAnimation()
        Haptics.notification(.success)
    }

    private func startStarAnimation() {
        starTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                let newStar = AnimatingStar(
                    x: CGFloat.random(in: 20...370),
                    y: CGFloat.random(in: 50...700),
                    opacity: Double.random(in: 0.2...0.6),
                    size: CGFloat.random(in: 4...10)
                )
                withAnimation(.easeIn(duration: 0.5)) { animatingStars.append(newStar) }
                if animatingStars.count > 20 {
                    withAnimation(.easeOut(duration: 1.0)) { animatingStars.removeFirst() }
                }
            }
        }
    }

    private func recordWakeUp() async {
        guard let bedStart = sleepStore.trackingStartTime else { return }
        isAnalyzing = true
        let wakeNow = Date()
        var session = SleepSession(bedtime: bedStart, wakeTime: wakeTime, actualWakeTime: wakeNow,
                                   quality: sleepQuality, aiAnalysis: "", notes: sleepNotes, createdAt: Date())

        do {
            let analysis = try await SleepAIService.shared.analyzeSleep(session: session, recentSessions: Array(sleepStore.sessions.prefix(7)))
            session.aiAnalysis = analysis
        } catch {
            session.aiAnalysis = "Great job tracking your sleep! Consistency is the key to better sleep quality."
        }

        let uses = UserDefaults.standard.integer(forKey: "sleep_tracks")
        UserDefaults.standard.set(uses + 1, forKey: "sleep_tracks")

        sleepStore.addSession(session)
        sleepStore.stopTracking()
        starTimer?.invalidate(); animatingStars = []
        isAnalyzing = false
        showingWakeModal = false
        Haptics.notification(.success)
    }

    private func recordWakeUpWithoutAnalysis() {
        guard let bedStart = sleepStore.trackingStartTime else { sleepStore.stopTracking(); showingWakeModal = false; return }
        let session = SleepSession(bedtime: bedStart, wakeTime: wakeTime, actualWakeTime: Date(),
                                   quality: sleepQuality, aiAnalysis: "", notes: sleepNotes, createdAt: Date())
        sleepStore.addSession(session)
        sleepStore.stopTracking()
        starTimer?.invalidate(); animatingStars = []
        showingWakeModal = false
    }

    private func formatTrackingDuration(since start: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(start))
        let h = elapsed / 3600; let m = (elapsed % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
    }

    private func qualityIcon(_ q: Int) -> String {
        switch q { case 1: return "face.dashed"; case 2: return "face.smiling"; case 3: return "star"; case 4: return "star.fill"; default: return "sparkles" }
    }

    private func qualityLabel(_ q: Int) -> String {
        switch q { case 1: return "Awful"; case 2: return "Poor"; case 3: return "OK"; case 4: return "Good"; default: return "Great" }
    }
}
