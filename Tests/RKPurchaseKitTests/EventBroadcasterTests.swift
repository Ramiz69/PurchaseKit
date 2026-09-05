//
//  EventBroadcasterTests.swift
//  RKPurchaseKitTests
//
//  Created by Ramiz Kichibekov on 11.05.2025.
//

import Testing
@testable import RKPurchaseKit

/// Covers the guarantees ``EventBroadcaster`` exists to provide: every subscriber sees
/// every event, and no subscriber buffers without limit.
@Suite("EventBroadcaster", .timeLimit(.minutes(1)))
struct EventBroadcasterTests {

    private struct Event: Sendable, Equatable {
        let number: Int
    }

    /// Regression test for the defect that motivated this type.
    ///
    /// A single shared `AsyncStream` has exactly one consumer, so two `for await` loops over
    /// it split the sequence — the first observer saw the odd events, the second the even
    /// ones, and each silently missed the rest.
    @Test("every subscriber receives every event")
    func broadcastsToAllSubscribers() async {
        let broadcaster = EventBroadcaster<Event>()
        let first = broadcaster.makeStream()
        let second = broadcaster.makeStream()

        let expected = Array(1...10)
        let firstReceived = Task { await collect(expected.count, from: first) }
        let secondReceived = Task { await collect(expected.count, from: second) }

        for number in expected {
            broadcaster.yield(Event(number: number))
        }

        #expect(await firstReceived.value == expected)
        #expect(await secondReceived.value == expected)
    }

    @Test("a subscriber that never drains keeps only the newest events")
    func boundsTheBuffer() async {
        let broadcaster = EventBroadcaster<Event>()
        let stream = broadcaster.makeStream()

        let overflow = EventBroadcaster<Event>.bufferSize * 100
        for number in 1...overflow {
            broadcaster.yield(Event(number: number))
        }
        broadcaster.finish()

        var received: [Int] = []
        for await event in stream {
            received.append(event.number)
        }

        #expect(received.count == EventBroadcaster<Event>.bufferSize)
        // `.bufferingNewest`: the most recent entitlement state is the one worth keeping.
        #expect(received.last == overflow)
    }

    @Test("a subscriber that goes away is unregistered")
    func releasesTerminatedSubscribers() async {
        let broadcaster = EventBroadcaster<Event>()
        #expect(broadcaster.subscriberCount == 0)

        do {
            let stream = broadcaster.makeStream()
            #expect(broadcaster.subscriberCount == 1)
            // Yield before iterating: `for await` on an empty, unfinished stream blocks on
            // the first element, so the loop body would never run.
            broadcaster.yield(Event(number: 1))
            for await _ in stream { break }
        }

        // Leaving the scope deinitialises the iterator, which terminates the continuation.
        // `onTermination` runs asynchronously, so give it a bounded window to land.
        await settle(untilTrue: { broadcaster.subscriberCount == 0 })

        #expect(broadcaster.subscriberCount == 0)
    }

    @Test("an abandoned subscriber does not stall the others")
    func abandonedSubscriberDoesNotBlockDelivery() async {
        let broadcaster = EventBroadcaster<Event>()
        _ = broadcaster.makeStream()
        let live = broadcaster.makeStream()

        broadcaster.yield(Event(number: 42))

        var received: Int?
        for await event in live {
            received = event.number
            break
        }

        #expect(received == 42)
    }

    @Test("finish ends live streams and refuses new ones")
    func finishClosesEverything() async {
        let broadcaster = EventBroadcaster<Event>()
        let live = broadcaster.makeStream()

        broadcaster.finish()

        var receivedAfterFinish: [Int] = []
        for await event in live {
            receivedAfterFinish.append(event.number)
        }
        #expect(receivedAfterFinish.isEmpty)

        var receivedOnLateStream: [Int] = []
        for await event in broadcaster.makeStream() {
            receivedOnLateStream.append(event.number)
        }
        #expect(receivedOnLateStream.isEmpty)
        #expect(broadcaster.subscriberCount == 0)
    }

    @Test("concurrent yields reach a subscriber intact")
    func survivesConcurrentYields() async {
        let broadcaster = EventBroadcaster<Event>()
        let stream = broadcaster.makeStream()
        let total = EventBroadcaster<Event>.bufferSize

        let received = Task { await collect(total, from: stream) }
        await withTaskGroup(of: Void.self) { group in
            for number in 1...total {
                group.addTask { broadcaster.yield(Event(number: number)) }
            }
        }

        #expect(await received.value.sorted() == Array(1...total))
    }

    // MARK: Helpers

    /// Polls `condition` briefly so a test does not depend on exact callback timing.
    private func settle(untilTrue condition: @Sendable () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }

            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func collect(_ count: Int, from stream: AsyncStream<Event>) async -> [Int] {
        var received: [Int] = []
        for await event in stream {
            received.append(event.number)
            if received.count == count { break }
        }

        return received
    }
}
