import Foundation

public struct ObservationUpdate: Sendable, Equatable {
    public let snapshot: SystemSnapshot
    public let changeSummary: ChangeSummary
    public let sampleNumber: Int

    public init(snapshot: SystemSnapshot, changeSummary: ChangeSummary, sampleNumber: Int) {
        self.snapshot = snapshot
        self.changeSummary = changeSummary
        self.sampleNumber = sampleNumber
    }
}

public final class ObservationSession {
    private let observer: ResourceObserver
    private var history: RollingHistory<SystemSnapshot>
    private var sampleNumber = 0

    public init(
        topProcessLimit: Int = 3,
        historyCapacity: Int = 60,
        observer: ResourceObserver? = nil
    ) {
        self.observer = observer ?? ResourceObserver(topProcessLimit: topProcessLimit)
        self.history = RollingHistory<SystemSnapshot>(capacity: historyCapacity)
    }

    public func nextUpdate() throws -> ObservationUpdate {
        let snapshot = try observer.sample()
        history.append(snapshot)
        sampleNumber += 1

        let changeSummary = HistoryAnalyzer.summarize(
            current: snapshot,
            history: history.items
        )

        return ObservationUpdate(
            snapshot: snapshot,
            changeSummary: changeSummary,
            sampleNumber: sampleNumber
        )
    }
}
