// FineTune/Views/Components/OutputDeviceList.swift
import AudioToolbox
import SwiftUI

/// Compact list of output devices. Clicking a row makes it the system default output.
struct OutputDeviceList: View {
    let devices: [AudioDevice]
    let defaultDeviceID: AudioDeviceID
    let iconOverride: (String) -> String?
    let focusedUID: String?
    let onSelect: (AudioDevice) -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            ForEach(devices) { device in
                OutputDeviceRow(
                    device: device,
                    icon: DeviceIconResolver.displayIcon(
                        overrideSymbol: iconOverride(device.uid),
                        automatic: device.icon,
                        deviceName: device.name
                    ),
                    isSelected: device.id == defaultDeviceID,
                    isFocused: focusedUID == device.uid,
                    onSelect: { onSelect(device) }
                )
                .id(PopupKeyboardNavModel.RowID.device(uid: device.uid))
            }
        }
    }
}

private struct OutputDeviceRow: View {
    let device: AudioDevice
    let icon: NSImage?
    let isSelected: Bool
    let isFocused: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                DeviceBadge(icon: icon, isSelected: isSelected)
                Text(device.name)
                    .font(isSelected ? DesignTokens.Typography.itemName : DesignTokens.Typography.rowName)
                    .foregroundStyle(DesignTokens.Palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DesignTokens.Palette.accent)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PopupRowButtonStyle(isFocused: isFocused))
        .accessibilityLabel(device.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .help(isSelected ? "Current system output" : "Use \(device.name) as the system output")
    }
}

/// Plain row button with the popup's hover / pressed / focused treatment.
struct PopupRowButtonStyle: ButtonStyle {
    var isFocused: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        PopupRowButtonBody(configuration: configuration, isFocused: isFocused)
    }
}

private struct PopupRowButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                    .fill(isHovered || isFocused ? DesignTokens.Colors.hoverSurface : .clear)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : DesignTokens.Animation.hover, value: isHovered)
            .animation(reduceMotion ? nil : DesignTokens.Animation.quick, value: configuration.isPressed)
    }
}
