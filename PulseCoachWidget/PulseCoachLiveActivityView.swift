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
            .id("lockscreen-\(context.state.updateSequence)")
            .activityBackgroundTint(Color.black.opacity(0.90))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.state.phase.displayTitle)
                            .font(.system(size: 13, weight: .heavy, design: .default))
                            .foregroundStyle(phaseTintColor(for: context.state.phase))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text(context.state.counterText)
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .id("expLead-\(context.state.updateSequence)")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    liveTimerText(for: context.state, fontSize: 22)
                        .frame(width: 66, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        Text(context.attributes.workoutName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)

                        Spacer()

                        if context.state.phase == .rest || context.state.phase == .transitionRest {
                            Button(intent: AddTenSecondsIntent()) {
                                Text("+10s")
                                    .font(.caption.weight(.heavy))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .tint(phaseTintColor(for: context.state.phase))
                        }

                        if context.state.phase != .done {
                            Button(intent: ToggleWorkoutPauseIntent()) {
                                Label(
                                    context.state.isPaused ? "Resume" : "Pause",
                                    systemImage: context.state.isPaused ? "play.fill" : "pause.fill"
                                )
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                            }
                            .tint(phaseTintColor(for: context.state.phase))
                        }
                    }
                    .id("expBot-\(context.state.updateSequence)")
                }
            } compactLeading: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(phaseTintColor(for: context.state.phase))
                        .frame(width: 8, height: 8)
                    Text(shortPhaseLabel(for: context.state.phase))
                        .font(.system(size: 12, weight: .heavy, design: .default))
                        .foregroundStyle(phaseTintColor(for: context.state.phase))
                        .lineLimit(1)
                }
                .id("compLead-\(context.state.updateSequence)")
            } compactTrailing: {
                liveTimerText(for: context.state, fontSize: 13)
                    .frame(width: 44, alignment: .trailing)
            } minimal: {
                // Dynamic Island minimal view (when Spotify occupies the other half):
                // Circular icon dynamically colored to match current phase (Red=Work, Green=Rest, Blue=Transition, Yellow=Prep)
                ZStack {
                    Circle()
                        .fill(phaseTintColor(for: context.state.phase).opacity(0.28))
                    Circle()
                        .strokeBorder(phaseTintColor(for: context.state.phase), lineWidth: 2.2)
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(phaseTintColor(for: context.state.phase))
                }
                .frame(width: 22, height: 22)
                .id("minimal-\(context.state.updateSequence)")
            }
            .keylineTint(phaseTintColor(for: context.state.phase))
        }
    }
}

private struct LockScreenLiveActivityBanner: View {
    let workoutName: String
    let state: PulseCoachActivityAttributes.ContentState

    private var isRestPhase: Bool {
        state.phase == .rest || state.phase == .transitionRest
    }

    var body: some View {
        HStack(spacing: 8) {
            // Left: Phase badge + Exercise/Rep counter (scales down slightly so right controls never truncate)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(phaseTintColor(for: state.phase))
                        .frame(width: 8, height: 8)

                    Text(state.phase.displayTitle)
                        .font(.system(size: 14, weight: .black, design: .default))
                        .foregroundStyle(phaseTintColor(for: state.phase))
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)

                    if state.isPaused {
                        Text("PAUSED")
                            .font(.system(size: 9, weight: .heavy, design: .default))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.yellow, in: Capsule())
                    }
                }

                Text(state.counterText)
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if state.isPaused || state.phase == .done {
                    Text("Total left: \(formatMMSS(state.totalRemainingSeconds))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    HStack(spacing: 4) {
                        Text("Total left:")
                            .fixedSize(horizontal: true, vertical: false)
                        Text(
                            timerInterval: state.phaseStartDate...max(state.phaseStartDate.addingTimeInterval(0.1), state.workoutEndDate),
                            countsDown: true
                        )
                        .id("total-\(state.updateSequence)")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center-Right: Live Countdown Timer (Dedicated width & high layout priority so "0:15" never truncates to "0:...")
            liveTimerText(for: state, fontSize: 28)
                .frame(width: 70, alignment: .trailing)
                .layoutPriority(2)

            // Right: +10s (during Rest/Transition Rest) & Pause/Resume AppIntent Buttons (Fixed size so "+10s" never shrinks to "+")
            if state.phase != .done {
                HStack(spacing: 6) {
                    if isRestPhase {
                        Button(intent: AddTenSecondsIntent()) {
                            Text("+10s")
                                .font(.system(size: 13, weight: .heavy, design: .default))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .frame(height: 36)
                                .background(phaseTintColor(for: state.phase), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: true, vertical: false)
                    }

                    Button(intent: ToggleWorkoutPauseIntent()) {
                        Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(
                                state.isPaused ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color.white,
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

@ViewBuilder
private func liveTimerText(
    for state: PulseCoachActivityAttributes.ContentState,
    fontSize: CGFloat
) -> some View {
    if state.phase == .done {
        Text("DONE")
            .font(.system(size: fontSize * 0.7, weight: .black, design: .default))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(.green)
    } else if state.isPaused {
        Text(formatSeconds(state.pausedRemainingSeconds))
            .font(.system(size: fontSize, weight: .black, design: .default))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(.yellow)
    } else {
        let safeEnd = max(state.phaseStartDate.addingTimeInterval(0.1), state.phaseEndDate)
        Text(
            timerInterval: state.phaseStartDate...safeEnd,
            countsDown: true
        )
        .id("timer-\(state.updateSequence)-\(state.phase.rawValue)")
        .font(.system(size: fontSize, weight: .black, design: .default))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
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

private func formatMMSS(_ total: Int) -> String {
    let clamped = max(0, total)
    let m = clamped / 60
    let s = clamped % 60
    return String(format: "%02d:%02d", m, s)
}

private func phaseTintColor(for phase: WorkoutPhaseType) -> Color {
    switch phase {
    case .getReady:
        return Color(red: 1.0, green: 0.84, blue: 0.15) // Yellow
    case .work:
        return Color(red: 1.0, green: 0.23, blue: 0.19) // Red
    case .rest:
        return Color(red: 0.19, green: 0.82, blue: 0.35) // Green
    case .transitionRest:
        return Color(red: 0.04, green: 0.52, blue: 1.0) // Blue
    case .done:
        return Color(red: 0.19, green: 0.82, blue: 0.35)
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
