//
//  RKEventBroadcaster.swift
//  RKPurchaseKit
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Foundation

/// Delivers every event to every active subscriber.
///
/// `AsyncStream` has exactly one consumer. Two `for await` loops over the *same* stream do
/// not each receive the full sequence — they split it, so one screen sees an event and the
/// other silently misses it. Handing out one shared stream therefore loses purchase events
/// as soon as a second observer appears. Instead each subscriber gets its own stream, and
/// this type keeps the live continuations so a single yield reaches all of them.
///
/// The class is `@unchecked Sendable` because every mutable member is guarded by `lock`.
/// `NSLock` rather than `Mutex` or `OSAllocatedUnfairLock` so the deployment targets stay
/// at iOS 15 / macOS 12.
final class EventBroadcaster<Event: Sendable>: @unchecked Sendable {

    // MARK: Properties

    /// Per-subscriber buffer depth.
    ///
    /// Bounded on purpose: the stream is optional to consume, and an unbounded buffer grows
    /// for the whole lifetime of the process when nobody drains it. Events describe
    /// entitlement changes, so when a slow subscriber overflows, the newest ones are the
    /// ones worth keeping.
    private static var bufferSize: Int { 32 }

    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]
    private var isFinished = false

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

        lock.lock()
        let hasFinished = isFinished
        if !hasFinished {
            continuations[id] = continuation
        }
        lock.unlock()

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
        lock.lock()
        let targets = Array(continuations.values)
        lock.unlock()

        // Yield outside the lock: delivery can terminate a stream, and the resulting
        // `onTermination` calls back into `remove(_:)` for the same lock.
        for continuation in targets {
            continuation.yield(event)
        }
    }
    /// Ends every active stream and refuses new ones.
    func finish() {
        lock.lock()
        isFinished = true
        let targets = Array(continuations.values)
        continuations.removeAll()
        lock.unlock()

        for continuation in targets {
            continuation.finish()
        }
    }

    // MARK: Private methods

    private func remove(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}
