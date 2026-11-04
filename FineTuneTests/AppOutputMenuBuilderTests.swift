// FineTuneTests/AppOutputMenuBuilderTests.swift
import Testing
import AppKit
@testable import FineTune

@Suite("AppOutputMenuBuilder")
@MainActor
struct AppOutputMenuBuilderTests {
    private let speakers = AudioDevice(id: 75, uid: "BuiltInSpeakerDevice", name: "Colunas (MacBook Air)", icon: nil)
    private let monitor = AudioDevice(id: 82, uid: "VG278-UID", name: "VG278", icon: nil)

    private final class Recorder {
        var followDefaultCount = 0
        var selectedUIDs: [String] = []
    }

    private func makeMenu(isFollowingDefault: Bool, selectedDeviceUID: String?, recorder: Recorder) -> NSMenu {
        AppOutputMenuBuilder.makeMenu(
            devices: [speakers, monitor],
            selectedDeviceUID: selectedDeviceUID,
            isFollowingDefault: isFollowingDefault,
            systemOutputName: "Colunas (MacBook Air)",
            onSelectFollowDefault: { recorder.followDefaultCount += 1 },
            onDeviceSelected: { recorder.selectedUIDs.append($0) }
        )
    }

    private func hasCheckmark(_ item: NSMenuItem) -> Bool { item.image != nil }

    @Test("Sections and System Default come first with the current output name")
    func structure() {
        let menu = makeMenu(isFollowingDefault: true, selectedDeviceUID: "BuiltInSpeakerDevice", recorder: Recorder())
        let titles = menu.items.map(\.title)
        #expect(menu.items[0].isSectionHeader)
        #expect(titles[0] == "Follow System Output")
        #expect(titles[1] == "System Default (Colunas (MacBook Air))")
        #expect(menu.items[2].isSeparatorItem)
        #expect(menu.items[3].isSectionHeader)
        #expect(titles[3] == "Play Only On")
        #expect(Array(titles[4...]) == ["Colunas (MacBook Air)", "VG278"])
    }

    @Test("System Default title without a known output")
    func systemDefaultTitleWithoutOutput() {
        #expect(AppOutputMenuBuilder.systemDefaultTitle(systemOutputName: nil) == "System Default")
    }

    @Test("Following the system output checks only System Default")
    func checkmarkWhenFollowing() {
        let menu = makeMenu(isFollowingDefault: true, selectedDeviceUID: "BuiltInSpeakerDevice", recorder: Recorder())
        #expect(hasCheckmark(menu.items[1]))
        #expect(!hasCheckmark(menu.items[4]))
        #expect(!hasCheckmark(menu.items[5]))
    }

    @Test("A pinned app checks only its device")
    func checkmarkWhenPinned() {
        let menu = makeMenu(isFollowingDefault: false, selectedDeviceUID: "VG278-UID", recorder: Recorder())
        #expect(!hasCheckmark(menu.items[1]))
        #expect(!hasCheckmark(menu.items[4]))
        #expect(hasCheckmark(menu.items[5]))
    }

    @Test("Building the menu runs no action")
    func buildingHasNoSideEffects() {
        let recorder = Recorder()
        _ = makeMenu(isFollowingDefault: false, selectedDeviceUID: "VG278-UID", recorder: recorder)
        #expect(recorder.followDefaultCount == 0)
        #expect(recorder.selectedUIDs.isEmpty)
    }

    @Test("Selecting System Default runs only the follow-default action, once")
    func selectSystemDefault() {
        let recorder = Recorder()
        let menu = makeMenu(isFollowingDefault: false, selectedDeviceUID: "VG278-UID", recorder: recorder)
        menu.performActionForItem(at: 1)
        #expect(recorder.followDefaultCount == 1)
        #expect(recorder.selectedUIDs.isEmpty)
    }

    @Test("Selecting a device runs only that device's action, once")
    func selectDevice() {
        let recorder = Recorder()
        let menu = makeMenu(isFollowingDefault: true, selectedDeviceUID: "BuiltInSpeakerDevice", recorder: recorder)
        menu.performActionForItem(at: 5)
        #expect(recorder.selectedUIDs == ["VG278-UID"])
        #expect(recorder.followDefaultCount == 0)
    }

    @Test("Section headers and separators carry no action")
    func headersAreInert() {
        let menu = makeMenu(isFollowingDefault: true, selectedDeviceUID: nil, recorder: Recorder())
        for index in [0, 2, 3] {
            #expect(menu.items[index].action == nil)
        }
    }
}
