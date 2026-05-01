import Foundation

public struct RollingHistory<Element> {
    private let capacity: Int
    private var storage: [Element] = []

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    public var items: [Element] {
        storage
    }

    public mutating func append(_ element: Element) {
        storage.append(element)
        if storage.count > capacity {
            storage.removeFirst(storage.count - capacity)
        }
    }
}
