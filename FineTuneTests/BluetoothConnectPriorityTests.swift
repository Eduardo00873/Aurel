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
    private let speakers = AudioDevice(id: 75, uid: "BuiltInSpeakerDevice", name: "MacBook Air Speakers", icon: nil)
    private let display = AudioDevice(id: 82, uid: "display-uid", name: "VG278", icon: nil)
    private let headphones = AudioDevice(id: 90, uid: "41-42-FF-BC-37-BC:output", name: "Headphones", icon: nil)
    private let usb = AudioDevice(id: 95, uid: "usb-dac", name: "USB DAC", icon: nil)
    private let jack = AudioDevice(id: 77, uid: "BuiltInHeadphoneOutputDevice", name: "External Headphones", icon: nil)

    private func makeEngine(priority: [String]) -> (AudioEngine, MockAudioDeviceMonitor, SettingsManager) {
        let settings = SettingsManager(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("FineTuneTests-\(UUID().uuidString)"))
        settings.setDevicePriorityOrder(priority)
        let monitor = MockAudioDeviceMonitor()
        for device in [speakers, display, headphones, usb, jack] { monitor.addOutputDevice(device) }
        let volume = MockDeviceVolumeProviding(deviceMonitor: monitor)
        volume.defaultDeviceID = speakers.id
        volume.defaultDeviceUID = speakers.uid
        let bluetoothID = headphones.id
        let engine = AudioEngine(
            permission: AudioRecordingPermission(),
            settingsManager: settings,
            deviceProvider: monitor,
            deviceVolumeMonitor: volume,
            isAlive: { _ in true },
            isBluetooth: { $0 == bluetoothID },
            isWiredHeadphones: { $0.uid == "BuiltInHeadphoneOutputDevice" },
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

    @Test("Wired headphones on the jack also become the top priority")
    func wiredHeadphonesGoToTop() {
        let (engine, monitor, settings) = makeEngine(priority: [speakers.uid, display.uid, jack.uid])
        monitor.onDeviceConnected?(jack.uid, jack.name)
        #expect(settings.devicePriorityOrder == [jack.uid, speakers.uid, display.uid])
        _ = engine
    }

    @Test("The default wired-headphones check recognises the built-in jack device by UID")
    func jackUIDIsRecognised() {
        #expect(AudioDeviceID(0).isWiredHeadphoneOutput(uid: "BuiltInHeadphoneOutputDevice"))
        #expect(!AudioDeviceID(0).isWiredHeadphoneOutput(uid: "BuiltInSpeakerDevice"))
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
