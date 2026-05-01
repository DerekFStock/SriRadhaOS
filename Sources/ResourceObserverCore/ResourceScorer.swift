import Foundation

public enum ResourceScorer {
    public static func cpuPressureLevel(for totalCPUUsage: Double) -> ResourcePressureLevel {
        switch totalCPUUsage {
        case ..<35:
            .calm
        case ..<65:
            .elevated
        case ..<85:
            .high
        default:
            .severe
        }
    }

    public static func memoryPressureLevel(
        freeRatio: Double,
        swapUsedMB: Double
    ) -> ResourcePressureLevel {
        if swapUsedMB >= 4_096 || freeRatio < 0.03 {
            return .severe
        }
        if swapUsedMB >= 1_024 || freeRatio < 0.06 {
            return .high
        }
        if swapUsedMB >= 128 || freeRatio < 0.12 {
            return .elevated
        }
        return .calm
    }

    public static func combinedPressureLevel(
        cpuLevel: ResourcePressureLevel,
        memoryLevel: ResourcePressureLevel
    ) -> ResourcePressureLevel {
        max(cpuLevel, memoryLevel)
    }

    public static func impactScore(cpuPercent: Double, memoryMB: Double) -> Double {
        let cpuWeight = cpuPercent * 1.0
        let memoryWeight = min(memoryMB / 256.0, 20.0)
        return cpuWeight + memoryWeight
    }

    public static func diagnosis(
        totalCPUUsage: Double,
        memory: MemorySnapshot,
        topProcesses: [ProcessSnapshot]
    ) -> Diagnosis {
        let cpuLevel = cpuPressureLevel(for: totalCPUUsage)
        let level = combinedPressureLevel(
            cpuLevel: cpuLevel,
            memoryLevel: memory.pressureLevel
        )

        if memory.pressureLevel >= .high {
            let swap = memory.swapUsedMB.formatted(.number.precision(.fractionLength(0...1)))
            return Diagnosis(
                summary: "Memory pressure is high and swap usage is \(swap) MB. The system may feel sluggish even if CPU is not saturated.",
                pressureLevel: level,
                primaryBottleneck: .memory
            )
        }

        guard let leader = topProcesses.first else {
            return Diagnosis(
                summary: "No dominant process detected. The system looks relatively calm right now.",
                pressureLevel: level,
                primaryBottleneck: .unknown
            )
        }

        let summary: String
        switch cpuLevel {
        case .calm:
            summary = "\(leader.name) is currently the busiest visible process, but overall CPU pressure is low."
        case .elevated:
            summary = "\(leader.name) is contributing most to current CPU pressure."
        case .high, .severe:
            let roundedCPU = leader.cpuPercent.formatted(.number.precision(.fractionLength(0...1)))
            summary = "\(leader.name) is leading CPU pressure at \(roundedCPU)% CPU."
        }

        return Diagnosis(
            summary: summary,
            pressureLevel: level,
            primaryBottleneck: .cpu
        )
    }
}

extension ResourcePressureLevel: Comparable {
    public static func < (lhs: ResourcePressureLevel, rhs: ResourcePressureLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .calm:
            0
        case .elevated:
            1
        case .high:
            2
        case .severe:
            3
        }
    }
}
