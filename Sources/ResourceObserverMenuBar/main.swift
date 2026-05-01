import AppKit
import Foundation
import ResourceObserverCore

@MainActor
final class MenuTextItemView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(width: CGFloat = 560) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.backgroundColor = .clear
        addSubview(label)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setAttributedText(_ text: NSAttributedString) {
        label.attributedStringValue = text
        let fitting = fittingSize
        frame.size = NSSize(width: fitting.width, height: max(fitting.height, 28))
    }
}

@MainActor
final class HistorySparklineView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private var samples: [Double] = []

    init(width: CGFloat = 560) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = .clear
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width),
            heightAnchor.constraint(equalToConstant: 78),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(samples: [Double], latestCPU: Double) {
        self.samples = Array(samples.suffix(20))
        let latest = latestCPU.formatted(.number.precision(.fractionLength(0...1)))
        titleLabel.attributedStringValue = NSAttributedString(
            string: "Recent CPU Trend  \(latest)%",
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.boldSystemFont(ofSize: 14)
            ]
        )
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let graphRect = NSRect(x: 18, y: 10, width: bounds.width - 36, height: 34)
        let backgroundPath = NSBezierPath(roundedRect: graphRect, xRadius: 6, yRadius: 6)
        NSColor(calibratedWhite: 1.0, alpha: 0.08).setFill()
        backgroundPath.fill()

        guard samples.count > 1 else {
            return
        }

        let maxSample = max(samples.max() ?? 0, 10)
        let minSample = min(samples.min() ?? 0, maxSample)
        let range = max(maxSample - minSample, 1)
        let stepX = graphRect.width / CGFloat(max(samples.count - 1, 1))

        let path = NSBezierPath()
        for (index, sample) in samples.enumerated() {
            let normalized = (sample - minSample) / range
            let x = graphRect.minX + (CGFloat(index) * stepX)
            let y = graphRect.minY + (CGFloat(normalized) * graphRect.height)
            let point = NSPoint(x: x, y: y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }

        color(for: samples.last ?? 0).setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    private func color(for usage: Double) -> NSColor {
        switch usage {
        case ..<35:
            return .systemGreen
        case ..<70:
            return .systemYellow
        default:
            return .systemRed
        }
    }
}

