// FineTune/Views/MenuBarPopupView.swift
import AudioToolbox
import SwiftUI

struct MenuBarPopupView: View {
    @Bindable var audioEngine: AudioEngine
    @Bindable var deviceVolumeMonitor: DeviceVolumeMonitor
    @ObservedObject var updateManager: UpdateManager

    /// Audio recording permission (gates the app list)
    let permission: AudioRecordingPermission

    /// Accessibility permission service (media-key status)
    @Bindable var accessibility: AccessibilityPermissionService

    /// Media-key subsystem status
    @Bindable var mediaKeyStatus: MediaKeyStatus

    /// Popup visibility — suppresses the HUD while the popup is open
    @Bindable var popupVisibility: PopupVisibilityService

    let hudController: HUDWindowController

    let mediaKeyMonitor: MediaKeyMonitor

    /// Memoized sorted output devices (priority order, hidden devices filtered)
    @State private var sortedDevices: [AudioDevice] = []

    /// Whether the popup window is key (gates per-row work)
    @State private var isPopupVisible = true

    /// Whether the hidden (ignored) apps list is expanded
    @State private var showsHiddenApps = false

    @State private var navModel = PopupKeyboardNavModel()
    /// Logical keyboard-nav selection. Plain @State (not @FocusState) so reads
    /// and writes are synchronous within a single event handler — using
    /// @FocusState here raced with SwiftUI's auto-focus-on-key-window claim.
    /// A single focusable anchor on the popup body root receives key events;
    /// rows render their selection state purely from this @State value.
    @State private var selectedRow: PopupKeyboardNavModel.RowID? = nil
    /// True once the user presses any nav-vocabulary key. Gates the row-highlight
    /// visual so a fresh popup opens clean even though `selectedRow` may be set.
    @State private var hasKeyboardEngaged: Bool = false
    /// `.onKeyPress` only fires when the modifier-owning view (or a focused
    /// descendant) has focus, so the body root holds a focus anchor.
    @FocusState private var anchorFocused: Bool
    /// Owns keyboard percentage entry (buffer + commit/restore signals), broadcast to
    /// rows via the environment. First responder stays on the nav anchor throughout.
    @State private var textEntry = PopupTextEntryCoordinator()

    @Environment(\.openSettings) private var openSettings

    // MARK: - Layout

    private static let popupWidth: CGFloat = 320
    private static let contentPadding: CGFloat = DesignTokens.Spacing.md

