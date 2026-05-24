import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: StoreManager
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    HStack { Text("Settings").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white); Spacer() }
                        .padding(.horizontal, 20).padding(.top, 60)
                    proCard
                    settingsGroup(title: "General", items: [
                        ("star.fill", Color(hex: "F59E0B"), "Rate SleepAI", "Love it? Leave a review"),
                        ("square.and.arrow.up", Color(hex: "60A5FA"), "Share App", "Tell your friends"),
                    ])
                    settingsGroup(title: "Support", items: [
                        ("questionmark.circle.fill", Color.appAccent, "Help & FAQ", nil),
                        ("envelope.fill", Color(hex: "A78BFA"), "Contact Support", "kouki_1203@icloud.com"),
                        ("arrow.counterclockwise.circle.fill", Color(hex: "38BDF8"), "Restore Purchases", nil),
                    ])
                    settingsGroup(title: "Legal", items: [
                        ("lock.shield.fill", Color(hex: "2ECC71"), "Privacy Policy", nil),
                        ("doc.text.fill", Color.appMuted, "Terms of Use", nil),
                    ])
                    Text("SleepAI v1.0.0\nPowered by Claude AI").font(.system(size: 12)).foregroundStyle(Color.appMuted.opacity(0.5)).multilineTextAlignment(.center).padding(.bottom, 20)
                    Spacer(minLength: 100)
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
    }

    private var proCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack { Circle().fill(Color.appAccent.opacity(0.15)).frame(width: 52, height: 52); Image(systemName: store.isPro ? "crown.fill" : "lock.fill").font(.system(size: 22)).foregroundStyle(Color.appAccent) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.isPro ? "SleepAI Pro" : "Free Plan").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    Text(store.isPro ? "Unlimited tracking & AI analysis" :
                         "\(max(0, StoreManager.freeUsesPerMonth - UserDefaults.standard.integer(forKey: "sleep_tracks"))) free sessions remaining")
                        .font(.system(size: 13)).foregroundStyle(Color.appMuted)
                }
                Spacer()
                if store.isPro { Image(systemName: "checkmark.seal.fill").font(.system(size: 24)).foregroundStyle(Color.appAccent) }
            }
            if !store.isPro {
                Button { Haptics.impact(.medium); showPaywall = true } label: {
                    Text("Upgrade to Pro").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                }.buttonStyle(GradientButtonStyle())
            }
        }
        .padding(18).glassSurface(cornerRadius: 24).padding(.horizontal, 20)
    }

    private func settingsGroup(title: String, items: [(String, Color, String, String?)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.appMuted).padding(.horizontal, 20)
            VStack(spacing: 1) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Button { Haptics.impact(.light) } label: {
                        HStack(spacing: 14) {
                            ZStack { RoundedRectangle(cornerRadius: 9).fill(item.1.opacity(0.15)).frame(width: 36, height: 36); Image(systemName: item.0).font(.system(size: 15, weight: .medium)).foregroundStyle(item.1) }
                            VStack(alignment: .leading, spacing: 2) { Text(item.2).font(.system(size: 15, weight: .medium)).foregroundStyle(.white); if let sub = item.3 { Text(sub).font(.system(size: 12)).foregroundStyle(Color.appMuted) } }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.appMuted)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14).background(Color.appSurface)
                    }.buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appBorder, lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }
}
