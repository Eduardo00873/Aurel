// FineTuneTests/WelcomeWindowControllerTests.swift
import Testing
@testable import FineTune

@Suite("WelcomeWindowController")
@MainActor
struct WelcomeWindowControllerTests {
    @Test("Shown only while the audio permission is undecided")
    func shownOnlyWhenUndecided() {
        #expect(WelcomeWindowController.shouldShow(for: .unknown))
        #expect(!WelcomeWindowController.shouldShow(for: .authorized))
        #expect(!WelcomeWindowController.shouldShow(for: .denied))
    }
}
