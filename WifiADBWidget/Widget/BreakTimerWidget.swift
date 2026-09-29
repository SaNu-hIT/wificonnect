import SwiftUI
import WidgetKit

struct BreakTimerEntry: TimelineEntry {
    let date: Date
    let state: TimerState
    let devices: [DeviceInfo]
    let work: WorkData
}

struct BreakTimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> BreakTimerEntry {
        let now = Date()
        return BreakTimerEntry(
            date: now,
            state: TimerState(phase: .running, minutes: 25, start: now, end: now.addingTimeInterval(25 * 60), activity: ""),
            devices: [DeviceInfo(addr: "192.168.1.2:5555", model: "Pixel", state: "connected", attached: true)],
            work: WorkData(focus: "Project", projects: [WorkProject(name: "Project", status: "in progress", next: "Next step", due: nil)]))
    }

    func getSnapshot(in context: Context, completion: @escaping (BreakTimerEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BreakTimerEntry>) -> Void) {
        let now = Date()
        let first = entry(at: now)
        var entries = [first]
        // Re-render at the end so the view switches to the activity prompt.
        if first.state.phase == .running, first.state.end > now {
            entries.append(entry(at: first.state.end))
        }
        // Refresh after midnight so "days left" stays right.
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86400))
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    private func entry(at date: Date) -> BreakTimerEntry {
        BreakTimerEntry(date: date, state: TimerStore.load(), devices: DeviceStore.loadDevices(), work: WorkStore.load())
    }
}

struct BreakTimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BreakTimerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if family == .systemLarge {
                WorkBuddyView(work: entry.work)
                Divider().overlay(Color(white: 0.3))
            }
            BreakTimerCardView(state: entry.state, now: entry.date)
            if family == .systemLarge {
                Divider().overlay(Color(white: 0.3))
                DeviceListView(devices: entry.devices)
            }
        }
        .containerBackground(.black, for: .widget)
    }
}

/// Focused project on top, then the rest in one line each.
struct WorkBuddyView: View {
    let work: WorkData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Work buddy").font(.headline)
                Spacer()
                Text(Date(), format: .dateTime.weekday(.wide).day().month())
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let focus = work.focused {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(focus.name).font(.title3.bold())
                        if let status = focus.status {
                            Text(status).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        DueLabel(project: focus)
                    }
                    if let next = focus.next {
                        Text("Next: \(next)").font(.callout).lineLimit(2)
                    }
                }
                .padding(10)
                .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Text("Add projects to work.json (menu bar → Open work.json)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(work.others.prefix(3), id: \.name) { p in
                HStack(spacing: 6) {
                    Text(p.name).font(.system(size: 12, weight: .medium)).lineLimit(1).layoutPriority(1)
                    if let status = p.status {
                        Text("· \(status)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if let next = p.next {
                        Text("→ \(next)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    DueLabel(project: p)
                }
            }
        }
        .foregroundStyle(.white)
    }
}

struct DueLabel: View {
    let project: WorkProject

    var body: some View {
        if let days = project.daysLeft {
            Text(days < 0 ? "\(-days)d overdue" : days == 0 ? "due today" : "\(days)d left")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(days <= 1 ? Color.red : days <= 3 ? Color.orange : Color.secondary)
        }
    }
}

/// Wireless devices as published by the app. Buttons queue commands the app runs.
struct DeviceListView: View {
    let devices: [DeviceInfo]

    var body: some View {
        let online = devices.filter { $0.state == "connected" }.count
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Wireless ADB").font(.headline)
                Spacer()
                Text("\(online) connected").font(.caption).foregroundStyle(.secondary)
            }
            if devices.isEmpty {
                Text("No wireless devices").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(devices.prefix(2), id: \.addr) { d in
                HStack(spacing: 8) {
                    Circle().fill(color(d)).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(d.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Text(d.state).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(intent: DeviceCommandIntent(action: "reconnect", addr: d.addr)) {
                        Text(d.attached ? "Reconnect" : "Connect")
                    }
                    if d.attached {
                        Button(intent: DeviceCommandIntent(action: "disconnect", addr: d.addr)) { Text("Disconnect") }
                    }
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .foregroundStyle(.white)
    }

    private func color(_ d: DeviceInfo) -> Color {
        d.state == "connected" ? .green : d.attached ? .orange : .gray
    }
}

struct BreakTimerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BreakTimer", provider: BreakTimerProvider()) { entry in
            BreakTimerWidgetView(entry: entry)
        }
        .configurationDisplayName("Work Buddy")
        .description("Projects and next steps, break timer, wireless ADB devices. Medium size shows the timer only.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct WifiADBWidgetBundle: WidgetBundle {
    var body: some Widget {
        BreakTimerWidget()
    }
}
