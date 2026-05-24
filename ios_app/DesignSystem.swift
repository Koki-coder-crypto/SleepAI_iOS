import SwiftUI
import UIKit

extension Color {
    static let appBG        = Color(hex: "0A0E1A")
    static let appSurface   = Color(white: 1, opacity: 0.05)
    static let appBorder    = Color(white: 1, opacity: 0.08)
    static let appAccent    = Color(hex: "818CF8")   // Indigo
    static let appAccentAlt = Color(hex: "6366F1")
    static let appMuted     = Color(hex: "8B9CB6")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(red: Double((rgb >> 16) & 0xFF)/255, green: Double((rgb >> 8) & 0xFF)/255, blue: Double(rgb & 0xFF)/255)
    }
}

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) { UINotificationFeedbackGenerator().notificationOccurred(type) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

struct GlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
extension View {
    func glassSurface(cornerRadius: CGFloat = 20) -> some View { modifier(GlassSurfaceModifier(cornerRadius: cornerRadius)) }
}

struct GradientButtonStyle: ButtonStyle {
    var colors: [Color] = [Color.appAccent, Color.appAccentAlt]
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .shadow(color: colors[0].opacity(configuration.isPressed ? 0.2 : 0.35), radius: 12, y: 6)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PlanCard: View {
    let title: String; let displayPrice: String; let period: String
    let badge: String?; let badgeColor: Color; let trialNote: String?
    let selected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        if let badge { Text(badge).font(.system(size: 10, weight: .bold)).foregroundStyle(badgeColor).padding(.horizontal, 8).padding(.vertical, 3).background(badgeColor.opacity(0.12), in: Capsule()) }
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(displayPrice).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(selected ? Color.appAccent : .white)
                        Text(period).font(.system(size: 13)).foregroundStyle(Color.appMuted)
                    }
                    if let note = trialNote { Text(note).font(.system(size: 12, weight: .medium)).foregroundStyle(Color(hex: "2ECC71")) }
                }
                Spacer()
                ZStack {
                    Circle().stroke(selected ? Color.appAccent : Color.white.opacity(0.2), lineWidth: 2).frame(width: 22, height: 22)
                    if selected { Circle().fill(Color.appAccent).frame(width: 12, height: 12) }
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(selected ? Color.appAccent.opacity(0.07) : Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Color.appAccent.opacity(0.5) : Color.appBorder, lineWidth: selected ? 1.5 : 1)))
        }
        .buttonStyle(.plain).animation(.spring(response: 0.3, dampingFraction: 0.75), value: selected)
    }
}
