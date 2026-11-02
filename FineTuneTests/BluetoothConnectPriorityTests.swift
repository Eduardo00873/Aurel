// FineTuneTests/BluetoothConnectPriorityTests.swift
import Testing
import Foundation
import AudioToolbox
@testable import FineTune

/// Connecting Bluetooth headphones should take over the output, as on macOS:
/// the device moves to the top of the priority list. Wired devices keep their place.
@Suite("Bluetooth connect priority")
@MainActor
struct BluetoothConnectPriorityTests {
    private let speakers = AudioDevice(id: 75, uid: "BuiltInSpeakerDevice", name: "MacBook Air Speakers", icon: nil, supportsAutoEQ: false)
    private let display = AudioDevice(id: 82, uid: "display-uid", name: "VG278", icon: nil, supportsAutoEQ: false)
    private let headphones = AudioDevice(id: 90, uid: "41-42-FF-BC-37-BC:output", name: "Headphones", icon: nil, supportsAutoEQ: false)
    private let usb = AudioDevice(id: 95, uid: "usb-dac", name: "USB DAC", icon: nil, supportsAutoEQ: false)

    private func makeEngine(priority: [String]) -> (AudioEngine, MockAudioDeviceMonitor, SettingsManager) {
        let settings = SettingsManager(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("FineTuneTests-\(UUID().uuidString)"))
        settings.setDevicePriorityOrder(priority)
        let monitor = MockAudioDeviceMonitor()
        for device in [speakers, display, headphones, usb] { monitor.addOutputDevice(device) }
        let volume = MockDeviceVolumeProviding(deviceMonitor: monitor)
        volume.defaultDeviceID = speakers.id
        volume.defaultDeviceUID = speakers.uid
        let bluetoothID = headphones.id
        let engine = AudioEngine(
            permission: AudioRecordingPermission(),
            settingsManager: settings,
            autoEQProfileManager: AutoEQProfileManager(),
            deviceProvider: monitor,
            deviceVolumeMonitor: volume,
            isAlive: { _ in true },
            isBluetooth: { $0 == bluetoothID },
            startMonitorsAutomatically: false
        )
        return (engine, monitor, settings)
    }

    @Test("A newly connected Bluetooth device becomes the top priority")
    func newBluetoothGoesToTop() {
        let (engine, monitor, settings) = makeEngine(priority: [speakers.uid, display.uid])
        monitor.onDeviceConnected?(headphones.uid, headphones.name)
        #expect(settings.devicePriorityOrder == [headphones.uid, speakers.uid, display.uid])
        _ = engine
    }

    @Test("A reconnecting Bluetooth device that was last moves back to the top")
    func reconnectingBluetoothGoesToTop() {
        let (engine, monitor, settings) = makeEngine(priority: [speakers.uid, display.uid, headphones.uid])
        monitor.onDeviceConnected?(headphones.uid, headphones.name)
        #expect(settings.devicePriorityOrder == [headphones.uid, speakers.uid, display.uid])
        _ = engine
    }

    @Test("A wired device keeps its saved position or is appended")
    func wiredDeviceKeepsPosition() {
        let (engine, monitor, settings) = makeEngine(priority: [speakers.uid, display.uid])
        monitor.onDeviceConnected?(display.uid, display.name)
        monitor.onDeviceConnected?(usb.uid, usb.name)
        #expect(settings.devicePriorityOrder == [speakers.uid, display.uid, usb.uid])
        _ = engine
    }

    @Test("Promoting is idempotent and keeps every other device in order")
    func promoteIsIdempotent() {
        let settings = SettingsManager(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("FineTuneTests-\(UUID().uuidString)"))
        settings.setDevicePriorityOrder(["a", "b", "c"])
        settings.promoteDeviceToTopPriority("c")
        settings.promoteDeviceToTopPriority("c")
        #expect(settings.devicePriorityOrder == ["c", "a", "b"])
        settings.promoteDeviceToTopPriority("new")
        #expect(settings.devicePriorityOrder == ["new", "c", "a", "b"])
    }
}
