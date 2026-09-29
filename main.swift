import AppKit

struct Device {
    let serial: String
    let state: String
    let model: String
    var isWireless: Bool { serial.contains(":") || serial.contains("._adb-tls-connect.") }
}

// GUI apps don't inherit the shell PATH, so look in the usual install locations.
let adbPath: String? = [
    "/opt/homebrew/share/android-commandlinetools/platform-tools/adb",
    NSHomeDirectory() + "/Library/Android/sdk/platform-tools/adb",
    "/opt/homebrew/bin/adb",
    "/usr/local/bin/adb",
].first { FileManager.default.isExecutableFile(atPath: $0) }

/// Runs adb and returns its combined output. Output goes to a temp file instead of a pipe,
/// because an adb server daemon started by this call inherits stdout and would hold a pipe open forever.
@discardableResult
func adb(_ args: [String], timeout: TimeInterval = 10) -> String {
    guard let adbPath else { return "adb not found" }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: url.path, contents: nil)
    defer { try? FileManager.default.removeItem(at: url) }
    guard let handle = try? FileHandle(forWritingTo: url) else { return "cannot create temp file" }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: adbPath)
    p.arguments = args
    p.standardOutput = handle
    p.standardError = handle
    do { try p.run() } catch { return error.localizedDescription }
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { if p.isRunning { p.terminate() } }
    p.waitUntilExit()
    try? handle.close()
    if p.terminationReason == .uncaughtSignal { return "Timed out: adb \(args.joined(separator: " "))" }
    return ((try? String(contentsOf: url, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
}

func listDevices() -> [Device] {
    adb(["devices", "-l"]).split(separator: "\n").compactMap { line in
        if line.hasPrefix("*") || line.hasPrefix("List of") { return nil }
        let parts = line.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let model = parts.first { $0.hasPrefix("model:") }.map { String($0.dropFirst(6)) } ?? ""
        return Device(serial: String(parts[0]), state: String(parts[1]), model: model)
    }
}

func connectOK(_ out: String) -> Bool {
    out.contains("connected to") && !out.contains("cannot") && !out.contains("failed")
}

/// One wireless device as shown in the menu and the desktop widget: attached now, saved from before, or both.
struct WirelessRow {
    let addr: String
    let model: String
    let state: String
    let attached: Bool
    let isSaved: Bool
    var title: String { model.isEmpty ? addr : "\(model)  \(addr)" }
    var color: NSColor { state == "connected" ? .systemGreen : attached ? .systemOrange : .systemGray }
}

func dot(_ color: NSColor) -> NSImage? {
    NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(paletteColors: [color]).applying(.init(scale: .small)))
}

/// Button that runs a closure and responds to the first click even when the panel isn't key.
final class ActionButton: NSButton {
    private var handler: () -> Void = {}

    convenience init(_ title: String, enabled: Bool, _ handler: @escaping () -> Void) {
        self.init(title: title, target: nil, action: nil)
        self.handler = handler
        target = self
        action = #selector(fire)
        controlSize = .small
        font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        isEnabled = enabled
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    @objc private func fire() { handler() }
}

// MARK: Break timer

/// One two-digit flip card: dark card split in the middle, digits flip when the value changes.
final class FlipCard: NSView {
    static let cardWidth: CGFloat = 60
    static let cardHeight: CGFloat = 56
    private static let captionHeight: CGFloat = 14
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 40, weight: .heavy)

    private let card = CALayer()
    private let topStatic: (CALayer, CATextLayer)
    private let bottomStatic: (CALayer, CATextLayer)
    private let topFlap: (CALayer, CATextLayer)
    private let bottomFlap: (CALayer, CATextLayer)
    private let caption = CATextLayer()
    private(set) var value = ""

    private var texts: [CATextLayer] { [topStatic.1, bottomStatic.1, topFlap.1, bottomFlap.1] }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.cardWidth, height: Self.cardHeight + Self.captionHeight)
    }

    init(caption text: String) {
        topStatic = Self.half(top: true)
        bottomStatic = Self.half(top: false)
        topFlap = Self.half(top: true)
        bottomFlap = Self.half(top: false)
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        card.frame = CGRect(x: 0, y: Self.captionHeight, width: Self.cardWidth, height: Self.cardHeight)
        card.backgroundColor = NSColor.black.cgColor  // shows through as the split line
        card.cornerRadius = 6
        card.masksToBounds = true
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / 250
        card.sublayerTransform = perspective
        // Flaps rotate around the split line: top flap hinges on its bottom edge, bottom flap on its top edge.
        topFlap.0.anchorPoint = CGPoint(x: 0.5, y: 0)
        topFlap.0.frame = topStatic.0.frame
        bottomFlap.0.anchorPoint = CGPoint(x: 0.5, y: 1)
        bottomFlap.0.frame = bottomStatic.0.frame
        topFlap.0.isHidden = true
        bottomFlap.0.isHidden = true
        for (container, _) in [topStatic, bottomStatic, topFlap, bottomFlap] { card.addSublayer(container) }
        layer?.addSublayer(card)

        caption.string = text
        caption.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        caption.fontSize = 9
        caption.alignmentMode = .center
        caption.foregroundColor = NSColor.secondaryLabelColor.cgColor
        caption.frame = CGRect(x: 0, y: 0, width: Self.cardWidth, height: 11)
        layer?.addSublayer(caption)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        for t in texts + [caption] { t.contentsScale = scale }
    }

    /// A clipped container showing the top or bottom half of a full-height digit label.
    private static func half(top: Bool) -> (CALayer, CATextLayer) {
        let h = cardHeight / 2 - 0.5
        let container = CALayer()
        container.frame = CGRect(x: 0, y: top ? cardHeight / 2 + 0.5 : 0, width: cardWidth, height: h)
        container.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        container.masksToBounds = true
        container.isDoubleSided = false
        let text = CATextLayer()
        text.font = font
        text.fontSize = font.pointSize
        text.alignmentMode = .center
        text.foregroundColor = NSColor(white: 0.85, alpha: 1).cgColor
        text.contentsScale = 2
        // CATextLayer draws from its top edge; shift so the digits sit centred on the card.
        let lineHeight = font.ascender - font.descender
        let inset = (cardHeight - lineHeight) / 2 + 2
        text.frame = CGRect(x: 0, y: -container.frame.origin.y - inset, width: cardWidth, height: cardHeight)
        container.addSublayer(text)
        return (container, text)
    }

    func setDigitColor(_ color: NSColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for t in texts { t.foregroundColor = color.cgColor }
        CATransaction.commit()
    }

    func set(_ new: String, animated: Bool) {
        guard new != value else { return }
        let old = value
        value = new
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        guard animated, !old.isEmpty else {
            for t in texts { t.string = new }
            topFlap.0.isHidden = true
            bottomFlap.0.isHidden = true
            CATransaction.commit()
            return
        }
        topStatic.1.string = new
        bottomStatic.1.string = old
        topFlap.1.string = old
        bottomFlap.1.string = new
        topFlap.0.removeAllAnimations()
        bottomFlap.0.removeAllAnimations()
        topFlap.0.transform = CATransform3DIdentity
        bottomFlap.0.transform = CATransform3DMakeRotation(.pi / 2, 1, 0, 0)
        topFlap.0.isHidden = false
        bottomFlap.0.isHidden = false
        CATransaction.commit()

        // First half: the old top folds down to the split line…
        let fold = CABasicAnimation(keyPath: "transform.rotation.x")
        fold.fromValue = 0
        fold.toValue = -Double.pi / 2
        fold.duration = 0.16
        fold.timingFunction = CAMediaTimingFunction(name: .easeIn)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [self] in
            // …then the new bottom unfolds from the split line.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            topFlap.0.isHidden = true
            CATransaction.commit()
            let unfold = CABasicAnimation(keyPath: "transform.rotation.x")
            unfold.fromValue = Double.pi / 2
            unfold.toValue = 0
            unfold.duration = 0.16
            unfold.timingFunction = CAMediaTimingFunction(name: .easeOut)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setCompletionBlock { [self] in
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                bottomStatic.1.string = value
                bottomFlap.0.isHidden = true
                CATransaction.commit()
            }
            bottomFlap.0.transform = CATransform3DIdentity
            bottomFlap.0.add(unfold, forKey: "flip")
            CATransaction.commit()
        }
        topFlap.0.transform = CATransform3DMakeRotation(-.pi / 2, 1, 0, 0)
        topFlap.0.add(fold, forKey: "flip")
        CATransaction.commit()
    }
}

