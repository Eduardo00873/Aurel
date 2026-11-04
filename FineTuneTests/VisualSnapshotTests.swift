// FineTuneTests/VisualSnapshotTests.swift
import AppKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import FineTune

/// Visual regression tests for the popup rows and the Settings sidebar, in light and dark.
///
/// Reference images live in `__Snapshots__/VisualSnapshotTests/`. To re-record after an
/// intended visual change, delete the affected images and run the tests twice.
/// Skipped in CI: the runner's macOS and Xcode render text slightly differently.
@Suite("Visual snapshots")
@MainActor
struct VisualSnapshotTests {
    private static let appearances: [(name: String, appearance: NSAppearance.Name)] = [
        ("light", .aqua),
        ("dark", .darkAqua),
    ]

    private func host<V: View>(_ view: V, width: CGFloat, height: CGFloat, appearance: NSAppearance.Name) -> NSView {
        let hosting = NSHostingView(rootView: view
            .frame(width: width, height: height)
            .background(DesignTokens.Palette.surface))
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hosting.appearance = NSAppearance(named: appearance)
        hosting.layoutSubtreeIfNeeded()
        return hosting
    }

    private func assertAppearances<V: View>(
        _ view: V, width: CGFloat, height: CGFloat,
        fileID: StaticString = #fileID, file: StaticString = #filePath,
        testName: String = #function, line: UInt = #line, column: UInt = #column
    ) {
        for (name, appearance) in Self.appearances {
            assertSnapshot(
                of: host(view, width: width, height: height, appearance: appearance),
                as: .image(precision: 0.99, perceptualPrecision: 0.98),
                named: name, fileID: fileID, file: file, testName: testName, line: line, column: column
            )
        }
    }

    private var appIcon: NSImage {
        NSImage(systemSymbolName: "music.note", accessibilityDescription: nil) ?? NSImage()
    }

    private func row(volume: Float, isMuted: Bool = false, isInactive: Bool = false, boost: BoostLevel = .x1) -> some View {
        AppVolumeRow(
            icon: appIcon, name: "Music", volume: volume, isMuted: isMuted,
            isInactive: isInactive, boost: boost, onBoostChange: { _ in },
            onVolumeChange: { _ in }, onMuteChange: { _ in }
        ) { EmptyView() }
            .padding(.horizontal, DesignTokens.Spacing.md)
    }

    @Test func testAppVolumeRow() {
        assertAppearances(row(volume: 0.5), width: 340, height: 56)
    }

    @Test func testAppVolumeRowMuted() {
        assertAppearances(row(volume: 0.5, isMuted: true), width: 340, height: 56)
    }

    @Test func testAppVolumeRowInactive() {
        assertAppearances(row(volume: 0.8, isInactive: true), width: 340, height: 56)
    }

    @Test func testAppVolumeRowBoosted() {
        assertAppearances(row(volume: 0.5, boost: .x2), width: 340, height: 56)
    }

    @Test func testSettingsSidebar() {
        assertAppearances(SettingsSidebar(selection: .constant(.general)), width: 200, height: 260)
    }
}
