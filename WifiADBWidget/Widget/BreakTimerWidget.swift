import SwiftUI
import WidgetKit

struct BreakTimerEntry: TimelineEntry {
    let date: Date
    let state: TimerState
}

struct BreakTimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> BreakTimerEntry {
        let now = Date()
        return BreakTimerEntry(date: now, state: TimerState(phase: .running, minutes: 25, start: now,
                                                            end: now.addingTimeInterval(25 * 60), activity: ""))
    }

    func getSnapshot(in context: Context, completion: @escaping (BreakTimerEntry) -> Void) {
        completion(BreakTimerEntry(date: Date(), state: TimerStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BreakTimerEntry>) -> Void) {
        let state = TimerStore.load()
        let now = Date()
        var entries = [BreakTimerEntry(date: now, state: state)]
        // Re-render at the end so the view switches to the activity prompt.
        if state.phase == .running, state.end > now {
            entries.append(BreakTimerEntry(date: state.end, state: state))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct BreakTimerWidgetView: View {
    let entry: BreakTimerEntry

    var body: some View {
        BreakTimerCardView(state: entry.state, now: entry.date)
            .containerBackground(.black, for: .widget)
    }
}

struct BreakTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BreakTimer", provider: BreakTimerProvider()) { entry in
            BreakTimerWidgetView(entry: entry)
        }
        .configurationDisplayName("Break Timer")
        .description("Flip-clock countdown that reminds you to move.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct WifiADBWidgetBundle: WidgetBundle {
    var body: some Widget {
        BreakTimerWidget()
    }
}
