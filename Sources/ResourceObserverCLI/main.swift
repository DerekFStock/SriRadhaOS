import Foundation
import ResourceObserverCore

struct CLIConfiguration {
    let sampleCount: Int?
    let interval: TimeInterval
    let topProcessLimit: Int

    static func parse(arguments: [String]) -> CLIConfiguration {
        var sampleCount: Int?
        var interval: TimeInterval = 2.0
        var topProcessLimit = 3
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--samples":
                if index + 1 < arguments.count, let value = Int(arguments[index + 1]), value > 0 {
                    sampleCount = value
                    index += 1
                }
            case "--interval":
                if index + 1 < arguments.count,
                   let value = Double(arguments[index + 1]),
                   value > 0 {
                    interval = value
                    index += 1
                }
            case "--top":
                if index + 1 < arguments.count,
                   let value = Int(arguments[index + 1]),
                   value > 0 {
                    topProcessLimit = value
                    index += 1
                }
            default:
                break
            }
            index += 1
        }

        return CLIConfiguration(
            sampleCount: sampleCount,
            interval: interval,
            topProcessLimit: topProcessLimit
        )
    }
}

let configuration = CLIConfiguration.parse(arguments: Array(CommandLine.arguments.dropFirst()))
let session = ObservationSession(topProcessLimit: configuration.topProcessLimit)

print(ProjectInfo.name)
print(ProjectInfo.mission)
print("Sampling every \(configuration.interval.formatted(.number.precision(.fractionLength(0...1)))) seconds.")
print("Press Ctrl-C to stop.\n")

var iteration = 0
while configuration.sampleCount == nil || iteration < configuration.sampleCount! {
    do {
        let update = try session.nextUpdate()
        render(update: update)
    } catch {
        fputs("Failed to sample system resources: \(error)\n", stderr)
    }

    iteration += 1
    if let sampleCount = configuration.sampleCount, iteration >= sampleCount {
        break
    }

    Thread.sleep(forTimeInterval: configuration.interval)
}

func render(update: ObservationUpdate) {
    let snapshot = update.snapshot
    let timestamp = snapshot.timestamp.formatted(
        date: .omitted,
        time: .standard
    )

    print("Sample \(update.sampleNumber) at \(timestamp)")
    print("Load: \(snapshot.pressureLevel.rawValue)")
    print("CPU: \(snapshot.totalCPUUsage.formatted(.number.precision(.fractionLength(0...1))))%")
    print(
        "Memory: \(snapshot.memory.pressureLevel.rawValue) " +
        "- Used \(snapshot.memory.usedMB.formatted(.number.precision(.fractionLength(0...1)))) MB" +
        " - Free \(snapshot.memory.freeMB.formatted(.number.precision(.fractionLength(0...1)))) MB"
    )
    print(
        "Swap: \(snapshot.memory.swapUsedMB.formatted(.number.precision(.fractionLength(0...1)))) MB" +
        " / \(snapshot.memory.swapTotalMB.formatted(.number.precision(.fractionLength(0...1)))) MB"
    )
    print("Top Processes:")

    if snapshot.topProcesses.isEmpty {
        print("  none above the current visibility threshold")
    } else {
        for (index, process) in snapshot.topProcesses.enumerated() {
            let cpu = process.cpuPercent.formatted(.number.precision(.fractionLength(0...1)))
            let memory = process.memoryMB.formatted(.number.precision(.fractionLength(0...1)))
            print("  \(index + 1). \(process.name) (pid \(process.pid)) - CPU \(cpu)% - Mem \(memory) MB")
        }
    }

    print("Diagnosis: \(snapshot.diagnosis.summary)")
    print("Recent Change: \(update.changeSummary.summary)\n")
}
