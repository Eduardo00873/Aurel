// FineTuneTests/URLHandlerSetDeviceTests.swift
import Testing
import Foundation
import AppKit
@testable import FineTune

@Suite("URLHandler set-device respects ignored apps")
@MainActor
struct URLHandlerSetDeviceTests {
    @Test("set-device does not route an ignored app")
    func ignoredAppIsNotRouted() {
        let (engine, handler) = makeHandler()
        let app = makeApp(pid: 101, bundleID: "net.whatsapp.WhatsApp")
        engine.apps = [app]
        ignore(app, in: engine.settingsManager)

        handler.handleURL(setDeviceURL(app: "net.whatsapp.WhatsApp", device: "speakers"))

        #expect(engine.setDeviceCalls.isEmpty)
    }

    @Test("set-device routes a non-ignored app to the requested device")
    func nonIgnoredAppIsRouted() {
        let (engine, handler) = makeHandler()
        let app = makeApp(pid: 102, bundleID: "com.spotify.client")
        engine.apps = [app]

        handler.handleURL(setDeviceURL(app: "com.spotify.client", device: "headphones"))

        #expect(engine.setDeviceCalls.count == 1)
        #expect(engine.setDeviceCalls.first?.pid == app.id)
        #expect(engine.setDeviceCalls.first?.deviceUID == "headphones")
    }

    @Test("Ignoring one app does not affect device selection for other apps")
    func otherAppsKeepDeviceSelection() {
        let (engine, handler) = makeHandler()
        let ignored = makeApp(pid: 103, bundleID: "net.whatsapp.WhatsApp")
        let normal = makeApp(pid: 104, bundleID: "com.apple.Music")
        engine.apps = [ignored, normal]
        ignore(ignored, in: engine.settingsManager)

        handler.handleURL(setDeviceURL(app: "net.whatsapp.WhatsApp", device: "speakers"))
        handler.handleURL(setDeviceURL(app: "com.apple.Music", device: "speakers"))
        handler.handleURL(setDeviceURL(app: "com.apple.Music", device: "headphones"))

        #expect(engine.setDeviceCalls.map(\.pid) == [normal.id, normal.id])
        #expect(engine.setDeviceCalls.map(\.deviceUID) == ["speakers", "headphones"])
    }

    @Test("Ignored state is honored whenever it changes")
    func ignoredStateOrderIndependent() {
        let (engine, handler) = makeHandler()
        let app = makeApp(pid: 105, bundleID: "net.whatsapp.WhatsApp")
        engine.apps = [app]
        let url = setDeviceURL(app: "net.whatsapp.WhatsApp", device: "speakers")

        // Routed before being ignored
        handler.handleURL(url)
        #expect(engine.setDeviceCalls.count == 1)

        // Ignored afterwards: no further routing
        ignore(app, in: engine.settingsManager)
        handler.handleURL(url)
        #expect(engine.setDeviceCalls.count == 1)

        // Unignored again: normal routing resumes
        engine.settingsManager.unignoreApp(app.persistenceIdentifier)
        handler.handleURL(url)
        #expect(engine.setDeviceCalls.count == 2)
    }

    // MARK: - Helpers

    private func makeHandler() -> (MockURLHandlerEngine, URLHandler) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FineTuneTests-\(UUID().uuidString)")
        let engine = MockURLHandlerEngine(settingsManager: SettingsManager(directory: tempDir))
        return (engine, URLHandler(audioEngine: engine))
    }

    private func makeApp(pid: pid_t, bundleID: String) -> AudioApp {
        AudioApp(
            id: pid,
            processObjectIDs: [],
            name: bundleID,
            icon: NSImage(),
            bundleID: bundleID
        )
    }

    private func ignore(_ app: AudioApp, in settings: SettingsManager) {
        settings.ignoreApp(
            app.persistenceIdentifier,
            info: IgnoredAppInfo(persistenceIdentifier: app.persistenceIdentifier, displayName: app.name, bundleID: app.bundleID)
        )
    }

    private func setDeviceURL(app: String, device: String) -> URL {
        URL(string: "edutune://set-device?app=\(app)&device=\(device)")!
    }
}

@MainActor
private final class MockURLHandlerEngine: URLHandlerEngine {
    var apps: [AudioApp] = []
    let settingsManager: SettingsManager
    private(set) var setDeviceCalls: [(pid: pid_t, deviceUID: String?)] = []

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    func setDevice(for app: AudioApp, deviceUID: String?) {
        setDeviceCalls.append((app.id, deviceUID))
    }

    func setVolume(for app: AudioApp, to volume: Float) {}
    func getVolume(for app: AudioApp) -> Float { 1.0 }
    func setMute(for app: AudioApp, to muted: Bool) {}
    func getMute(for app: AudioApp) -> Bool { false }
    func setVolumeForInactive(identifier: String, to volume: Float) {}
    func setMuteForInactive(identifier: String, to muted: Bool) {}
    func getMuteForInactive(identifier: String) -> Bool { false }
}
