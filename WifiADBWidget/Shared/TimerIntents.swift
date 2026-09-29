import AppIntents

// Widget buttons run these; the app uses the same buttons so both stay in sync.

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
