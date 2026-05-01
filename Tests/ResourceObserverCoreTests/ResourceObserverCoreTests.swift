import Foundation
import Testing
@testable import ResourceObserverCore

@Test func projectInfoContainsPublicMetadata() {
    #expect(ProjectInfo.name == "SriRadhaOS")
    #expect(ProjectInfo.mission.contains("Mac"))
    #expect(ProjectInfo.firstMilestone.contains("CLI"))
}

@Test func pressureLevelThresholdsAreStable() {
    #expect(ResourceScorer.cpuPressureLevel(for: 10) == .calm)
    #expect(ResourceScorer.cpuPressureLevel(for: 40) == .elevated)
    #expect(ResourceScorer.cpuPressureLevel(for: 70) == .high)
    #expect(ResourceScorer.cpuPressureLevel(for: 90) == .severe)
}

@Test func diagnosisUsesTopProcessWhenAvailable() {
    let memory = MemorySnapshot(
        usedMB: 8_000,
        freeMB: 4_000,
        compressedMB: 200,
        swapUsedMB: 0,
        swapTotalMB: 1_024,
        pressureLevel: .calm
    )
    let diagnosis = ResourceScorer.diagnosis(
        totalCPUUsage: 82,
        memory: memory,
        topProcesses: [
            ProcessSnapshot(
                pid: 42,
                identityKey: "xcode",
                name: "Xcode",
                cpuPercent: 61,
                memoryMB: 1200,
                impactScore: 65
            )
        ]
    )

    #expect(diagnosis.primaryBottleneck == .cpu)
    #expect(diagnosis.pressureLevel == .high)
    #expect(diagnosis.summary.contains("Xcode"))
}

@Test func diagnosisPrefersMemoryWhenPressureIsHigh() {
    let memory = MemorySnapshot(
        usedMB: 15_000,
        freeMB: 300,
        compressedMB: 1_000,
        swapUsedMB: 2_048,
        swapTotalMB: 4_096,
        pressureLevel: .high
    )

    let diagnosis = ResourceScorer.diagnosis(
        totalCPUUsage: 25,
        memory: memory,
        topProcesses: []
    )

    #expect(diagnosis.primaryBottleneck == .memory)
    #expect(diagnosis.summary.contains("Memory pressure is high"))
}

@Test func rollingHistoryKeepsOnlyLatestItems() {
    var history = RollingHistory<Int>(capacity: 3)
    history.append(1)
    history.append(2)
    history.append(3)
    history.append(4)

    #expect(history.items == [2, 3, 4])
}

@Test func historyAnalyzerReportsBaselineWhenHistoryIsShort() {
    let snapshot = makeSnapshot(cpu: 20, topCPU: 35, processName: "Xcode")
    let summary = HistoryAnalyzer.summarize(current: snapshot, history: [snapshot])

    #expect(summary.summary.contains("Collecting baseline"))
}

@Test func historyAnalyzerDetectsCpuRiseAndLeader() {
    let baseline = makeSnapshot(cpu: 22, topCPU: 20, processName: "Xcode")
    let current = makeSnapshot(cpu: 48, topCPU: 58, processName: "Xcode")
    let summary = HistoryAnalyzer.summarize(current: current, history: [baseline, current])

    #expect(summary.summary.contains("CPU load rose"))
    #expect(summary.summary.contains("Xcode"))
    #expect(summary.processSpike?.name == "Xcode")
}

@Test func backgroundNoiseGetsDeprioritizedBelowHeavyForegroundWork() {
    let backgroundProcess = ProcessSnapshot(
        pid: 10,
        identityKey: "corespotlightd",
        name: "corespotlightd",
        cpuPercent: 50,
        memoryMB: 300,
        impactScore: ResourceScorer.impactScore(cpuPercent: 50, memoryMB: 300)
    )
    let foregroundProcess = ProcessSnapshot(
        pid: 11,
        identityKey: "xcode",
        name: "Xcode",
        cpuPercent: 45,
        memoryMB: 900,
        impactScore: ResourceScorer.impactScore(cpuPercent: 45, memoryMB: 900)
    )

    let adjustedBackground = ProcessNoiseReducer.adjustedImpactScore(for: backgroundProcess)
    let adjustedForeground = ProcessNoiseReducer.adjustedImpactScore(for: foregroundProcess)

    #expect(adjustedForeground > adjustedBackground)
}

@Test func observationSessionAdvancesSampleNumbers() throws {
    let session = ObservationSession(topProcessLimit: 3, historyCapacity: 5)

    let first = try session.nextUpdate()
    let second = try session.nextUpdate()

    #expect(first.sampleNumber == 1)
    #expect(second.sampleNumber == 2)
}

@Test func presentationFormatterUsesSeveritySymbols() {
    #expect(PresentationFormatter.severitySymbol(for: .calm) == "·")
    #expect(PresentationFormatter.severitySymbol(for: .elevated) == "!")
    #expect(PresentationFormatter.severitySymbol(for: .high) == "!!")
    #expect(PresentationFormatter.severitySymbol(for: .severe) == "!!!")
}

@Test func processGrouperCombinesChromeHelpers() {
    let grouped = ProcessGrouper.group([
        ProcessSnapshot(
            pid: 100,
            identityKey: "pid-100",
            name: "Google Chrome Helper",
            cpuPercent: 12,
            memoryMB: 220,
            impactScore: 14
        ),
        ProcessSnapshot(
            pid: 101,
            identityKey: "pid-101",
            name: "Google Chrome Helper (Renderer)",
            cpuPercent: 18,
            memoryMB: 430,
            impactScore: 21
        )
    ])

    #expect(grouped.count == 1)
    #expect(grouped[0].name.contains("Google Chrome"))
    #expect(grouped[0].sourceCount == 2)
    #expect(grouped[0].cpuPercent == 30)
}

private func makeSnapshot(
    cpu: Double,
    topCPU: Double,
    processName: String
) -> SystemSnapshot {
    let memory = MemorySnapshot(
        usedMB: 8_000,
        freeMB: 4_000,
        compressedMB: 200,
        swapUsedMB: 0,
        swapTotalMB: 1_024,
        pressureLevel: .calm
    )
    let process = ProcessSnapshot(
        pid: 42,
        identityKey: processName.lowercased(),
        name: processName,
        cpuPercent: topCPU,
        memoryMB: 500,
        impactScore: topCPU + 2
    )
    let diagnosis = ResourceScorer.diagnosis(
        totalCPUUsage: cpu,
        memory: memory,
        topProcesses: [process]
    )

    return SystemSnapshot(
        timestamp: Date(),
        totalCPUUsage: cpu,
        memory: memory,
        pressureLevel: diagnosis.pressureLevel,
        topProcesses: [process],
        diagnosis: diagnosis
    )
}
