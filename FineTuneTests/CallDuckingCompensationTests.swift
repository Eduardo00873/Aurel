// FineTuneTests/CallDuckingCompensationTests.swift
import Testing
import Foundation
import AppKit
import AudioToolbox
@testable import FineTune

/// During a call macOS ducks every other process, including Aurel's replay of the
/// calling app. Apps capturing input get +20 dB on top of their volume to make up for it.
@Suite("Call ducking compensation")
@MainActor
struct CallDuckingCompensationTests {
    private final class Box {
        var tap: RecordingProcessTapController?
        var inCall = false
    }

    private let device = AudioDevice(id: AudioDeviceID(99), uid: "uid-test", name: "Test Output", icon: nil, supportsAutoEQ: false)
    private let app = AudioApp(id: 777, processObjectIDs: [], name: "WhatsApp", icon: NSImage(), bundleID: "net.whatsapp.WhatsApp")

    private func makeEngine() -> (AudioEngine, SettingsManager, Box) {
        let settings = SettingsManager(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("FineTuneTests-\(UUID().uuidString)"))
        let monitor = MockAudioDeviceMonitor()
        monitor.addOutputDevice(device)
        let processMonitor = StubProcessMonitor()
        processMonitor.activeApps = [app]
        let permission = AudioRecordingPermission()
        permission.status = .authorized
        let box = Box()
        let engine = AudioEngine(
            permission: permission,
            settingsManager: settings,
            autoEQProfileManager: AutoEQProfileManager(),
            deviceProvider: monitor,
            processMonitor: processMonitor,
            deviceVolumeMonitor: MockDeviceVolumeProviding(deviceMonitor: monitor),
            tapFactory: { app, uids, _ in
                let tap = RecordingProcessTapController(app: app, deviceUIDs: uids)
                box.tap = tap
                return tap
            },
            isRunningInput: { _ in box.inCall },
            startMonitorsAutomatically: false
        )
        engine.setDevice(for: app, deviceUID: device.uid)
        engine.volumeState.setVolume(for: app.id, to: 0.5, identifier: app.persistenceIdentifier)
        engine.setVolume(for: app, to: 0.5)
        return (engine, settings, box)
    }

    @Test("An app in a call gets +20 dB, and loses it when the call ends")
    func compensatesDuringCall() throws {
        let (engine, _, box) = makeEngine()
        let tap = try #require(box.tap)
        #expect(tap.volume == 0.5)

        box.inCall = true
        engine.refreshCallState()
        #expect(engine.callActivePIDs == [app.id])
        #expect(abs(tap.volume - 5.0) < 0.0001)

        box.inCall = false
        engine.refreshCallState()
        #expect(engine.callActivePIDs.isEmpty)
        #expect(tap.volume == 0.5)
    }

    @Test("Volume changes during a call keep the compensation")
    func volumeChangeDuringCall() throws {
        let (engine, _, box) = makeEngine()
        let tap = try #require(box.tap)
        box.inCall = true
        engine.refreshCallState()
        engine.setVolume(for: app, to: 0.2)
        #expect(abs(tap.volume - 2.0) < 0.0001)
    }

    @Test("Turning the setting off removes the compensation immediately")
    func settingOff() throws {
        let (engine, settings, box) = makeEngine()
        let tap = try #require(box.tap)
        box.inCall = true
        engine.refreshCallState()

        var s = settings.appSettings
        s.callDuckingCompensationEnabled = false
        settings.updateAppSettings(s)
        engine.setCallDuckingCompensationEnabled(false)
        #expect(tap.volume == 0.5)
    }

    @Test("The setting is on by default and survives a missing key")
    func defaultOn() throws {
        #expect(AppSettings().callDuckingCompensationEnabled)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(decoded.callDuckingCompensationEnabled)
    }
}
