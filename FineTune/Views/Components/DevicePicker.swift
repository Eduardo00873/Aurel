// FineTune/Views/Components/DevicePicker.swift
import SwiftUI

/// A styled device picker dropdown with a "System Audio" option (follows the macOS default).
struct DevicePicker: View {
    let devices: [AudioDevice]
    var deviceIconOverrides: [String: String] = [:]
    let selectedDeviceUID: String
    let isFollowingDefault: Bool
    let defaultDeviceUID: String?
    var triggerWidth: CGFloat = 105
    let onDeviceSelected: (String) -> Void
    let onSelectFollowDefault: () -> Void

    @State private var isExpanded = false
    @State private var isButtonHovered = false

    @Environment(\.appearancePreference) private var appearancePreference

    // Configuration
    private let popoverWidth: CGFloat = 210
    private let itemSpacing: CGFloat = 2
    private let cornerRadius: CGFloat = 8

    /// Menu item representation for unified dropdown
    enum MenuItem: Identifiable, Equatable {
        case systemAudio
        case device(AudioDevice)

        var id: String {
            switch self {
            case .systemAudio: return "__system_audio__"
            case .device(let device): return device.uid
            }
        }

        var name: String {
            switch self {
            case .systemAudio: return "System Audio"
            case .device(let device): return device.name
            }
        }
    }

    private var menuItems: [MenuItem] {
        [.systemAudio] + devices.map { .device($0) }
    }

    /// Display text for trigger button
    private var triggerText: String {
        if isFollowingDefault {
            return "System Audio"
        } else if let device = devices.first(where: { $0.uid == selectedDeviceUID }) {
            return device.name
        }
        return "Select"
    }

    private func displayIcon(for device: AudioDevice) -> NSImage? {
        DeviceIconResolver.displayIcon(
            overrideSymbol: deviceIconOverrides[device.uid],
            automatic: device.icon,
            deviceName: device.name
        )
    }

    @ViewBuilder
    private var triggerIcon: some View {
        if isFollowingDefault {
            Image(systemName: "globe")
                .font(.system(size: 15))
                .symbolRenderingMode(.hierarchical)
        } else if let device = devices.first(where: { $0.uid == selectedDeviceUID }),
                  let icon = displayIcon(for: device) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 15))
                .symbolRenderingMode(.hierarchical)
        }
    }

    // MARK: - Body

    var body: some View {
        triggerButton
            .background(
                PopoverHost(
                    isPresented: $isExpanded,
                    preferredColorScheme: appearancePreference.swiftUIColorScheme,
                    nsAppearance: appearancePreference.nsAppearance
                ) {
                    dropdownContent
                }
            )
    }

    // MARK: - Trigger Button

    /// Bordered material pill with icon + text + chevron.
    private var triggerButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    triggerIcon
                    Text(triggerText)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
                    .animation(.easeInOut(duration: 0.25), value: isExpanded)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 4)
            .frame(width: triggerWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius)
                .fill(.regularMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Dimensions.buttonRadius)
                .strokeBorder(
                    isButtonHovered ? DesignTokens.Colors.glassRowBorderHover : DesignTokens.Colors.glassRowBorder,
                    lineWidth: 0.5
                )
        }
        .onHover { isButtonHovered = $0 }
        .animation(DesignTokens.Animation.hover, value: isButtonHovered)
    }

    // MARK: - Dropdown Content

    private var dropdownContent: some View {
        VStack(spacing: 0) {
            // Device list
            ScrollView(.vertical) {
                LazyVStack(spacing: itemSpacing) {
                    ForEach(menuItems) { item in
                        deviceRow(for: item)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 5)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 220)
        }
        .frame(width: popoverWidth)
        .background(
            VisualEffectBackground(material: .menu, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(DesignTokens.Colors.glassBorder, lineWidth: 0.5)
        }
    }

    // MARK: - Device Row

    @ViewBuilder
    private func deviceRow(for item: MenuItem) -> some View {
        let isSelected = isItemSelected(item)

        DevicePickerRow(
            item: item,
            resolvedIcon: {
                if case .device(let device) = item {
                    return displayIcon(for: device)
                }
                return nil
            }(),
            isSelected: isSelected,
            isDefaultDevice: {
                if case .device(let device) = item {
                    return device.uid == defaultDeviceUID
                }
                return false
            }(),
            onTap: {
                handleItemTap(item)
            }
        )
    }

    private func isItemSelected(_ item: MenuItem) -> Bool {
        switch item {
        case .systemAudio:
            return isFollowingDefault
        case .device(let device):
            return !isFollowingDefault && device.uid == selectedDeviceUID
        }
    }

    private func handleItemTap(_ item: MenuItem) {
        switch item {
        case .systemAudio:
            onSelectFollowDefault()
        case .device(let device):
            onDeviceSelected(device.uid)
        }
        withAnimation(.easeOut(duration: 0.15)) {
            isExpanded = false
        }
    }
}

// MARK: - Device Picker Row

private struct DevicePickerRow: View {
    let item: DevicePicker.MenuItem
    let resolvedIcon: NSImage?
    let isSelected: Bool
    let isDefaultDevice: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                // Selection indicator
                selectionIndicator

                // Icon
                itemIcon

                // Text content
                itemText

                Spacer()

                // Default device star
                if isDefaultDevice {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .whenHovered { isHovered = $0 }
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.accentPrimary)
                .frame(width: 16)
        } else {
            Spacer()
                .frame(width: 16)
        }
    }

    @ViewBuilder
    private var itemIcon: some View {
        switch item {
        case .systemAudio:
            Image(systemName: "globe")
                .font(.system(size: 13))
                .frame(width: 16)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        case .device:
            if let icon = resolvedIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 13))
                    .frame(width: 16)
            }
        }
    }

    @ViewBuilder
    private var itemText: some View {
        switch item {
        case .systemAudio:
            VStack(alignment: .leading, spacing: 1) {
                Text("System Audio")
                Text("Follows macOS default")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
        case .device(let device):
            Text(device.name)
                .lineLimit(1)
        }
    }
}

// MARK: - Previews

#Preview("Device Picker") {
    ComponentPreviewContainer {
        DevicePicker(
            devices: MockData.sampleDevices,
            selectedDeviceUID: MockData.sampleDevices[0].uid,
            isFollowingDefault: true,
            defaultDeviceUID: MockData.sampleDevices[0].uid,
            onDeviceSelected: { _ in },
            onSelectFollowDefault: {}
        )
    }
}
