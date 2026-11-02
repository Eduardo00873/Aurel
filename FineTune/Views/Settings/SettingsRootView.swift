// FineTune/Views/Settings/SettingsRootView.swift
import SwiftUI

@MainActor
struct SettingsRootView: View {
    @Bindable var settings: SettingsManager
    @Bindable var audioEngine: AudioEngine
    @Bindable var deviceVolumeMonitor: DeviceVolumeMonitor
    @Bindable var accessibility: AccessibilityPermissionService
    @Bindable var mediaKeyStatus: MediaKeyStatus
    let mediaKeyMonitor: MediaKeyMonitor
    let shortcutsRegistry: ShortcutsRegistry
    @ObservedObject var updateManager: UpdateManager

    // Updates is not listed: Sparkle is disabled (no feed configured).
    enum Section: String, Hashable, CaseIterable, Identifiable {
        case general, audio, shortcuts, appearance, about
        var id: Self { self }

        var title: String {
            switch self {
            case .general: "General"
            case .audio: "Audio"
            case .shortcuts: "Shortcuts"
            case .appearance: "Appearance"
            case .about: "About"
            }
        }

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .audio: "speaker.wave.2"
            case .shortcuts: "command"
            case .appearance: "paintbrush"
            case .about: "info.circle"
            }
        }
    }

    /// Kept while the window stays open; the window starts on General.
    @State private var selection: Section? = .general
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var current: Section { selection ?? .general }

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selection)
                .frame(width: 180)

            Rectangle()
                .fill(DesignTokens.Palette.border)
                .frame(width: 0.5)

            VStack(alignment: .leading, spacing: 0) {
                Text(current.title)
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(DesignTokens.Palette.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    .padding(.top, DesignTokens.Spacing.xl)
                    .accessibilityAddTraits(.isHeader)

                content(for: current)
                    .id(current)
                    .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DesignTokens.Palette.background)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: current)
        }
        .frame(width: 760, height: 540)
        .preferredColorScheme(settings.appSettings.appearance.swiftUIColorScheme)
        .background(WindowAppearanceBridge(appearance: settings.appSettings.appearance.nsAppearance))
        .background(WindowTitleBridge(title: "Aurel Settings"))
    }

    @ViewBuilder
    private func content(for section: Section) -> some View {
        switch section {
        case .general:
            GeneralTab(
                settings: settings,
                onResetAll: {
                    audioEngine.handleSettingsReset()
                    deviceVolumeMonitor.setSystemFollowDefault()
                }
            )
        case .audio:
            AudioTab(
                settings: settings,
                audioEngine: audioEngine,
                deviceVolumeMonitor: deviceVolumeMonitor
            )
        case .shortcuts:
            ShortcutsTab(
                settings: settings,
                accessibility: accessibility,
                mediaKeyStatus: mediaKeyStatus,
                mediaKeyMonitor: mediaKeyMonitor,
                shortcutsRegistry: shortcutsRegistry
            )
        case .appearance:
            AppearanceTab(settings: settings)
        case .about:
            AboutTab()
        }
    }
}

/// Sidebar navigation: SF Symbol + short label, subtle selected and hover backgrounds.
struct SettingsSidebar: View {
    @Binding var selection: SettingsRootView.Section?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            ForEach(SettingsRootView.Section.allCases) { section in
                SettingsSidebarItem(section: section, isSelected: (selection ?? .general) == section) {
                    selection = section
                }
            }
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.top, DesignTokens.Spacing.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DesignTokens.Palette.surface)
    }
}

private struct SettingsSidebarItem: View {
    let section: SettingsRootView.Section
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: section.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? DesignTokens.Palette.accent : DesignTokens.Palette.textSecondary)
                    .frame(width: 20)
                Text(section.title)
                    .font(isSelected ? DesignTokens.Typography.itemName : DesignTokens.Typography.rowName)
                    .foregroundStyle(DesignTokens.Palette.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                    .fill(background)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isHovered)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var background: Color {
        if isSelected { return DesignTokens.Palette.accent.opacity(0.16) }
        if isHovered { return DesignTokens.Colors.hoverSurface }
        return .clear
    }
}