/// MIN and SEC flip cards side by side.
final class FlipClockView: NSStackView {
    private let mins = FlipCard(caption: "MIN")
    private let secs = FlipCard(caption: "SEC")

    init() {
        super.init(frame: .zero)
        orientation = .horizontal
        spacing = 6
        addArrangedSubview(mins)
        addArrangedSubview(secs)
        show(seconds: 0, animated: false)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(seconds total: Int, animated: Bool) {
        mins.set(String(format: "%02d", min(total / 60, 99)), animated: animated)
        secs.set(String(format: "%02d", total % 60), animated: animated)
    }

    enum Style { case dimmed, normal, alert }

    func setStyle(_ style: Style) {
        layer?.removeAnimation(forKey: "pulse")
        alphaValue = style == .dimmed ? 0.5 : 1
        let color: NSColor = style == .alert ? .systemOrange : NSColor(white: 0.85, alpha: 1)
        mins.setDigitColor(color)
        secs.setDigitColor(color)
        if style == .alert {
            wantsLayer = true
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1
            pulse.toValue = 0.3
            pulse.duration = 0.6
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            layer?.add(pulse, forKey: "pulse")
        }
    }
}

/// Break timer panel. State lives in TimerStore (shared with the widget), so this view polls it
/// every second and re-renders when the phase or the widget changed it.
final class BreakTimerView: NSView {
    private var state = TimerStore.load()
    private var shownPhase: TimerState.Phase?
    private var tick: Timer?

