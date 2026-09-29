import AppIntents

// Widget buttons run these. The app compiles them too, so the system can hand them to the app.

struct StartBreakTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Break Timer"

    @Parameter(title: "Minutes")
    var minutes: Int

    init() {}
    init(minutes: Int) { self.minutes = minutes }

    func perform() async throws -> some IntentResult {
        TimerStore.start(minutes: minutes)
        return .result()
    }
}

struct StopBreakTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Break Timer"

    func perform() async throws -> some IntentResult {
        TimerStore.stop()
        return .result()
    }
}

struct AnswerBreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Answer Break Prompt"

    @Parameter(title: "Result")
    var result: String

    init() {}
    init(result: String) { self.result = result }

    func perform() async throws -> some IntentResult {
        TimerStore.answer(result)
        return .result()
    }
}

/// Queues a command for the menu bar app, launching it if needed (it has no window, so this is silent).
struct DeviceCommandIntent: AppIntent {
    static let title: LocalizedStringResource = "ADB Device Command"
    static let openAppWhenRun = true

    @Parameter(title: "Action")
    var action: String

    @Parameter(title: "Address")
    var addr: String

    init() {}
    init(action: String, addr: String) {
        self.action = action
        self.addr = addr
    }

    func perform() async throws -> some IntentResult {
        DeviceStore.enqueue(DeviceCommand(action: action, addr: addr))
        return .result()
    }
}
