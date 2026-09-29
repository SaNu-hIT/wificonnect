import Foundation
import WidgetKit

/// Must match the App Group in both entitlements files.
let appGroupID = "group.com.wifiadb.shared"

/// Defaults shared by the app and the widget. Also works unsigned (build.sh); it is then a plain suite.
let sharedDefaults = UserDefaults(suiteName: appGroupID) ?? .standard

/// ~/Library/Group Containers/<app group>/ — the only place both the app and the sandboxed widget can write.
let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    ?? FileManager.default.temporaryDirectory

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

let sharedEncoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.prettyPrinted, .sortedKeys]
    return e
}()

let sharedDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
}()

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
    static let logURL = sharedContainer.appendingPathComponent("activity.json")

    static func load() -> TimerState {
        guard let data = sharedDefaults.data(forKey: stateKey),
              let state = try? sharedDecoder.decode(TimerState.self, from: data) else { return TimerState() }
        return state
    }

    static func save(_ state: TimerState) {
        sharedDefaults.set(try? sharedEncoder.encode(state), forKey: stateKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func start(minutes: Int) {
        // Rotate through the activities so consecutive prompts differ.
        let n = sharedDefaults.integer(forKey: "activityIndex")
        sharedDefaults.set(n + 1, forKey: "activityIndex")
        let now = Date()
        save(TimerState(phase: .running, minutes: minutes, start: now,
                        end: now.addingTimeInterval(TimeInterval(minutes * 60)),
                        activity: activities[n % activities.count]))
    }

    static func stop() {
        save(TimerState())
    }

    /// Logs the answer to the activity prompt and restarts the same duration.
    /// Ignored unless a prompt is showing, e.g. a stale widget tapped after the panel stopped the timer.
    static func answer(_ result: String) {
        let state = load()
        guard state.phase(at: Date()) == .prompt, state.minutes > 0 else { return }
        appendLog(ActivityEntry(start: state.start, end: Date(), minutes: state.minutes,
                                activity: state.activity, result: result))
        start(minutes: state.minutes)
    }

    private static func appendLog(_ entry: ActivityEntry) {
        var entries = (try? Data(contentsOf: logURL)).flatMap { try? sharedDecoder.decode([ActivityEntry].self, from: $0) } ?? []
        entries.append(entry)
        try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? sharedEncoder.encode(entries).write(to: logURL)
    }
}
