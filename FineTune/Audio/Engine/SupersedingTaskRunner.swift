// FineTune/Audio/Engine/SupersedingTaskRunner.swift
import Foundation

/// Runs one async operation at a time; a new request supersedes the current one.
///
/// Starting a request cancels the operation in flight and waits for it to finish —
/// including its cleanup (`defer`) — before the new operation starts. Requests that are
/// themselves superseded while waiting throw `CancellationError` without running.
/// This stops a cancelled device switch from tearing down resources that the next
/// switch has already created.
@MainActor
final class SupersedingTaskRunner {
    private var current: Task<Void, Error>?
    private var generation = 0

    func run(_ operation: @escaping @MainActor () async throws -> Void) async throws {
        generation += 1
        let myGeneration = generation

        let previous = current
        previous?.cancel()
        _ = await previous?.result

        // A newer request arrived while we were waiting: let it run instead.
        guard myGeneration == generation else { throw CancellationError() }

        let task = Task { @MainActor in try await operation() }
        current = task
        defer { if generation == myGeneration { current = nil } }
        try await task.value
    }

    /// Cancels the operation in flight, if any, without waiting for it.
    func cancel() {
        generation += 1
        current?.cancel()
        current = nil
    }
}