    private let clock = FlipClockView()
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let buttons = NSStackView()

    /// Called when the layout changes so the panel can resize.
    var onLayoutChange: () -> Void = {}
    /// Called when the countdown ends so the panel can be brought back if hidden.
    var onPrompt: () -> Void = {}

    init() {
        super.init(frame: .zero)
        title.font = .systemFont(ofSize: 12, weight: .medium)
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byWordWrapping
        detail.maximumNumberOfLines = 2
        buttons.spacing = 4

        let text = NSStackView(views: [title, detail, buttons])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 3
        let row = NSStackView(views: [clock, text])
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
        sync()
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.sync() }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func sync() {
        let now = Date()
        let latest = TimerStore.load()
        let phase = latest.phase(at: now)
        if latest != state || phase != shownPhase {
            state = latest
            if phase == .prompt, let previous = shownPhase, previous != .prompt {
                NSSound(named: "Glass")?.play()
                onPrompt()
            }
            shownPhase = phase
            render()
        }
        if phase == .running {
            clock.show(seconds: Int(max(0, state.end.timeIntervalSinceNow).rounded(.up)), animated: true)
        }
    }

    private func act(_ change: @escaping () -> Void) -> () -> Void {
        { [weak self] in change(); self?.sync() }
    }

    private func render() {
        buttons.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switch shownPhase ?? .idle {
        case .idle:
            title.stringValue = "Break timer"
            detail.stringValue = "Minutes between breaks"
            clock.setStyle(.dimmed)
            clock.show(seconds: 0, animated: false)
            for m in TimerStore.presets {
                buttons.addArrangedSubview(ActionButton("\(m)", enabled: true, act { TimerStore.start(minutes: m) }))
            }
        case .running:
            title.stringValue = "Next break"
            detail.stringValue = "Ends at " + state.end.formatted(date: .omitted, time: .shortened)
            clock.setStyle(.normal)
            clock.show(seconds: Int(max(0, state.end.timeIntervalSinceNow).rounded(.up)), animated: false)
            buttons.addArrangedSubview(ActionButton("Stop", enabled: true, act { TimerStore.stop() }))
        case .prompt:
            title.stringValue = "Time to move!"
            detail.stringValue = state.activity
            clock.setStyle(.alert)
            clock.show(seconds: 0, animated: false)
            buttons.addArrangedSubview(ActionButton("Done", enabled: true, act { TimerStore.answer("done") }))
            buttons.addArrangedSubview(ActionButton("Skip", enabled: true, act { TimerStore.answer("skipped") }))
        }
        onLayoutChange()
    }
}

/// Small always-on-top panel listing wireless devices with Reconnect / Disconnect buttons,
/// plus the break timer. Drag anywhere to move.
final class DesktopPanel: NSPanel {
    private let stack = NSStackView()
    private let devices = NSStackView()
    let timer = BreakTimerView()
    private var shown = ""

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        let bg = NSVisualEffectView()
        bg.material = .popover
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 12
        bg.layer?.masksToBounds = true
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 12, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bg.topAnchor),
            stack.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
        ])
        contentView = bg

        devices.orientation = .vertical
        devices.alignment = .leading
        devices.spacing = 8
        let separator = NSBox()
        separator.boxType = .separator
        add(devices)
        add(separator)
        add(timer)
        timer.onLayoutChange = { [weak self] in self?.fit() }

        if !setFrameUsingName("WifiADBPanel"), let screen = NSScreen.main?.visibleFrame {
            setFrameOrigin(NSPoint(x: screen.maxX - 300, y: screen.maxY - 120))
        }
        setFrameAutosaveName("WifiADBPanel")
        fit()
    }

    override var canBecomeKey: Bool { true }

    func update(rows: [WirelessRow], busy: Bool, app: App) {
        // Skip rebuilding when nothing visible changed (the status poll runs every 5s).
        let signature = "\(busy)|" + rows.map { "\($0.title)=\($0.state)" }.joined(separator: ",")
        guard signature != shown else { return }
        shown = signature
        devices.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let online = rows.filter { $0.state == "connected" }.count
        let header = NSStackView()
        let title = NSTextField(labelWithString: "Wireless ADB")
        title.font = .boldSystemFont(ofSize: 13)
        let count = NSTextField(labelWithString: busy ? "working…" : "\(online) connected")
        count.font = .systemFont(ofSize: 11)
        count.textColor = .secondaryLabelColor
        let close = ActionButton("", enabled: true) { app.setPanelVisible(false) }
        close.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Hide widget")
        close.isBordered = false
        header.addView(title, in: .leading)
        header.addView(count, in: .leading)
        header.addView(close, in: .trailing)
        addDeviceRow(header)

        if rows.isEmpty {
            let none = NSTextField(labelWithString: "No wireless devices")
            none.textColor = .secondaryLabelColor
            addDeviceRow(none)
        }
        for r in rows {
            let icon = NSImageView(image: dot(r.color) ?? NSImage())
            let name = NSTextField(labelWithString: r.title)
            name.font = .systemFont(ofSize: 12, weight: .medium)
            let state = NSTextField(labelWithString: r.state)
            state.font = .systemFont(ofSize: 11)
            state.textColor = .secondaryLabelColor
            let text = NSStackView(views: [name, state])
            text.orientation = .vertical
            text.alignment = .leading
            text.spacing = 1

            let row = NSStackView()
            row.addView(icon, in: .leading)
            row.addView(text, in: .leading)
            row.addView(ActionButton(r.attached ? "Reconnect" : "Connect", enabled: !busy) { app.reconnectDevice(r.addr) }, in: .trailing)
            if r.attached {
                row.addView(ActionButton("Disconnect", enabled: !busy) { app.disconnectDevice(r.addr) }, in: .trailing)
            }
            addDeviceRow(row)
        }
        fit()
    }

    /// Resizes the window to its content, keeping the top edge in place.
    private func fit() {
        stack.layoutSubtreeIfNeeded()
        let size = stack.fittingSize
        var f = frame
        f.origin.y += f.height - size.height
        f.size = size
        setFrame(f, display: true)
    }

    private func add(_ view: NSView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true
    }

    private func addDeviceRow(_ view: NSView) {
        devices.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: devices.widthAnchor).isActive = true
    }
}

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    var devices: [Device] = []
    var busy = false
    lazy var panel = DesktopPanel()

    /// Wireless addresses connected before (address -> model), so they can be reconnected after dropping.
    var saved: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "saved") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "saved") }
    }

    var panelVisible: Bool { UserDefaults.standard.object(forKey: "showPanel") as? Bool ?? true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self
        item.menu = menu
        panel.timer.onPrompt = { [weak self] in self?.setPanelVisible(true) }
        setPanelVisible(panelVisible)
        refresh()
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        syncWork()
        DispatchQueue.global().async {
            let list = listDevices()
            DispatchQueue.main.async {
                self.devices = list
                self.updateUI()
                self.runQueuedCommand()
            }
        }
    }

    func updateUI() {
        let rows = wirelessRows()
        let online = rows.filter { $0.state == "connected" }.count
        let symbol = busy ? "arrow.triangle.2.circlepath" : online > 0 ? "wifi" : "wifi.slash"
        item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Wireless ADB")
        item.button?.toolTip = "Wireless ADB: \(online) connected"
        if panelVisible { panel.update(rows: rows, busy: busy, app: self) }
        // Publish for the widget, which cannot run adb itself.
        DeviceStore.saveDevices(rows.map { DeviceInfo(addr: $0.addr, model: $0.model, state: $0.state, attached: $0.attached) })
    }

    /// Runs one command queued by the widget's buttons.
    func runQueuedCommand() {
        guard !busy, let cmd = DeviceStore.takeCommand() else { return }
        switch cmd.action {
        case "reconnect": reconnectDevice(cmd.addr)
        case "disconnect": disconnectDevice(cmd.addr)
        default: break
        }
    }

    // MARK: Work buddy

    static let workURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/WifiADB/work.json")
    private var workModified: Date?

    /// Publishes work.json to the widget whenever the file changes; creates an example if missing.
    func syncWork() {
        guard let modified = (try? FileManager.default.attributesOfItem(atPath: Self.workURL.path))?[.modificationDate] as? Date else {
            try? FileManager.default.createDirectory(at: Self.workURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? WorkStore.example.write(to: Self.workURL, atomically: true, encoding: .utf8)
            return
        }
        guard modified != workModified else { return }
        workModified = modified
        if let data = try? Data(contentsOf: Self.workURL), let work = try? WorkStore.decode(data) {
            WorkStore.save(work)
        }
    }

    @objc func openWorkAction(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Self.workURL)
    }

    func setPanelVisible(_ visible: Bool) {
        UserDefaults.standard.set(visible, forKey: "showPanel")
        if visible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        updateUI()
    }

    /// Attached wireless devices first, then saved addresses that are not attached.
    func wirelessRows() -> [WirelessRow] {
        let wireless = devices.filter(\.isWireless)
        let saved = self.saved
        let addrs = wireless.map(\.serial) + saved.keys.sorted().filter { a in !wireless.contains { $0.serial == a } }
        return addrs.map { addr in
            let dev = wireless.first { $0.serial == addr }
            let model = dev?.model.isEmpty == false ? dev!.model : saved[addr] ?? ""
            let state = dev.map { $0.state == "device" ? "connected" : $0.state } ?? "not connected"
            return WirelessRow(addr: addr, model: model, state: state, attached: dev != nil, isSaved: saved[addr] != nil)
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard adbPath != nil else {
            menu.addItem(NSMenuItem(title: "adb not found", action: nil, keyEquivalent: ""))
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            return
        }
        // Use the list from the 3s background poll; calling adb here would block the menu.
        updateUI()

        let rows = wirelessRows()
        let usb = devices.filter { !$0.isWireless }
        let online = rows.filter { $0.state == "connected" }.count
        menu.addItem(NSMenuItem(title: busy ? "Working…" : "\(online) wireless connected", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        menu.addItem(.sectionHeader(title: "Wi‑Fi"))
        if rows.isEmpty { menu.addItem(NSMenuItem(title: "None", action: nil, keyEquivalent: "")) }
        for r in rows {
            let row = NSMenuItem(title: "\(r.title)  —  \(r.state)", action: nil, keyEquivalent: "")
            row.image = dot(r.color)
            let sub = NSMenu()
            sub.addItem(action(r.attached ? "Reconnect" : "Connect", #selector(reconnectAction), r.addr))
            if r.attached { sub.addItem(action("Disconnect", #selector(disconnectAction), r.addr)) }
            if r.isSaved { sub.addItem(action("Forget", #selector(forgetAction), r.addr)) }
            row.submenu = sub
            menu.addItem(row)
        }

        if !usb.isEmpty {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: "USB"))
            for dev in usb {
                let title = "\(dev.model.isEmpty ? dev.serial : "\(dev.model)  \(dev.serial)")" + (dev.state == "device" ? "" : "  —  \(dev.state)")
                let row = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                if dev.state == "device" {
                    let sub = NSMenu()
                    sub.addItem(action("Enable Wi‑Fi debugging", #selector(enableWifiAction), dev.serial))
                    row.submenu = sub
                }
                menu.addItem(row)
            }
        }

        menu.addItem(.separator())
        let widget = action("Show Desktop Widget", #selector(togglePanelAction), nil)
        widget.state = panelVisible ? .on : .off
        menu.addItem(widget)
        menu.addItem(action("Open work.json", #selector(openWorkAction), nil))
        menu.addItem(action("Connect to IP…", #selector(connectToIPAction), nil))
        menu.addItem(action("Restart adb server", #selector(restartAction), nil))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    func action(_ title: String, _ selector: Selector, _ value: String?) -> NSMenuItem {
        let m = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        m.target = self
        m.representedObject = value
        return m
    }

    // MARK: Actions

    /// Runs `work` off the main thread; a non-nil result is shown as an error alert.
    func perform(_ work: @escaping () -> String?) {
        guard !busy else { return }
        busy = true
        updateUI()
        DispatchQueue.global().async {
            let error = work()
            let list = listDevices()
            DispatchQueue.main.async {
                self.busy = false
                self.devices = list
                self.updateUI()
                if let error { self.alert(error) }
            }
        }
    }

    func reconnectDevice(_ addr: String) {
        perform { self.reconnect(addr) }
    }

    func disconnectDevice(_ addr: String) {
        perform {
            let out = adb(["disconnect", addr])
            return out.contains("error") ? out : nil
        }
    }

    @objc func reconnectAction(_ sender: NSMenuItem) {
        guard let addr = sender.representedObject as? String else { return }
        reconnectDevice(addr)
    }

    @objc func disconnectAction(_ sender: NSMenuItem) {
        guard let addr = sender.representedObject as? String else { return }
        disconnectDevice(addr)
    }

    @objc func forgetAction(_ sender: NSMenuItem) {
        guard let addr = sender.representedObject as? String else { return }
        saved.removeValue(forKey: addr)
        updateUI()
    }

    @objc func togglePanelAction(_ sender: NSMenuItem) {
        setPanelVisible(!panelVisible)
    }

    @objc func enableWifiAction(_ sender: NSMenuItem) {
        guard let serial = sender.representedObject as? String else { return }
        perform {
            // Read the IP first: `tcpip` restarts adbd and briefly drops the USB connection.
            let ipOut = adb(["-s", serial, "shell", "ip", "-f", "inet", "addr", "show", "wlan0"])
            guard let r = ipOut.range(of: #"inet \d+\.\d+\.\d+\.\d+"#, options: .regularExpression) else {
                return "Could not read the phone's Wi‑Fi IP. Is it on Wi‑Fi?\n\n\(ipOut)"
            }
            let ip = ipOut[r].dropFirst(5)
            let out = adb(["-s", serial, "tcpip", "5555"])
            guard out.contains("restarting") else { return out }
            Thread.sleep(forTimeInterval: 2)
            return self.connect("\(ip):5555")
        }
    }

    @objc func connectToIPAction(_ sender: NSMenuItem) {
        let a = NSAlert()
        a.messageText = "Connect to device"
        a.informativeText = "IP or IP:port (default port 5555)"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "192.168.1.10:5555"
        a.accessoryView = field
        a.addButton(withTitle: "Connect")
        a.addButton(withTitle: "Cancel")
        a.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        var addr = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !addr.isEmpty else { return }
        if !addr.contains(":") { addr += ":5555" }
        perform { self.connect(addr) }
    }

    @objc func restartAction(_ sender: NSMenuItem) {
        perform {
            adb(["kill-server"])
            adb(["start-server"])
            return nil
        }
    }

    // MARK: adb operations (background thread)

    func connect(_ addr: String) -> String? {
        let out = adb(["connect", addr])
        guard connectOK(out) else { return out }
        let model = listDevices().first { $0.serial == addr }?.model ?? ""
        saved[addr] = model.isEmpty ? saved[addr] ?? "" : model
        return nil
    }

    func reconnect(_ addr: String) -> String? {
        adb(["disconnect", addr])
        guard let error = connect(addr) else { return nil }

        // Android 11+ wireless debugging picks a new port each time it is enabled; look it up via mDNS.
        let ip = addr.split(separator: ":").first.map(String.init) ?? addr
        let found = adb(["mdns", "services"]).split(separator: "\n")
            .filter { $0.contains("_adb-tls-connect._tcp") }
            .compactMap { $0.split(whereSeparator: \.isWhitespace).last.map(String.init) }
            .first { $0.hasPrefix(ip + ":") && $0 != addr }
        guard let found else { return error }
        if let error2 = connect(found) { return "\(error)\n\nAlso tried \(found) via mDNS:\n\(error2)" }
        let model = saved.removeValue(forKey: addr) ?? ""
        if saved[found]?.isEmpty != false { saved[found] = model }
        return nil
    }

    func alert(_ text: String) {
        let a = NSAlert()
        a.messageText = "Wireless ADB"
        a.informativeText = text.isEmpty ? "Unknown error" : text
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
