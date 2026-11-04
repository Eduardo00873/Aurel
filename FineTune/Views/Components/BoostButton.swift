// FineTune/Views/Components/BoostButton.swift
import SwiftUI

/// Per-app "Amplify" control shown next to the mute button. Reads "1×" quietly when off
/// and turns into an accent "2×"/"3×"/"4×" pill when the app is amplified, so the boost
/// is always visible and one click away.
struct BoostButton: View {
    let boost: BoostLevel
    let onChange: (BoostLevel) -> Void

    @State private var isHovered = false

    var body: some View {
        Menu {
            Picker("Amplify", selection: Binding(get: { boost }, set: onChange)) {
                ForEach(BoostLevel.allCases, id: \.self) { Text($0.menuTitle).tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            Text(boost.label)
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(boost.isBoosted ? Color.accentColor : labelColor)
                .padding(.horizontal, 5)
                .frame(height: 18)
                .background(Capsule().fill(backgroundColor))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { isHovered = $0 }
        .animation(DesignTokens.Animation.hover, value: isHovered)
        .help(boost.isBoosted ? "Amplified \(boost.label). Click to change." : "Amplify a quiet app above 100%")
        .accessibilityLabel(boost.isBoosted ? "Amplify, \(boost.label)" : "Amplify, off")
    }

    private var labelColor: Color {
        isHovered ? DesignTokens.Palette.textPrimary : DesignTokens.Palette.textSecondary
    }

    private var backgroundColor: Color {
        if boost.isBoosted { return Color.accentColor.opacity(isHovered ? 0.22 : 0.15) }
        return isHovered ? Color.primary.opacity(0.08) : .clear
    }
}
