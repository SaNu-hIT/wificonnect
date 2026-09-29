import AppKit
import SwiftUI

/// Host app for the widget extension. Shows the same timer; the widget only appears in
/// Edit Widgets after this app has been run once.
@main
struct WifiADBApp: App {
    var body: some Scene {
        WindowGroup("Break Timer") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = TimerStore.load()
            VStack(alignment: .leading, spacing: 16) {
                BreakTimerCardView(state: state, now: context.date)
                    .padding(16)
                    .background(.black, in: RoundedRectangle(cornerRadius: 16))
                Text("Add the widget: right-click the desktop → Edit Widgets → Break Timer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .onChange(of: state.phase(at: context.date)) { _, phase in
                if phase == .prompt { NSSound(named: "Glass")?.play() }
            }
        }
    }
}
