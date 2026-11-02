// FineTune/Views/Settings/Tabs/AppearanceTab.swift
import SwiftUI

@MainActor
struct AppearanceTab: View {
    @Bindable var settings: SettingsManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxl) {
                SettingsSection("Theme") {
                    SettingsRow(
                        "Appearance",
                        description: "Match macOS, or lock to Light or Dark"
                    ) {
                        ThemeTilePicker(selection: $settings.appSettings.appearance)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
    }
}
