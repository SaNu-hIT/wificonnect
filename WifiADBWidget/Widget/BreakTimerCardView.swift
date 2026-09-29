import SwiftUI

/// Flip-clock style break timer, used by both the widget and the app. `now` drives the countdown.
struct BreakTimerCardView: View {
    let state: TimerState
    let now: Date

    var body: some View {
        let phase = state.phase(at: now)
        HStack(spacing: 16) {
            FlipDigitsView(state: state, now: now, phase: phase)
            VStack(alignment: .leading, spacing: 6) {
                switch phase {
                case .idle:
                    Text("Break timer").font(.headline)
                    Text("Minutes between breaks").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        ForEach(TimerStore.presets, id: \.self) { m in
                            Button(intent: StartBreakTimerIntent(minutes: m)) { Text("\(m)") }
                        }
                    }
                case .running:
                    Text("Next break").font(.headline)
                    Text("Ends at \(state.end.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                    Button(intent: StopBreakTimerIntent()) { Text("Stop") }
                case .prompt:
                    Text("Time to move!").font(.headline)
                    Text(state.activity).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Button(intent: AnswerBreakIntent(result: "done")) { Text("Done") }
                        Button(intent: AnswerBreakIntent(result: "skipped")) { Text("Skip") }
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }
}

/// Dark split card with big digits. While running, the text is a live countdown, so the widget
/// updates every second without extra timeline entries.
struct FlipDigitsView: View {
    let state: TimerState
    let now: Date
    let phase: TimerState.Phase

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12))
            digits
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(phase == .prompt ? Color.orange : Color(white: 0.85))
                .opacity(phase == .idle ? 0.4 : 1)
                .padding(.horizontal, 8)
            Rectangle().fill(.black).frame(height: 2)  // split line across the digits
        }
        .frame(width: 150, height: 80)
    }

    @ViewBuilder
    private var digits: some View {
        if phase == .running {
            Text(timerInterval: min(now, state.end)...state.end, countsDown: true, showsHours: false)
        } else {
            Text("00:00")
        }
    }
}
