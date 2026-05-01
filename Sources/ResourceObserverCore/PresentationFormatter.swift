import Foundation

public enum PresentationFormatter {
    public static func severitySymbol(for level: ResourcePressureLevel) -> String {
        switch level {
        case .calm:
            return "·"
        case .elevated:
            return "!"
        case .high:
            return "!!"
        case .severe:
            return "!!!"
        }
    }

    public static func shortLoadLine(
        cpuUsage: Double,
        level: ResourcePressureLevel
    ) -> String {
        let cpu = cpuUsage.formatted(.number.precision(.fractionLength(0...1)))
        return "\(severitySymbol(for: level)) \(level.rawValue)  CPU \(cpu)%"
    }

    public static func shortMemoryLine(_ memory: MemorySnapshot) -> String {
        let swap = memory.swapUsedMB.formatted(.number.precision(.fractionLength(0...1)))
        return "\(severitySymbol(for: memory.pressureLevel)) \(memory.pressureLevel.rawValue)  Swap \(swap) MB"
    }
}
