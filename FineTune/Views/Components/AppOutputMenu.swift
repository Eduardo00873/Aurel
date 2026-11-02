// FineTune/Views/Components/AppOutputMenu.swift
import SwiftUI

/// Compact native menu for choosing where one app plays: the system default or a specific device.
struct AppOutputMenu: View {
    let devices: [AudioDevice]
    let selectedDeviceUID: String?
    let isFollowingDefault: Bool
    let onSelectFollowDefault: () -> Void
    let onDeviceSelected: (String) -> Void

    @State private var isHovered = false

    private var title: String {
        if isFollowingDefault { return "System Default" }
        return devices.first(where: { $0.uid == selectedDeviceUID })?.name ?? "System Default"
    }

    var body: some View {
        Menu {
            Button {
                onSelectFollowDefault()
            } label: {
                menuLabel("System Default", selected: isFollowingDefault)
            }
            Divider()
            ForEach(devices) { device in
                Button {
                    onDeviceSelected(device.uid)
                } label: {
                    menuLabel(device.name, selected: !isFollowingDefault && device.uid == selectedDeviceUID)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .font(.system(size: 11))
            .foregroundStyle(isHovered ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(maxWidth: 130, alignment: .trailing)
        .onHover { isHovered = $0 }
        .animation(DesignTokens.Animation.hover, value: isHovered)
        .accessibilityLabel("Output: \(title)")
        .help("Choose where this app plays")
    }

    @ViewBuilder
    private func menuLabel(_ text: String, selected: Bool) -> some View {
        if selected {
            Label(text, systemImage: "checkmark")
        } else {
            Text(text)
        }
    }
}
