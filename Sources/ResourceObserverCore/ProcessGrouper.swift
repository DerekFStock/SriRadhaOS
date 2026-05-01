import Foundation

enum ProcessGrouper {
    private struct GroupBucket {
        let identityKey: String
        let displayName: String
        var members: [ProcessSnapshot]
    }

    static func group(_ processes: [ProcessSnapshot]) -> [ProcessSnapshot] {
        var buckets: [String: GroupBucket] = [:]

        for process in processes {
            let group = grouping(for: process.name)

            if var bucket = buckets[group.identityKey] {
                bucket.members.append(process)
                buckets[group.identityKey] = bucket
            } else {
                buckets[group.identityKey] = GroupBucket(
                    identityKey: group.identityKey,
                    displayName: group.displayName,
                    members: [process]
                )
            }
        }

        return buckets.values.map { bucket in
            let totalCPU = bucket.members.reduce(0) { $0 + $1.cpuPercent }
            let totalMemory = bucket.members.reduce(0) { $0 + $1.memoryMB }
            let totalImpact = bucket.members.reduce(0) { $0 + $1.impactScore }
            let displayName =
                bucket.members.count > 1
                ? "\(bucket.displayName) (\(bucket.members.count) procs)"
                : bucket.displayName

            return ProcessSnapshot(
                pid: syntheticPID(for: bucket.identityKey),
                identityKey: bucket.identityKey,
                name: displayName,
                sourceCount: bucket.members.count,
                cpuPercent: totalCPU,
                memoryMB: totalMemory,
                impactScore: totalImpact
            )
        }
    }

    private static func grouping(for rawName: String) -> (identityKey: String, displayName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        if name.hasPrefix("Google Chrome Helper") {
            return ("google-chrome", "Google Chrome")
        }
        if name.hasPrefix("Codex Helper") {
            return ("codex", "Codex")
        }
        if name.hasPrefix("Xcode Helper") {
            return ("xcode", "Xcode")
        }
        if name.hasPrefix("Safari Web Content") || name.hasPrefix("Safari Networking") {
            return ("safari", "Safari")
        }
        if name.hasPrefix("Simulator") || name == "iOS Simulator" {
            return ("ios-simulator", "iOS Simulator")
        }

        return (name.lowercased(), name)
    }

    private static func syntheticPID(for key: String) -> Int32 {
        var hash: UInt32 = 2_166_136_261
        for byte in key.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return Int32(bitPattern: hash)
    }
}
