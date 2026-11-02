// FineTune/Views/Components/AppOutputMenu.swift
import AppKit
import SwiftUI

/// Compact native menu for choosing where one app plays: the system output (default)
/// or a specific device. A specific device is shown with a small pin so a custom
/// route is distinguishable from "System Default" at a glance.
///
/// The menu is presented only after a completed click on the label. A SwiftUI `Menu`
/// opens on mouse-down and selects on mouse-up, so a press-drag-release could pin an
/// app to a device by accident; opening the `NSMenu` after the click has finished puts
/// it in click-to-select mode, where only an explicit click on an item runs an action.
struct AppOutputMenu: View {
    let devices: [AudioDevice]
    let selectedDeviceUID: String?
    let isFollowingDefault: Bool
    /// Name of the current system output, shown next to "System Default" in the menu.
    let systemOutputName: String?
    let onSelectFollowDefault: () -> Void
    let onDeviceSelected: (String) -> Void

    @State private var isHovered = false
    @State private var anchor = MenuAnchor()

    private var isCustom: Bool { !isFollowingDefault }

    /// Name of the pinned device; a pinned device that is currently disconnected stays visible as such.
    private var customName: String? {
        guard isCustom else { return nil }
        return devices.first(where: { $0.uid == selectedDeviceUID })?.name ?? "Unavailable Device"
    }

    var body: some View {
        Button {
            presentMenu()
        } label: {
            HStack(spacing: 3) {
                if isCustom {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                Text(customName ?? "System Default")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .font(.system(size: 11))
            .foregroundStyle(labelColor)
            .contentShape(Rectangle())
            .background(MenuAnchorView(anchor: anchor))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .frame(maxWidth: 130, alignment: .trailing)
        .onHover { isHovered = $0 }
        .animation(DesignTokens.Animation.hover, value: isHovered)
        .accessibilityLabel(customName.map { "Output: only on \($0)" } ?? "Output: System Default")
        .help(customName.map { "Plays only on \($0). Choose System Default to follow the system output." }
              ?? "Follows the system output")
    }

    private func presentMenu() {
        let menu = AppOutputMenuBuilder.makeMenu(
            devices: devices,
            selectedDeviceUID: selectedDeviceUID,
            isFollowingDefault: isFollowingDefault,
            systemOutputName: systemOutputName,
            onSelectFollowDefault: onSelectFollowDefault,
            onDeviceSelected: onDeviceSelected
        )
        guard let view = anchor.view else { return }
        // Top-left of the menu just below the label (the anchor view is not flipped).
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -2), in: view)
    }

    /// Custom routes read in primary text so they stand apart from the quieter default.
    private var labelColor: Color {
        if isHovered || isCustom { return DesignTokens.Colors.textPrimary }
        return DesignTokens.Colors.textSecondary
    }
}

// MARK: - Menu Construction

/// Builds the per-app output `NSMenu`. Building has no side effects; an action runs
/// only when AppKit performs an item's action after the user clicks it.
enum AppOutputMenuBuilder {
    static let followSectionTitle = "Follow System Output"
    static let devicesSectionTitle = "Play Only On"

    static func makeMenu(
        devices: [AudioDevice],
        selectedDeviceUID: String?,
        isFollowingDefault: Bool,
        systemOutputName: String?,
        onSelectFollowDefault: @escaping () -> Void,
        onDeviceSelected: @escaping (String) -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(.sectionHeader(title: followSectionTitle))
        menu.addItem(ActionMenuItem(
            title: systemDefaultTitle(systemOutputName: systemOutputName),
            isSelected: isFollowingDefault,
            action: onSelectFollowDefault
        ))

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: devicesSectionTitle))
        for device in devices {
            let uid = device.uid
            menu.addItem(ActionMenuItem(
                title: device.name,
                isSelected: !isFollowingDefault && uid == selectedDeviceUID,
                action: { onDeviceSelected(uid) }
            ))
        }
        return menu
    }

    static func systemDefaultTitle(systemOutputName: String?) -> String {
        guard let systemOutputName else { return "System Default" }
        return "System Default (\(systemOutputName))"
    }
}

/// Menu item that runs a closure when AppKit performs its action. The selected item
/// carries a checkmark image, matching how SwiftUI renders `Label(_, systemImage: "checkmark")`.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, isSelected: Bool, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(performHandler), keyEquivalent: "")
        target = self
        isEnabled = true
        if isSelected {
            image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func performHandler() {
        handler()
    }
}

// MARK: - Anchor

/// Holds the AppKit view the menu is positioned against.
@MainActor
final class MenuAnchor {
    weak var view: NSView?
}

/// Invisible view placed behind the label so the menu can open directly below it.
private struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        anchor.view = nsView
    }
}
