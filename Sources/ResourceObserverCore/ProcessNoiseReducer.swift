import Foundation

enum ProcessNoiseReducer {
    private static let alwaysIgnoredNames: Set<String> = [
        "ps"
    ]

    private static let backgroundServiceNames: Set<String> = [
        "bird",
        "cloudd",
        "corespotlightd",
        "fileproviderd",
        "mds",
        "mds_stores",
        "mdworker_shared",
        "photoanalysisd",
        "suggestd"
    ]

    static func shouldIgnore(process: ProcessSnapshot) -> Bool {
        alwaysIgnoredNames.contains(process.name)
    }

    static func adjustedImpactScore(for process: ProcessSnapshot) -> Double {
        let baseScore = process.impactScore

        guard backgroundServiceNames.contains(process.name) else {
            return baseScore
        }

        if process.cpuPercent >= 90 || process.memoryMB >= 1_024 {
            return baseScore
        }

        return baseScore * 0.7
    }
}