    /// Height ceiling from the user's popup-size preference (width is fixed).
    private var maxContentHeight: CGFloat {
        audioEngine.settingsManager.appSettings.popupSize.dimensions.maxContentHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    mainContent
                }
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: maxContentHeight)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: selectedRow) { _, newFocus in
                    guard let newFocus else { return }
                    withAnimation(DesignTokens.Animation.hover) {
                        proxy.scrollTo(newFocus, anchor: .center)
                    }
                }
            }

            footer
        }
        .padding(Self.contentPadding)
        .frame(width: Self.popupWidth)
        .background(
            WindowAppearanceBridge(appearance: audioEngine.settingsManager.appSettings.appearance.nsAppearance)
                .frame(width: 0, height: 0)
        )
        .darkGlassBackground()
        .preferredColorScheme(audioEngine.settingsManager.appSettings.appearance.swiftUIColorScheme)
        .environment(\.appearancePreference, audioEngine.settingsManager.appSettings.appearance)
        .onAppear {
            updateSortedDevices()
            // popupVisibility.isVisible is driven by the filtered NSWindow key
            // notifications below, not by .onAppear — SwiftUI mounts this view
            // before the popup is actually shown, and setting isVisible here
            // would suppress the HUD on the first media key at cold launch.
        }
        .onChange(of: audioEngine.outputDevices) { _, _ in
            updateSortedDevices()
            syncNavOrder()
        }
        .onChange(of: audioEngine.apps) { _, _ in
            syncNavOrder()
        }
        .onChange(of: deviceVolumeMonitor.defaultDeviceID) { _, _ in
            updateSortedDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            // Global notification — fires for every window in the process. Filter to
            // FluidMenuBarExtra's popup window so unrelated windows (the HID-tap
            // primer, NSAlert panels, etc.) don't mark the popup as visible and
            // suppress the HUD.
            guard let window = notification.object as? NSWindow,
                  String(describing: type(of: window)).contains("FluidMenuBarExtra")
            else { return }
            isPopupVisible = true
            popupVisibility.isVisible = true
            syncNavOrder()
            hasKeyboardEngaged = false
            selectedRow = nil
            anchorFocused = true
            textEntry.buffer = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            guard let window = notification.object as? NSWindow,
                  String(describing: type(of: window)).contains("FluidMenuBarExtra")
            else { return }
            isPopupVisible = false
            popupVisibility.isVisible = false
            hasKeyboardEngaged = false
            selectedRow = nil
        }
        // Single focus anchor on the body root. `.focusEffectDisabled` suppresses
        // the OS-drawn focus ring around the entire popup.
        .focusable()
        .focusEffectDisabled()
        .focused($anchorFocused)
        // [.down, .repeat] so holding a key keeps moving the selection or adjusting volume.
        .onKeyPress(phases: [.down, .repeat]) { keyPress in
            handleKeyPress(keyPress)
        }
        .environment(textEntry)
        .onChange(of: textEntry.navRestoreNonce) { _, _ in
            // A mouse-driven field edit ended; reclaim nav focus so arrows/Return work.
            anchorFocused = true
        }
        .background {
            Button("") { handleEscape() }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()
        }
    }

    // MARK: - Header & Footer

    private var header: some View {
        HStack {
            Text("EduTune")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            Spacer()
            Button("Settings", systemImage: "gearshape") {
                openSettingsWindow()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(PopupIconButtonStyle())
            .help("EduTune Settings")
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
    }

    private var footer: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Divider()
                .padding(.horizontal, DesignTokens.Spacing.sm)
            Button {
                openSettingsWindow()
            } label: {
                HStack {
                    Text("EduTune Settings…")
                    Spacer()
                }
            }
            .buttonStyle(PopupRowButtonStyle())
            .font(.system(size: 13))
            .foregroundStyle(DesignTokens.Colors.textPrimary)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Text("Quit EduTune")
                    Spacer()
                    Text("⌘Q")
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            .buttonStyle(PopupRowButtonStyle())
            .font(.system(size: 13))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit EduTune (⌘Q)")
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                sectionTitle("Output")
                OutputDeviceList(
                    devices: sortedDevices,
                    defaultDeviceID: deviceVolumeMonitor.defaultDeviceID,
                    iconOverride: { audioEngine.settingsManager.getDeviceIconOverride(for: $0) },
                    focusedUID: focusedDeviceUID,
                    onSelect: { device in
                        audioEngine.setDefaultOutputDevice(device.id)
                    }
                )
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                sectionTitle("Applications")
                appsContent
                hiddenAppsSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .accessibilityAddTraits(.isHeader)
    }

    private var focusedDeviceUID: String? {
        guard hasKeyboardEngaged, case .device(let uid) = selectedRow else { return nil }
        return uid
    }

    private func isAppFocused(_ id: String) -> Bool {
        hasKeyboardEngaged && selectedRow == .app(persistenceID: id)
    }

    @ViewBuilder
    private var appsContent: some View {
        if permission.status != .authorized {
            PermissionBannerView(permission: permission)
        } else if audioEngine.displayableApps.isEmpty {
            emptyStateView
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                ForEach(audioEngine.displayableApps) { displayableApp in
                    switch displayableApp {
                    case .active(let app):
                        activeAppRow(app: app, id: displayableApp.id)
                    case .pinnedInactive(let info):
                        inactiveAppRow(info: info, displayableApp: displayableApp)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 18))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
            Text("No apps playing audio")
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    /// Row for an active app (currently producing audio)
    @ViewBuilder
    private func activeAppRow(app: AudioApp, id: String) -> some View {
        if let deviceUID = audioEngine.getDeviceUID(for: app) {
            AppVolumeRow(
                icon: app.icon,
                name: app.name,
                volume: audioEngine.getVolume(for: app),
                isMuted: audioEngine.getMute(for: app),
                isFocused: isAppFocused(id),
                onVolumeChange: { audioEngine.setVolume(for: app, to: $0) },
                onMuteChange: { audioEngine.setMute(for: app, to: $0) },
                onIconTap: { activateApp(pid: app.id, bundleID: app.bundleID) }
            ) {
                appOutput(
                    mode: audioEngine.getDeviceSelectionMode(for: app),
                    selectedDeviceUID: deviceUID,
                    selectedDeviceUIDs: audioEngine.getSelectedDeviceUIDs(for: app),
                    isFollowingDefault: audioEngine.isFollowingDefault(for: app),
                    onSelectFollowDefault: { audioEngine.setDevice(for: app, deviceUID: nil) },
                    onDeviceSelected: { audioEngine.setDevice(for: app, deviceUID: $0) },
                    onDevicesSelected: { audioEngine.setSelectedDeviceUIDs(for: app, to: $0) }
                )
            }
            .contextMenu {
                Button(audioEngine.isPinned(app) ? "Unpin" : "Keep in List") {
                    if audioEngine.isPinned(app) {
                        audioEngine.unpinApp(app.persistenceIdentifier)
                    } else {
                        audioEngine.pinApp(app)
                    }
                }
                Button("Hide \(app.name)") {
                    audioEngine.ignoreApp(app)
                }
            }
            .id(PopupKeyboardNavModel.RowID.app(persistenceID: id))
        }
    }

    /// Row for a pinned inactive app (not currently producing audio)
    private func inactiveAppRow(info: PinnedAppInfo, displayableApp: DisplayableApp) -> some View {
        let identifier = info.persistenceIdentifier
        return AppVolumeRow(
            icon: displayableApp.icon,
            name: info.displayName,
            volume: audioEngine.getVolumeForInactive(identifier: identifier),
            isMuted: audioEngine.getMuteForInactive(identifier: identifier),
            isInactive: true,
            isFocused: isAppFocused(displayableApp.id),
            onVolumeChange: { audioEngine.setVolumeForInactive(identifier: identifier, to: $0) },
            onMuteChange: { audioEngine.setMuteForInactive(identifier: identifier, to: $0) }
        ) {
            appOutput(
                mode: audioEngine.getDeviceSelectionModeForInactive(identifier: identifier),
                selectedDeviceUID: audioEngine.getDeviceRoutingForInactive(identifier: identifier),
                selectedDeviceUIDs: audioEngine.getSelectedDeviceUIDsForInactive(identifier: identifier),
                isFollowingDefault: audioEngine.isFollowingDefaultForInactive(identifier: identifier),
                onSelectFollowDefault: { audioEngine.setDeviceRoutingForInactive(identifier: identifier, deviceUID: nil) },
                onDeviceSelected: { audioEngine.setDeviceRoutingForInactive(identifier: identifier, deviceUID: $0) },
                onDevicesSelected: { audioEngine.setSelectedDeviceUIDsForInactive(identifier: identifier, to: $0) }
            )
        }
        .contextMenu {
            Button("Unpin") {
                audioEngine.unpinApp(identifier)
            }
            Button("Hide \(info.displayName)") {
                let hiddenInfo = IgnoredAppInfo(
                    persistenceIdentifier: identifier,
                    displayName: info.displayName,
                    bundleID: info.bundleID
                )
                audioEngine.settingsManager.ignoreApp(identifier, info: hiddenInfo)
            }
        }
        .id(PopupKeyboardNavModel.RowID.app(persistenceID: displayableApp.id))
    }

    /// Output selector for one app. Apps already saved in multi-output mode keep a
    /// picker that can edit their device set; the mode itself is no longer offered.
    @ViewBuilder
    private func appOutput(
        mode: DeviceSelectionMode,
        selectedDeviceUID: String?,
        selectedDeviceUIDs: Set<String>,
        isFollowingDefault: Bool,
        onSelectFollowDefault: @escaping () -> Void,
        onDeviceSelected: @escaping (String) -> Void,
        onDevicesSelected: @escaping (Set<String>) -> Void
    ) -> some View {
        switch mode {
        case .single:
            AppOutputMenu(
                devices: sortedDevices,
                selectedDeviceUID: selectedDeviceUID,
                isFollowingDefault: isFollowingDefault,
                onSelectFollowDefault: onSelectFollowDefault,
                onDeviceSelected: onDeviceSelected
            )
        case .multi:
            DevicePicker(
                devices: sortedDevices,
                deviceIconOverrides: audioEngine.settingsManager.deviceIconOverrides,
                selectedDeviceUID: selectedDeviceUID ?? deviceVolumeMonitor.defaultDeviceUID ?? "",
                selectedDeviceUIDs: selectedDeviceUIDs,
                isFollowingDefault: isFollowingDefault,
                defaultDeviceUID: deviceVolumeMonitor.defaultDeviceUID,
                mode: .multi,
                onModeChange: { _ in },
                onDeviceSelected: onDeviceSelected,
                onDevicesSelected: onDevicesSelected,
                onSelectFollowDefault: onSelectFollowDefault,
                showModeToggle: false,
                triggerWidth: 0,
                triggerStyle: .iconOnly
            )
        }
    }

    // MARK: - Hidden Apps

    @ViewBuilder
    private var hiddenAppsSection: some View {
        let hiddenApps = audioEngine.settingsManager.getIgnoredAppInfo()
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        if !hiddenApps.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Button {
                    withAnimation(DesignTokens.Animation.quick) {
                        showsHiddenApps.toggle()
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text("Hidden Apps (\(hiddenApps.count))")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .rotationEffect(.degrees(showsHiddenApps ? 90 : 0))
                    }
                }
                .buttonStyle(PopupRowButtonStyle())
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.Colors.textSecondary)

                if showsHiddenApps {
                    ForEach(hiddenApps, id: \.persistenceIdentifier) { info in
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(nsImage: DisplayableApp.loadIcon(bundleID: info.bundleID))
                                .resizable()
                                .frame(width: 16, height: 16)
                                .opacity(0.6)
                            Text(info.displayName)
                                .font(.system(size: 12))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Button("Show") {
                                audioEngine.unignoreApp(info.persistenceIdentifier)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .help("Show \(info.displayName) and control its volume again")
                        }
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .transition(.opacity)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    /// Escape cancels keyboard entry first, then dismisses the popup.
    private func handleEscape() {
        // The hidden Escape keyboardShortcut button can win over `.onKeyPress`, so an
        // in-progress keyboard entry is cancelled here too.
        if textEntry.buffer != nil {
            textEntry.buffer = nil
            return
        }
        NSApp.keyWindow?.resignKey()
    }

    private func openSettingsWindow() {
        NSApp.keyWindow?.resignKey()
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    // MARK: - Helpers

    /// Recomputes sorted output devices, filtering hidden ones.
    /// The current default output device is always kept visible even if hidden.
    /// Falls back to the unfiltered list if the filter produces an empty
    /// result — `defaultDeviceUID` can be briefly nil during device switchover.
    private func updateSortedDevices() {
        let all = audioEngine.prioritySortedOutputDevices
        let defaultUID = deviceVolumeMonitor.defaultDeviceUID
        let filtered = all.filter { device in
            device.uid == defaultUID || !audioEngine.settingsManager.isOutputDeviceHidden(device.uid)
        }
        sortedDevices = filtered.isEmpty ? all : filtered
    }

    // MARK: - Keyboard Navigation

    private func syncNavOrder() {
        navModel.syncOrder(
            activeDevices: sortedDevices,
            appPersistenceIDs: audioEngine.displayableApps.map(\.id),
            isEditingPriority: false
        )
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        // `.onKeyPress` also fires for focused descendants; yield while a TextField is editing so its Return commits via onSubmit instead of activating a row.
        if NSApp.keyWindow?.firstResponder is NSTextView { return .ignored }
        // Keyboard entry mode: the popup owns every key so the anchor keeps first responder.
        if textEntry.buffer != nil {
            return handleKeyboardEditKey(keyPress)
        }
        let mods = keyPress.modifiers
        let isM = keyPress.key == KeyEquivalent("m")
        let editSeed = digitSeed(for: keyPress)
        let isRecognized: Bool = {
            switch keyPress.key {
            case .upArrow, .downArrow, .leftArrow, .rightArrow, .return, .space:
                return true
            default:
                return isM || editSeed != nil
            }
        }()
        // Wake gate: compute target locally so first-press actions never read a
        // stale selection. ↑/↓ wake without moving; action keys wake and act on
        // the default in the same press.
        let target: PopupKeyboardNavModel.RowID?
        let wokeUp: Bool
        if !hasKeyboardEngaged && isRecognized {
            hasKeyboardEngaged = true
            target = navModel.defaultFocus(defaultOutputUID: deviceVolumeMonitor.defaultDeviceUID)
            selectedRow = target
            wokeUp = true
        } else {
            target = selectedRow
            wokeUp = false
        }
        switch keyPress.key {
        case .upArrow:
            if wokeUp { return target == nil ? .ignored : .handled }
            if let next = navModel.previous(before: target) {
                selectedRow = next
                return .handled
            }
            return .ignored
        case .downArrow:
            if wokeUp { return target == nil ? .ignored : .handled }
            if let next = navModel.next(after: target) {
                selectedRow = next
                return .handled
            }
            return .ignored
        case .leftArrow:
            return adjustVolume(at: target, direction: -1, shift: mods.contains(.shift))
        case .rightArrow:
            return adjustVolume(at: target, direction: +1, shift: mods.contains(.shift))
        case .return, .space:
            return activate(target)
        default:
            if let editSeed, keyPress.phase == .down, case .app = target {
                textEntry.buffer = editSeed
                return .handled
            }
            return isM ? toggleMute(for: target) : .ignored
        }
    }

    /// Consumes every key while entry is active so editing keystrokes never leak to navigation.
    private func handleKeyboardEditKey(_ keyPress: KeyPress) -> KeyPress.Result {
        // The Mac ⌫ key arrives as DEL (U+007F), which `KeyEquivalent.delete` doesn't match.
        if keyPress.characters == "\u{7f}" || keyPress.key == .delete {
            let next = String((textEntry.buffer ?? "").dropLast())
            textEntry.buffer = next.isEmpty ? nil : next
            return .handled
        }
        switch keyPress.key {
        case .return:
            textEntry.commitNonce += 1
            return .handled
        case .escape:
            textEntry.buffer = nil
            return .handled
        default:
            if let digit = digitSeed(for: keyPress), keyPress.phase == .down {
                let current = textEntry.buffer ?? ""
                if current.count < 4 {
                    textEntry.buffer = current + digit
                }
            }
            return .handled
        }
    }

    /// The bare digit `0`–`9` for this key press, or nil (modifier combos excluded).
    private func digitSeed(for keyPress: KeyPress) -> String? {
        guard keyPress.modifiers.intersection([.command, .control, .option]).isEmpty,
              keyPress.characters.count == 1,
              let ch = keyPress.characters.first,
              ("0"..."9").contains(ch)
        else { return nil }
        return String(ch)
    }

    /// ←/→ adjust the focused app's volume. Device rows no longer carry a volume control.
    private func adjustVolume(at target: PopupKeyboardNavModel.RowID?, direction: Int, shift: Bool) -> KeyPress.Result {
        guard case .app(let persistenceID) = target else { return .ignored }
        let baseStep = audioEngine.settingsManager.appSettings.volumeHotkeyStep.sliderDelta
        let step = shift ? baseStep * 2.0 : baseStep
        let delta = step * Double(direction)
        if let app = audioEngine.apps.first(where: { $0.persistenceIdentifier == persistenceID }) {
            applyAppVolumeStep(
                currentGain: audioEngine.currentVolume(for: app),
                currentMute: audioEngine.isMuted(for: app),
                direction: direction,
                delta: delta,
                setGain: { audioEngine.setVolume(for: app, to: $0) },
                setMute: { audioEngine.setMute(for: app, to: $0) }
            )
            return .handled
        }
        applyAppVolumeStep(
            currentGain: audioEngine.getVolumeForInactive(identifier: persistenceID),
            currentMute: audioEngine.getMuteForInactive(identifier: persistenceID),
            direction: direction,
            delta: delta,
            setGain: { audioEngine.setVolumeForInactive(identifier: persistenceID, to: $0) },
            setMute: { audioEngine.setMuteForInactive(identifier: persistenceID, to: $0) }
        )
        return .handled
    }

    /// Mirrors `ShortcutsRegistry.adjustTargetVolume`'s mute-edge semantics for
    /// both active and pinned-inactive app rows.
    private func applyAppVolumeStep(
        currentGain: Float,
        currentMute: Bool,
        direction: Int,
        delta: Double,
        setGain: (Float) -> Void,
        setMute: (Bool) -> Void
    ) {
        let currentSlider = VolumeMapping.gainToSlider(currentGain)
        let nextSlider = max(0.0, min(1.0, currentSlider + delta))
        let nextGain = VolumeMapping.sliderToGain(nextSlider)
        let willBeSilent = nextSlider <= 0.001
        if direction > 0 {
            if currentMute { setMute(false) }
        } else if currentMute && !willBeSilent {
            setMute(false)
        } else if !currentMute && willBeSilent {
            setMute(true)
        }
        setGain(nextGain)
    }

    private func toggleMute(for target: PopupKeyboardNavModel.RowID?) -> KeyPress.Result {
        guard case .app(let persistenceID) = target else { return .ignored }
        if let app = audioEngine.apps.first(where: { $0.persistenceIdentifier == persistenceID }) {
            audioEngine.toggleMute(for: app)
            return .handled
        }
        let current = audioEngine.getMuteForInactive(identifier: persistenceID)
        audioEngine.setMuteForInactive(identifier: persistenceID, to: !current)
        return .handled
    }

    /// Return/Space on a device row makes it the default output; on an app row it toggles mute.
    private func activate(_ target: PopupKeyboardNavModel.RowID?) -> KeyPress.Result {
        guard let target else { return .ignored }
        switch target {
        case .device(let uid):
            guard let device = sortedDevices.first(where: { $0.uid == uid }) else {
                return .ignored
            }
            audioEngine.setDefaultOutputDevice(device.id)
            return .handled
        case .app:
            return toggleMute(for: target)
        }
    }

    /// Activates an app, bringing it to foreground and restoring minimized windows
    private func activateApp(pid: pid_t, bundleID: String?) {
        // Step 1: Always activate via NSRunningApplication (reliable for non-minimized)
        let runningApp = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
        runningApp?.activate()

        // Step 2: Try to restore minimized windows via AppleScript
        if let bundleID = bundleID {
            // reopen + activate restores minimized windows for most apps
            let script = NSAppleScript(source: """
                tell application id "\(bundleID)"
                    reopen
                    activate
                end tell
                """)
            script?.executeAndReturnError(nil)
        }
    }
}

/// Small borderless icon button with hover / pressed feedback.
private struct PopupIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PopupIconButtonBody(configuration: configuration)
    }
}

private struct PopupIconButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(isHovered ? DesignTokens.Colors.interactiveHover : DesignTokens.Colors.interactiveDefault)
            .frame(width: 24, height: 24)
            .background {
                Circle().fill(isHovered ? DesignTokens.Colors.hoverSurface : .clear)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .contentShape(Circle())
            .onHover { isHovered = $0 }
            .animation(DesignTokens.Animation.hover, value: isHovered)
            .animation(DesignTokens.Animation.quick, value: configuration.isPressed)
    }
}
