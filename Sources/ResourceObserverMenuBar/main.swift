import AppKit
import Foundation
import ResourceObserverCore

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate {
    private let session = ObservationSession(topProcessLimit: 3, historyCapacity: 60)
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?

    private lazy var loadItem = makeDisplayItem("System: --")
    private lazy var memoryItem = makeDisplayItem("Memory: --")
    private lazy var diagnosisItem = makeDisplayItem("Likely Cause: --")
    private lazy var changeItem = makeDisplayItem("Changed Recently: --")
    private lazy var processHeaderItem = makeDisplayItem("Top Processes", bold: true)
    private var processItems: [NSMenuItem] = []
    private lazy var updatedItem = makeDisplayItem("Updated: --")
    private let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
    private let quitItem = NSMenuItem(title: "Quit SriRadhaOS", action: #selector(quit), keyEquivalent: "q")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenu()
        statusItem.button?.title = "SR · --"
        statusItem.menu = menu
        refresh()

        timer = Timer.scheduledTimer(
            timeInterval: 2.0,
            target: self,
            selector: #selector(refreshTimerFired),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func setupMenu() {
        let titleItem = makeDisplayItem(ProjectInfo.name, bold: true)

        refreshItem.target = self
        quitItem.target = self

        menu.addItem(titleItem)
        menu.addItem(.separator())
        menu.addItem(loadItem)
        menu.addItem(memoryItem)
        menu.addItem(diagnosisItem)
        menu.addItem(changeItem)
        menu.addItem(.separator())
        menu.addItem(processHeaderItem)

        for _ in 0..<3 {
            let item = makeDisplayItem("  --")
            processItems.append(item)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(updatedItem)
        menu.addItem(refreshItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
    }

    @objc private func refreshNow() {
        refresh()
    }

    @objc private func refreshTimerFired() {
        refresh()
    }

    @objc private func noop() {}

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func refresh() {
        do {
            let update = try session.nextUpdate()
            apply(update: update)
        } catch {
            statusItem.button?.title = "SR !!!"
            setDisplayText(diagnosisItem, text: "Likely Cause: Failed to sample resources")
            setDisplayText(changeItem, text: "Changed Recently: \(error)")
        }
    }

    private func apply(update: ObservationUpdate) {
        let snapshot = update.snapshot
        let statusSymbol = PresentationFormatter.severitySymbol(for: snapshot.pressureLevel)
        let statusCPU = snapshot.totalCPUUsage.formatted(.number.precision(.fractionLength(0...0)))
        statusItem.button?.title = "SR \(statusSymbol) \(statusCPU)%"

        setSystemLine(snapshot)
        setDisplayText(memoryItem, text: "Memory: \(PresentationFormatter.shortMemoryLine(snapshot.memory))")
        setDisplayText(diagnosisItem, text: "Likely Cause: \(snapshot.diagnosis.summary)")
        setDisplayText(changeItem, text: "Changed Recently: \(update.changeSummary.summary)")
        setDisplayText(updatedItem, text: "Updated: \(snapshot.timestamp.formatted(date: .omitted, time: .standard))")

        for (index, item) in processItems.enumerated() {
            if index < snapshot.topProcesses.count {
                let process = snapshot.topProcesses[index]
                setProcessLine(item: item, index: index + 1, process: process)
            } else {
                setDisplayText(item, text: "  --")
            }
        }
    }

    private func makeDisplayItem(_ title: String, bold: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(noop), keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        setDisplayText(item, text: title, bold: bold)
        return item
    }

    private func setDisplayText(_ item: NSMenuItem, text: String, bold: Bool = false) {
        item.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.white,
                .font: bold ? NSFont.menuBarFont(ofSize: 15) : NSFont.menuFont(ofSize: 15)
            ]
        )
    }

    private func setSystemLine(_ snapshot: SystemSnapshot) {
        let percentText = snapshot.totalCPUUsage.formatted(.number.precision(.fractionLength(0...1))) + "%"
        let text = "System: \(PresentationFormatter.shortLoadLine(cpuUsage: snapshot.totalCPUUsage, level: snapshot.pressureLevel))"
        loadItem.attributedTitle = attributedText(
            fullText: text,
            highlights: [(percentText, colorForUsage(snapshot.totalCPUUsage))]
        )
    }

    private func setProcessLine(item: NSMenuItem, index: Int, process: ProcessSnapshot) {
        let cpuValue = process.cpuPercent.formatted(.number.precision(.fractionLength(0...1))) + "%"
        let memoryValue = process.memoryMB.formatted(.number.precision(.fractionLength(0...1))) + " MB"
        let text = "  \(index). \(process.name)  CPU \(cpuValue)  Mem \(memoryValue)"
        item.attributedTitle = attributedText(
            fullText: text,
            highlights: [(cpuValue, colorForUsage(process.cpuPercent))]
        )
    }

    private func attributedText(
        fullText: String,
        highlights: [(String, NSColor)] = []
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.menuFont(ofSize: 15)
            ]
        )

        for (substring, color) in highlights {
            let range = (fullText as NSString).range(of: substring)
            if range.location != NSNotFound {
                attributed.addAttribute(.foregroundColor, value: color, range: range)
            }
        }

        return attributed
    }

    private func colorForUsage(_ usage: Double) -> NSColor {
        switch usage {
        case ..<35:
            return NSColor.systemGreen
        case ..<70:
            return NSColor.systemYellow
        default:
            return NSColor.systemRed
        }
    }
}

private func runSelfTest() {
    let session = ObservationSession(topProcessLimit: 3, historyCapacity: 10)

    do {
        let update = try session.nextUpdate()
        let symbol = PresentationFormatter.severitySymbol(for: update.snapshot.pressureLevel)
        print("Menu Title: SR \(symbol) \(update.snapshot.totalCPUUsage.formatted(.number.precision(.fractionLength(0...0))))%")
        print("Likely Cause: \(update.snapshot.diagnosis.summary)")
        print("Changed Recently: \(update.changeSummary.summary)")
    } catch {
        fputs("Menu bar self-test failed: \(error)\n", stderr)
        exit(1)
    }
}

if CommandLine.arguments.contains("--self-test") {
    runSelfTest()
} else {
    let app = NSApplication.shared
    let delegate = MenuBarController()
    app.delegate = delegate
    app.run()
}
