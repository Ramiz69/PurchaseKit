//
//  RKEventBroadcaster.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation
import Synchronization

/// Delivers every event to every active subscriber.
///
/// `AsyncStream` has exactly one consumer. Two `for await` loops over the *same* stream do
/// not each receive the full sequence — they split it, so one screen sees an event and the
/// other silently misses it. Handing out one shared stream therefore loses purchase events
/// as soon as a second observer appears. Instead each subscriber gets its own stream, and
/// this type keeps the live continuations so a single yield reaches all of them.
///
/// State lives behind a `Mutex`, which makes the type checked-`Sendable`: the compiler
/// verifies the isolation rather than taking an `@unchecked` assertion on trust.
final class EventBroadcaster<Event: Sendable>: Sendable {

    // MARK: Nested types

    private struct State {
        var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]
        var isFinished = false
    }

    // MARK: Properties

    /// Per-subscriber buffer depth.
    ///
    /// Bounded on purpose: the stream is optional to consume, and an unbounded buffer grows
    /// for the whole lifetime of the process when nobody drains it. Events describe
    /// entitlement changes, so when a slow subscriber overflows, the newest ones are the
    /// ones worth keeping.
    static var bufferSize: Int { 32 }

    private let state = Mutex(State())

    // MARK: Internal methods

    /// Creates a stream that receives every event yielded from now on.
    ///
    /// Events yielded before this call are not replayed; query the current state directly
    /// if you need it. Returns an already-finished stream once ``finish()`` has been called.
    func makeStream() -> AsyncStream<Event> {
        let id = UUID()
        let (stream, continuation) = AsyncStream.makeStream(
            of: Event.self,
            bufferingPolicy: .bufferingNewest(Self.bufferSize)
        )

        let hasFinished = state.withLock { state -> Bool in
            guard !state.isFinished else { return true }

            state.continuations[id] = continuation

            return false
        }

        guard !hasFinished else {
            continuation.finish()

            return stream
        }

        // Drop the continuation when the subscriber stops iterating or is cancelled,
        // otherwise the registry grows for every screen that ever observed the stream.
        // Assigning to an already-terminated continuation runs the handler immediately,
        // which covers a subscriber that went away during registration.
        continuation.onTermination = { [weak self] _ in
            self?.remove(id)
        }

        return stream
    }
    /// Sends one event to every active subscriber.
    func yield(_ event: Event) {
        // Read the targets under the lock, then deliver outside it: delivery can terminate a
        // stream, and the resulting `onTermination` calls back into `remove(_:)`, which takes
        // the same lock.
        let targets = state.withLock { Array($0.continuations.values) }
        for continuation in targets {
            continuation.yield(event)
        }
    }
    /// Ends every active stream and refuses new ones.
    func finish() {
        let targets = state.withLock { state -> [AsyncStream<Event>.Continuation] in
            state.isFinished = true
            let continuations = Array(state.continuations.values)
            state.continuations.removeAll()

            return continuations
        }
        for continuation in targets {
            continuation.finish()
        }
    }
    /// Number of registered subscribers. Exists so tests can observe cleanup.
    var subscriberCount: Int {
        state.withLock { $0.continuations.count }
    }

    // MARK: Private methods

    private func remove(_ id: UUID) {
        state.withLock { _ = $0.continuations.removeValue(forKey: id) }
    }
}
