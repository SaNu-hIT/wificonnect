import Foundation
import WidgetKit

/// Must match the App Group in both entitlements files.
let appGroupID = "group.com.wifiadb.shared"

struct TimerState: Codable, Equatable {
    enum Phase: String, Codable { case idle, running, prompt }
    var phase: Phase = .idle
    var minutes = 0
    var start = Date()
    var end = Date()
    var activity = ""

    /// A running timer whose end has passed is shown as the activity prompt.
    func phase(at date: Date) -> Phase {
        phase == .running && date >= end ? .prompt : phase
    }
}

struct ActivityEntry: Codable {
    let start: Date
    let end: Date
    let minutes: Int
    let activity: String
    let result: String  // "done" or "skipped"
}

/// Timer state shared between the app and the widget through the App Group.
enum TimerStore {
    static let presets = [15, 30, 45, 60]
    static let activities = [
        "Walk around for 5 minutes",
        "Do 10 push-ups",
        "Do 5 pull-ups",
        "Stretch for 3 minutes",
        "Do 20 squats",
        "Drink water and take a short walk",
    ]

    private static let stateKey = "timerState"
    private static var defaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// ~/Library/Group Containers/<app group>/activity.json
    static var logURL: URL {
        let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("activity.json")
    }

    static func load() -> TimerState {
        guard let data = defaults.data(forKey: stateKey),
              let state = try? decoder.decode(TimerState.self, from: data) else { return TimerState() }
        return state
    }

    static func save(_ state: TimerState) {
        defaults.set(try? encoder.encode(state), forKey: stateKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func start(minutes: Int) {
        // Rotate through the activities so consecutive prompts differ.
        let n = defaults.integer(forKey: "activityIndex")
        defaults.set(n + 1, forKey: "activityIndex")
        let now = Date()
        save(TimerState(phase: .running, minutes: minutes, start: now,
                        end: now.addingTimeInterval(TimeInterval(minutes * 60)),
                        activity: activities[n % activities.count]))
    }

    static func stop() {
        save(TimerState())
    }

    /// Logs the answer to the activity prompt and restarts the same duration.
    static func answer(_ result: String) {
        let state = load()
        appendLog(ActivityEntry(start: state.start, end: Date(), minutes: state.minutes,
                                activity: state.activity, result: result))
        start(minutes: state.minutes)
    }

    private static func appendLog(_ entry: ActivityEntry) {
        var entries = (try? Data(contentsOf: logURL)).flatMap { try? decoder.decode([ActivityEntry].self, from: $0) } ?? []
        entries.append(entry)
        try? encoder.encode(entries).write(to: logURL)
    }
}
