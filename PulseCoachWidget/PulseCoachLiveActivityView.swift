import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct PulseCoachLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PulseCoachActivityAttributes.self) { context in
            // Lock Screen / Banner Live Activity UI
            LockScreenLiveActivityBanner(
                workoutName: context.attributes.workoutName,
                state: context.state
            )
            .activityBackgroundTint(Color.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.phase.displayTitle)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(phaseTintColor(for: context.state.phase))
                        Text(context.state.counterText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    liveTimerText(for: context.state, fontSize: 24)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.workoutName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)

                        Spacer()

                        if context.state.phase != .done {
                            Button(intent: ToggleWorkoutPauseIntent()) {
                                Label(
                                    context.state.isPaused ? "Resume" : "Pause",
                                    systemImage: context.state.isPaused ? "play.fill" : "pause.fill"
                                )
                                .font(.caption.weight(.bold))
                            }
                            .tint(phaseTintColor(for: context.state.phase))
                        }
                    }
                }
            } compactLeading: {
                Text(shortPhaseLabel(for: context.state.phase))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(phaseTintColor(for: context.state.phase))
            } compactTrailing: {
                liveTimerText(for: context.state, fontSize: 13)
                    .frame(maxWidth: 46)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(phaseTintColor(for: context.state.phase))
            }
        }
    }
}

private struct LockScreenLiveActivityBanner: View {
    let workoutName: String
    let state: PulseCoachActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            // Left: Phase badge + Exercise/Rep counter
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(phaseTintColor(for: state.phase))
                        .frame(width: 8, height: 8)
                    Text(state.phase.displayTitle)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(phaseTintColor(for: state.phase))
                    if state.isPaused {
                        Text("PAUSED")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow, in: Capsule())
                    }
                }

                Text(state.counterText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(workoutName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            // Center-Right: Live Countdown Timer
            liveTimerText(for: state, fontSize: 34)

            // Right: Pause / Resume AppIntent Button
            if state.phase != .done {
                Button(intent: ToggleWorkoutPauseIntent()) {
                    Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(phaseTintColor(for: state.phase), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

@ViewBuilder
private func liveTimerText(
    for state: PulseCoachActivityAttributes.ContentState,
    fontSize: CGFloat
) -> some View {
    if state.phase == .done {
        Text("DONE")
            .font(.system(size: fontSize * 0.7, weight: .black, design: .rounded))
            .foregroundStyle(.green)
    } else if state.isPaused {
        Text(formatSeconds(state.pausedRemainingSeconds))
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.yellow)
    } else {
        Text(
            timerInterval: state.phaseStartDate...state.phaseEndDate,
            countsDown: true
        )
        .font(.system(size: fontSize, weight: .black, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .multilineTextAlignment(.trailing)
    }
}

private func formatSeconds(_ total: Int) -> String {
    let clamped = max(0, total)
    let m = clamped / 60
    let s = clamped % 60
    return String(format: "%d:%02d", m, s)
}

private func phaseTintColor(for phase: WorkoutPhaseType) -> Color {
    switch phase {
    case .getReady:
        return Color(red: 1.0, green: 0.84, blue: 0.15)
    case .work:
        return Color(red: 1.0, green: 0.23, blue: 0.19)
    case .rest:
        return Color(red: 0.19, green: 0.82, blue: 0.35)
    case .transitionRest:
        return Color(red: 0.04, green: 0.52, blue: 1.0)
    case .done:
        return Color.green
    }
}

private func shortPhaseLabel(for phase: WorkoutPhaseType) -> String {
    switch phase {
    case .getReady: return "PREP"
    case .work: return "WORK"
    case .rest: return "REST"
    case .transitionRest: return "LONG"
    case .done: return "DONE"
    }
}
