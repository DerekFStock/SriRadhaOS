import Foundation

public enum HistoryAnalyzer {
    public static func summarize(
        current: SystemSnapshot,
        history: [SystemSnapshot]
    ) -> ChangeSummary {
        guard let baseline = history.dropLast().last else {
            return ChangeSummary(
                summary: "Collecting baseline data for recent-change detection.",
                processSpike: nil
            )
        }

        if current.memory.pressureLevel > baseline.memory.pressureLevel {
            let currentSwap = current.memory.swapUsedMB
                .formatted(.number.precision(.fractionLength(0...1)))
            return ChangeSummary(
                summary: "Memory pressure rose since the last sample. Swap is now \(currentSwap) MB.",
                processSpike: nil
            )
        }

        let cpuDelta = current.totalCPUUsage - baseline.totalCPUUsage
        if cpuDelta >= 15 {
            if let spikingProcess = leadingProcessSpike(current: current, baseline: baseline) {
                let delta = cpuDelta.formatted(.number.precision(.fractionLength(0...1)))
                return ChangeSummary(
                    summary: "CPU load rose by \(delta) points, led by \(spikingProcess.name).",
                    processSpike: spikingProcess
                )
            }

            let delta = cpuDelta.formatted(.number.precision(.fractionLength(0...1)))
            return ChangeSummary(
                summary: "CPU load rose by \(delta) points since the previous sample.",
                processSpike: nil
            )
        }

        if let spikingProcess = leadingProcessSpike(current: current, baseline: baseline) {
            return ChangeSummary(
                summary: "\(spikingProcess.name) jumped noticeably since the previous sample.",
                processSpike: spikingProcess
            )
        }

        let swapDelta = current.memory.swapUsedMB - baseline.memory.swapUsedMB
        if swapDelta >= 128 {
            let delta = swapDelta.formatted(.number.precision(.fractionLength(0...1)))
            return ChangeSummary(
                summary: "Swap usage increased by \(delta) MB in the last sample window.",
                processSpike: nil
            )
        }

        return ChangeSummary(
            summary: "No major change detected in the last sample window.",
            processSpike: nil
        )
    }

    private static func leadingProcessSpike(
        current: SystemSnapshot,
        baseline: SystemSnapshot
    ) -> ProcessSnapshot? {
        let baselineByKey = Dictionary(uniqueKeysWithValues: baseline.topProcesses.map { ($0.identityKey, $0) })

        return current.topProcesses
            .map { process -> (ProcessSnapshot, Double) in
                let baselineCPU = baselineByKey[process.identityKey]?.cpuPercent ?? 0
                return (process, process.cpuPercent - baselineCPU)
            }
            .filter { _, delta in delta >= 20 }
            .sorted { lhs, rhs in lhs.1 > rhs.1 }
            .first?
            .0
    }
}
