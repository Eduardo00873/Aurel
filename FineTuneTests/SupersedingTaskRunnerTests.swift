// FineTuneTests/SupersedingTaskRunnerTests.swift
import Testing
import Foundation
@testable import FineTune

/// Guards the fix for rapid device switches: a cancelled switch's cleanup must finish
/// before the next switch starts, so it can't tear down the next switch's resources.
@Suite("SupersedingTaskRunner")
@MainActor
struct SupersedingTaskRunnerTests {
    @MainActor
    private final class Log {
        var events: [String] = []
    }

    @Test("A superseded operation finishes its cleanup before the next one starts")
    func cleanupRunsBeforeNextStarts() async throws {
        let runner = SupersedingTaskRunner()
        let log = Log()

        let first = Task { @MainActor in
            try? await runner.run {
                log.events.append("A start")
                defer { log.events.append("A cleanup") }
                try await Task.sleep(for: .seconds(5))
                log.events.append("A finished")
            }
        }
        try await Task.sleep(for: .milliseconds(50))

        try await runner.run {
            log.events.append("B start")
            log.events.append("B finished")
        }
        await first.value

        #expect(log.events == ["A start", "A cleanup", "B start", "B finished"])
    }

    @Test("Of several rapid requests, only the newest runs after the one in flight")
    func onlyNewestRequestRuns() async throws {
        let runner = SupersedingTaskRunner()
        let log = Log()

        let first = Task { @MainActor in
            try? await runner.run {
                defer { log.events.append("A cleanup") }
                try await Task.sleep(for: .seconds(5))
            }
        }
        try await Task.sleep(for: .milliseconds(50))

        let second = Task { @MainActor () -> Bool in
            do {
                try await runner.run { log.events.append("B ran") }
                return true
            } catch { return false }
        }
        let third = Task { @MainActor () -> Bool in
            do {
                try await runner.run { log.events.append("C ran") }
                return true
            } catch { return false }
        }

        await first.value
        let secondRan = await second.value
        let thirdRan = await third.value

        #expect(!secondRan)
        #expect(thirdRan)
        #expect(log.events == ["A cleanup", "C ran"])
    }

    @Test("cancel() stops the operation in flight")
    func cancelStopsOperation() async throws {
        let runner = SupersedingTaskRunner()
        let task = Task { @MainActor () -> Bool in
            do {
                try await runner.run { try await Task.sleep(for: .seconds(5)) }
                return true
            } catch { return false }
        }
        try await Task.sleep(for: .milliseconds(50))
        runner.cancel()
        let completed = await task.value
        #expect(!completed)
    }
}
