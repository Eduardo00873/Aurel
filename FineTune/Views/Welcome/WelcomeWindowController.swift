// FineTune/Views/Welcome/WelcomeWindowController.swift
import AppKit
import SwiftUI

/// First-launch window that explains why Aurel needs System Audio Recording
/// before macOS shows its own permission prompt.
@MainActor
final class WelcomeWindowController {
    private var window: NSWindow?

    /// The welcome only makes sense while the user hasn't decided on the permission yet.
    static func shouldShow(for status: AudioCapturePermissionStatus) -> Bool {
        status == .unknown
    }

    func show(onContinue: @escaping () -> Void) {
        guard window == nil else { return }
        let view = WelcomeView { [weak self] in
            self?.close()
            onContinue()
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
        window = nil
    }
}

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .padding(.top, 40)

            Text("Welcome to Aurel")
                .font(.system(size: 24, weight: .semibold))
                .padding(.top, 16)

            Text("Every app, its own volume.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 18) {
                feature("slider.horizontal.3", "A volume for every app",
                        "Turn one app down and keep the rest exactly as they are.")
                feature("speaker.slash", "Mute with one click",
                        "Silence a single app without touching the others.")
                feature("lock.shield", "Your audio stays on your Mac",
                        "Aurel needs System Audio Recording to adjust each app's sound. Nothing is recorded, saved or uploaded.")
            }
            .padding(.top, 32)
            .padding(.horizontal, 40)

            Spacer(minLength: 24)

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, 40)

            Text("macOS will ask for permission next.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.top, 10)
                .padding(.bottom, 28)
        }
        .frame(width: 420, height: 500)
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
