import Foundation

struct ProcessMetricsReader {
    private struct RawProcess {
        let pid: Int32
        let cpuPercent: Double
        let memoryMB: Double
        let name: String
    }

    func processCandidates(excluding excludedPIDs: Set<Int32>) throws -> [ProcessSnapshot] {
        let output = try shell(
            launchPath: "/bin/ps",
            arguments: ["-Aceo", "pid=,%cpu=,rss=,comm="]
        )

        let rows = output
            .split(whereSeparator: \.isNewline)
            .compactMap(parseProcess)
            .filter { !excludedPIDs.contains($0.pid) }
            .filter { $0.cpuPercent > 0.1 }

        return rows.map { row in
            ProcessSnapshot(
                pid: row.pid,
                identityKey: "pid-\(row.pid)",
                name: row.name,
                cpuPercent: row.cpuPercent,
                memoryMB: row.memoryMB,
                impactScore: ResourceScorer.impactScore(
                    cpuPercent: row.cpuPercent,
                    memoryMB: row.memoryMB
                )
            )
        }
    }

    private func parseProcess(line: Substring) -> RawProcess? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }

        let parts = trimmed.split(maxSplits: 3, whereSeparator: \.isWhitespace)
        guard parts.count == 4,
              let pid = Int32(parts[0]),
              let cpuPercent = Double(parts[1]),
              let rssKilobytes = Double(parts[2]) else {
            return nil
        }

        let name = String(parts[3]).split(separator: "/").last.map(String.init) ?? String(parts[3])
        return RawProcess(
            pid: pid,
            cpuPercent: cpuPercent,
            memoryMB: rssKilobytes / 1024.0,
            name: name
        )
    }

    private func shell(launchPath: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ResourceObserverError.commandFailed(
                command: ([launchPath] + arguments).joined(separator: " "),
                status: process.terminationStatus
            )
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}