@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate {
    private let session = ObservationSession(topProcessLimit: 3, historyCapacity: 60)
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?

    private lazy var overallItem = makeDisplayItem("Overall: --")
    private lazy var cpuItem = makeDisplayItem("CPU: --")
    private lazy var memoryItem = makeDisplayItem("Memory: --")
    private lazy var diagnosisItem = makeDisplayItem("Likely Cause: --")
    private lazy var changeItem = makeDisplayItem("Changed Recently: --")
    private let historyItem = NSMenuItem()
    private lazy var processHeaderItem = makeDisplayItem("Top Processes", bold: true)
    private var processItems: [NSMenuItem] = []
    private lazy var updatedItem = makeDisplayItem("Updated: --")
    private let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
    private let quitItem = NSMenuItem(title: "Quit SriRadhaOS", action: #selector(quit), keyEquivalent: "q")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenu()
        setStatusTitle(
            severitySymbol: "·",
            severityColor: .white,
            percentageText: "--",
            percentageColor: .white
        )
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
        menu.addItem(overallItem)
        menu.addItem(cpuItem)
        menu.addItem(memoryItem)
        menu.addItem(diagnosisItem)
        menu.addItem(changeItem)
        menu.addItem(historyItem)
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
            setStatusTitle(
                severitySymbol: "!!!",
                severityColor: .systemRed,
                percentageText: "--",
                percentageColor: .white
            )
            setDisplayText(diagnosisItem, text: "Likely Cause: Failed to sample resources")
            setDisplayText(changeItem, text: "Changed Recently: \(error)")
        }
    }

    private func apply(update: ObservationUpdate) {
        let snapshot = update.snapshot
        let statusSymbol = PresentationFormatter.severitySymbol(for: snapshot.pressureLevel)
        let statusCPU = snapshot.totalCPUUsage.formatted(.number.precision(.fractionLength(0...0))) + "%"
        setStatusTitle(
            severitySymbol: statusSymbol,
            severityColor: colorForSeverity(snapshot.pressureLevel),
            percentageText: statusCPU,
            percentageColor: colorForUsage(snapshot.totalCPUUsage)
        )

        setOverallLine(snapshot)
        setCPULine(snapshot)
        setDisplayText(memoryItem, text: "Memory: \(PresentationFormatter.shortMemoryLine(snapshot.memory))")
        setDisplayText(diagnosisItem, text: "Likely Cause: \(snapshot.diagnosis.summary)")
        setDisplayText(changeItem, text: "Changed Recently: \(update.changeSummary.summary)")
        setHistoryView(historyItem, update: update)
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
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.white,
                .font: bold ? NSFont.boldSystemFont(ofSize: 15) : NSFont.menuFont(ofSize: 15)
            ]
        )
        setDisplayView(item, attributedText: attributed)
    }

    private func setOverallLine(_ snapshot: SystemSnapshot) {
        let severityText = PresentationFormatter.shortOverallLine(level: snapshot.pressureLevel)
        let text = "Overall: \(severityText)"
        setDisplayView(overallItem, attributedText: attributedText(
            fullText: text,
            highlights: [(severityText, colorForSeverity(snapshot.pressureLevel))]
        ))
    }

    private func setCPULine(_ snapshot: SystemSnapshot) {
        let cpuText = snapshot.totalCPUUsage.formatted(.number.precision(.fractionLength(0...1))) + "%"
        let text = "CPU: \(PresentationFormatter.shortCPULine(snapshot.totalCPUUsage))"
        setDisplayView(cpuItem, attributedText: attributedText(
            fullText: text,
            highlights: [(cpuText, colorForUsage(snapshot.totalCPUUsage))]
        ))
    }

    private func setProcessLine(item: NSMenuItem, index: Int, process: ProcessSnapshot) {
        let cpuValue = process.cpuPercent.formatted(.number.precision(.fractionLength(0...1))) + "%"
        let memoryValue = process.memoryMB.formatted(.number.precision(.fractionLength(0...1))) + " MB"
        let text = "  \(index). \(process.name)  CPU \(cpuValue)  Mem \(memoryValue)"
        setDisplayView(item, attributedText: attributedText(
            fullText: text,
            highlights: [(cpuValue, colorForUsage(process.cpuPercent))]
        ))
    }

    private func setDisplayView(_ item: NSMenuItem, attributedText: NSAttributedString) {
        let view = (item.view as? MenuTextItemView) ?? MenuTextItemView()
        view.setAttributedText(attributedText)
        item.view = view
    }

    private func setHistoryView(_ item: NSMenuItem, update: ObservationUpdate) {
        let view = (item.view as? HistorySparklineView) ?? HistorySparklineView()
        view.configure(
            samples: update.recentSnapshots.map(\.totalCPUUsage),
            latestCPU: update.snapshot.totalCPUUsage
        )
        item.view = view
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

    private func setStatusTitle(
        severitySymbol: String,
        severityColor: NSColor,
        percentageText: String,
        percentageColor: NSColor
    ) {
        guard let button = statusItem.button else {
            return
        }

        let fullText = "SR \(severitySymbol) \(percentageText)"
        let attributed = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.menuBarFont(ofSize: 14)
            ]
        )
        let severityRange = (fullText as NSString).range(of: severitySymbol)
        if severityRange.location != NSNotFound {
            attributed.addAttribute(.foregroundColor, value: severityColor, range: severityRange)
        }
        let percentageRange = (fullText as NSString).range(of: percentageText)
        if percentageRange.location != NSNotFound {
            attributed.addAttribute(.foregroundColor, value: percentageColor, range: percentageRange)
        }
        button.attributedTitle = attributed
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

    private func colorForSeverity(_ level: ResourcePressureLevel) -> NSColor {
        switch level {
        case .calm:
            return .systemGreen
        case .elevated:
            return .systemYellow
        case .high, .severe:
            return .systemRed
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
        print("Recent Samples: \(update.recentSnapshots.count)")
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
