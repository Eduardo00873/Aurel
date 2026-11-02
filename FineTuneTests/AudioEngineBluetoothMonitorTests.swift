// FineTuneTests/AudioEngineBluetoothMonitorTests.swift
import Testing
import Foundation
@testable import FineTune

/// The paired-Bluetooth monitor has no consumer after the popup redesign, and querying
/// IOBluetooth triggers a Bluetooth permission prompt, so device events must not touch it.
@Suite("AudioEngine — Bluetooth monitor stays idle")
@MainActor
struct AudioEngineBluetoothMonitorTests {
    private func makeEngine() -> (AudioEngine, MockAudioDeviceMonitor) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FineTuneTests-\(UUID().uuidString)")
        let deviceMonitor = MockAudioDeviceMonitor()
        let engine = AudioEngine(
            permission: AudioRecordingPermission(),
            settingsManager: SettingsManager(directory: tempDir),
            autoEQProfileManager: AutoEQProfileManager(),
            deviceProvider: deviceMonitor,
            deviceVolumeMonitor: MockDeviceVolumeProviding(deviceMonitor: deviceMonitor),
            startMonitorsAutomatically: false
        )
        return (engine, deviceMonitor)
    }

    @Test("A fresh engine has no paired-Bluetooth state")
    func idleAfterInit() {
        let (engine, _) = makeEngine()
        #expect(engine.bluetoothDeviceMonitor.refreshRequestCount == 0)
        #expect(engine.bluetoothDeviceMonitor.pairedDevices.isEmpty)
    }

    @Test("Device connect and disconnect events leave the Bluetooth monitor untouched")
    func deviceEventsDoNotQueryBluetooth() {
        let (engine, deviceMonitor) = makeEngine()
        deviceMonitor.onDeviceConnected?("test-device-uid", "Test Headphones")
        deviceMonitor.onDeviceDisconnected?("test-device-uid", "Test Headphones")
        #expect(engine.bluetoothDeviceMonitor.refreshRequestCount == 0)
        #expect(engine.bluetoothDeviceMonitor.pairedDevices.isEmpty)
    }
}
