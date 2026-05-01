import Foundation

public enum ResourcePressureLevel: String, Sendable {
    case calm = "Calm"
    case elevated = "Elevated"
    case high = "High"
    case severe = "Severe"
}

public enum Bottleneck: String, Sendable {
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case unknown = "Unknown"
}

public struct ProcessSnapshot: Sendable, Equatable {
    public let pid: Int32
    public let identityKey: String
    public let name: String
    public let sourceCount: Int
    public let cpuPercent: Double
    public let memoryMB: Double
    public let impactScore: Double

    public init(
        pid: Int32,
        identityKey: String,
        name: String,
        sourceCount: Int = 1,
        cpuPercent: Double,
        memoryMB: Double,
        impactScore: Double
    ) {
        self.pid = pid
        self.identityKey = identityKey
        self.name = name
        self.sourceCount = sourceCount
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.impactScore = impactScore
    }
}

public struct Diagnosis: Sendable, Equatable {
    public let summary: String
    public let pressureLevel: ResourcePressureLevel
    public let primaryBottleneck: Bottleneck

    public init(
        summary: String,
        pressureLevel: ResourcePressureLevel,
        primaryBottleneck: Bottleneck
    ) {
        self.summary = summary
        self.pressureLevel = pressureLevel
        self.primaryBottleneck = primaryBottleneck
    }
}

public struct MemorySnapshot: Sendable, Equatable {
    public let usedMB: Double
    public let freeMB: Double
    public let compressedMB: Double
    public let swapUsedMB: Double
    public let swapTotalMB: Double
    public let pressureLevel: ResourcePressureLevel

    public init(
        usedMB: Double,
        freeMB: Double,
        compressedMB: Double,
        swapUsedMB: Double,
        swapTotalMB: Double,
        pressureLevel: ResourcePressureLevel
    ) {
        self.usedMB = usedMB
        self.freeMB = freeMB
        self.compressedMB = compressedMB
        self.swapUsedMB = swapUsedMB
        self.swapTotalMB = swapTotalMB
        self.pressureLevel = pressureLevel
    }
}

public struct SystemSnapshot: Sendable, Equatable {
    public let timestamp: Date
    public let totalCPUUsage: Double
    public let memory: MemorySnapshot
    public let pressureLevel: ResourcePressureLevel
    public let topProcesses: [ProcessSnapshot]
    public let diagnosis: Diagnosis

    public init(
        timestamp: Date,
        totalCPUUsage: Double,
        memory: MemorySnapshot,
        pressureLevel: ResourcePressureLevel,
        topProcesses: [ProcessSnapshot],
        diagnosis: Diagnosis
    ) {
        self.timestamp = timestamp
        self.totalCPUUsage = totalCPUUsage
        self.memory = memory
        self.pressureLevel = pressureLevel
        self.topProcesses = topProcesses
        self.diagnosis = diagnosis
    }
}

public struct ChangeSummary: Sendable, Equatable {
    public let summary: String
    public let processSpike: ProcessSnapshot?

    public init(summary: String, processSpike: ProcessSnapshot?) {
        self.summary = summary
        self.processSpike = processSpike
    }
}
