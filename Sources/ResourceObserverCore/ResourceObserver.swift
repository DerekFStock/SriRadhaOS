import Darwin
import Darwin.Mach
import Foundation

public enum ResourceObserverError: Error {
    case failedToReadCPUStats(kern_return_t)
    case failedToReadMemoryStats(kern_return_t)
    case failedToReadPageSize(kern_return_t)
    case failedToReadSwapUsage(Int32)
    case commandFailed(command: String, status: Int32)
}

public final class ResourceObserver {
    private let processReader = ProcessMetricsReader()
    private let topProcessLimit: Int
    private var previousCPUTicks: host_cpu_load_info_data_t?

    public init(topProcessLimit: Int = 3) {
        self.topProcessLimit = max(1, topProcessLimit)
    }

    public func sample() throws -> SystemSnapshot {
        let totalCPUUsage = try readTotalCPUUsage()
        let memory = try readMemorySnapshot()
        let currentPID = Int32(ProcessInfo.processInfo.processIdentifier)
        let topProcesses = try processReader.topProcesses(
            limit: topProcessLimit,
            excluding: [currentPID]
        )
        let diagnosis = ResourceScorer.diagnosis(
            totalCPUUsage: totalCPUUsage,
            memory: memory,
            topProcesses: topProcesses
        )

        return SystemSnapshot(
            timestamp: Date(),
            totalCPUUsage: totalCPUUsage,
            memory: memory,
            pressureLevel: diagnosis.pressureLevel,
            topProcesses: topProcesses,
            diagnosis: diagnosis
        )
    }

    private func readTotalCPUUsage() throws -> Double {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(
                    mach_host_self(),
                    HOST_CPU_LOAD_INFO,
                    reboundPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            throw ResourceObserverError.failedToReadCPUStats(result)
        }

        defer {
            previousCPUTicks = info
        }

        guard let previous = previousCPUTicks else {
            previousCPUTicks = info
            Thread.sleep(forTimeInterval: 0.2)
            return try readTotalCPUUsage()
        }

        let user = Double(info.cpu_ticks.0 - previous.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1 - previous.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 - previous.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 - previous.cpu_ticks.3)
        let total = user + system + idle + nice

        guard total > 0 else {
            return 0
        }

        return ((user + system + nice) / total) * 100.0
    }

    private func readMemorySnapshot() throws -> MemorySnapshot {
        var pageSize: vm_size_t = 0
        let pageSizeResult = host_page_size(mach_host_self(), &pageSize)
        guard pageSizeResult == KERN_SUCCESS else {
            throw ResourceObserverError.failedToReadPageSize(pageSizeResult)
        }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let statsResult = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    reboundPointer,
                    &count
                )
            }
        }

        guard statsResult == KERN_SUCCESS else {
            throw ResourceObserverError.failedToReadMemoryStats(statsResult)
        }

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.stride
        let swapResult = withUnsafeMutablePointer(to: &swap) { pointer in
            sysctlbyname(
                "vm.swapusage",
                pointer,
                &swapSize,
                nil,
                0
            )
        }

        guard swapResult == 0 else {
            throw ResourceObserverError.failedToReadSwapUsage(errno)
        }

        let bytesPerMB = 1024.0 * 1024.0
        let totalMemoryMB = Double(ProcessInfo.processInfo.physicalMemory) / bytesPerMB
        let freeMB = Double(stats.free_count + stats.speculative_count) * Double(pageSize) / bytesPerMB
        let activeMB = Double(stats.active_count) * Double(pageSize) / bytesPerMB
        let inactiveMB = Double(stats.inactive_count) * Double(pageSize) / bytesPerMB
        let wiredMB = Double(stats.wire_count) * Double(pageSize) / bytesPerMB
        let compressedMB = Double(stats.compressor_page_count) * Double(pageSize) / bytesPerMB
        let usedMB = min(totalMemoryMB, activeMB + inactiveMB + wiredMB + compressedMB)
        let freeRatio = totalMemoryMB > 0 ? freeMB / totalMemoryMB : 0
        let swapUsedMB = Double(swap.xsu_used) / bytesPerMB
        let swapTotalMB = Double(swap.xsu_total) / bytesPerMB
        let pressureLevel = ResourceScorer.memoryPressureLevel(
            freeRatio: freeRatio,
            swapUsedMB: swapUsedMB
        )

        return MemorySnapshot(
            usedMB: usedMB,
            freeMB: freeMB,
            compressedMB: compressedMB,
            swapUsedMB: swapUsedMB,
            swapTotalMB: swapTotalMB,
            pressureLevel: pressureLevel
        )
    }
}
