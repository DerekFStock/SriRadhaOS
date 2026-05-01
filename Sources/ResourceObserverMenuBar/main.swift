import AppKit
import Foundation
import ResourceObserverCore

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate {
    private let session = ObservationSession(topProcessLimit: 3, historyCapacity: 60)
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?

    private let loadItem = NSMenuItem(title: "Load: --", action: nil, keyEquivalent: "")
    private let memoryItem = NSMenuItem(title: "Memory: --", action: nil, keyEquivalent: "")
    private let diagnosisItem = NSMenuItem(title: "Diagnosis: --", action: nil, keyEquivalent: "")
    private let changeItem = NSMenuItem(title: "Recent Change: --", action: nil, keyEquivalent: "")
    private let processHeaderItem = NSMenuItem(title: "Top Processes", action: nil, keyEquivalent: "")
    private var processItems: [NSMenuItem] = []
    private let updatedItem = NSMenuItem(title: "Updated: --", action: nil, keyEquivalent: "")
    private let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
    private let quitItem = NSMenuItem(title: "Quit SriRadhaOS", action: #selector(quit), keyEquivalent: "q")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenu()
        statusItem.button?.title = "SR --"
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
        let titleItem = NSMenuItem(title: ProjectInfo.name, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        processHeaderItem.isEnabled = false

        [loadItem, memoryItem, diagnosisItem, changeItem, updatedItem].forEach {
            $0.isEnabled = false
        }

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
            let item = NSMenuItem(title: "  --", action: nil, keyEquivalent: "")
            item.isEnabled = false
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func refresh() {
        do {
            let update = try session.nextUpdate()
            apply(update: update)
        } catch {
            statusItem.button?.title = "SR !"
            diagnosisItem.title = "Diagnosis: Failed to sample resources"
            changeItem.title = "Recent Change: \(error)"
        }
    }

    private func apply(update: ObservationUpdate) {
        let snapshot = update.snapshot
        statusItem.button?.title = "SR \(snapshot.totalCPUUsage.formatted(.number.precision(.fractionLength(0...0))))%"

        loadItem.title = "Load: \(snapshot.pressureLevel.rawValue) - CPU \(snapshot.totalCPUUsage.formatted(.number.precision(.fractionLength(0...1))))%"
        memoryItem.title =
            "Memory: \(snapshot.memory.pressureLevel.rawValue) - Swap \(snapshot.memory.swapUsedMB.formatted(.number.precision(.fractionLength(0...1)))) MB"
        diagnosisItem.title = "Diagnosis: \(snapshot.diagnosis.summary)"
        changeItem.title = "Recent Change: \(update.changeSummary.summary)"
        updatedItem.title = "Updated: \(snapshot.timestamp.formatted(date: .omitted, time: .standard))"

        for (index, item) in processItems.enumerated() {
            if index < snapshot.topProcesses.count {
                let process = snapshot.topProcesses[index]
                let cpu = process.cpuPercent.formatted(.number.precision(.fractionLength(0...1)))
                let memory = process.memoryMB.formatted(.number.precision(.fractionLength(0...1)))
                item.title = "  \(index + 1). \(process.name) - CPU \(cpu)% - Mem \(memory) MB"
            } else {
                item.title = "  --"
            }
        }
    }
}

private func runSelfTest() {
    let session = ObservationSession(topProcessLimit: 3, historyCapacity: 10)

    do {
        let update = try session.nextUpdate()
        print("Menu Title: SR \(update.snapshot.totalCPUUsage.formatted(.number.precision(.fractionLength(0...0))))%")
        print("Diagnosis: \(update.snapshot.diagnosis.summary)")
        print("Recent Change: \(update.changeSummary.summary)")
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
