import SwiftUI
import UIKit

public struct ActiveTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TimerViewModel
    @State private var showLockedToast: Bool = false
    @State private var showAdjustRemainingSheet: Bool = false

    public init(workout: Workout) {
        self._viewModel = State(initialValue: TimerViewModel(workout: workout))
    }

    public var body: some View {
        ZStack {
            // Pure Dark Studio Background with subtle radial glow matching current phase
            Color.black
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    viewModel.currentPhaseType.ringColor.opacity(0.14),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 340
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: viewModel.currentPhaseType)

            VStack(spacing: 0) {
                // MARK: - Top Area (Includes Lock Button cleanly separated from bottom controls)
                topHeaderSection
                    .padding(.top, 10)
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)

                // MARK: - Center Circular Progress Ring & Large Countdown
                centerRingSection
                    .padding(.horizontal, 24)

                Spacer(minLength: 12)

                // MARK: - Bottom Controls Area
                bottomControlsSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .sheet(isPresented: $showAdjustRemainingSheet) {
            AdjustRemainingSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            viewModel.startWorkout()
        }
        .onDisappear {
            viewModel.stopAndCleanup()
        }
    }

    // MARK: - Top Header

    private var topHeaderSection: some View {
        VStack(spacing: 12) {
            // Top Bar: Lock Toggle (Top-Left) • Workout Name • Total Left Pill (Top-Right)
            HStack(spacing: 10) {
                headerLockButton

                Text(viewModel.workout.name)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(viewModel.formattedTotalRemaining)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.1), in: Capsule())
                    .contentTransition(.numericText())
            }

            // Phase Title Badge
            Text(viewModel.currentPhaseType.displayTitle)
                .font(.system(size: 28, weight: .black, design: .default))
                .tracking(1.2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(viewModel.currentPhaseType.ringColor)
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(viewModel.currentPhaseType.badgeBackgroundColor)
                        .overlay(
                            Capsule()
                                .strokeBorder(viewModel.currentPhaseType.ringColor.opacity(0.45), lineWidth: 1.5)
                        )
                )
                .animation(.easeInOut(duration: 0.25), value: viewModel.currentPhaseType)

            // Exercise X/Y • Rep A/B Counter
            Text(viewModel.counterSubtitle)
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
        }
    }

    // MARK: - Center Progress Ring

    private var centerRingSection: some View {
        ZStack {
            // Muted Gray Background Track
            Circle()
                .stroke(
                    Color(white: 0.18),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round)
                )

            // Clockwise Filling Progress Ring
            Circle()
                .trim(from: 0.0, to: CGFloat(viewModel.ringProgress))
                .stroke(
                    viewModel.currentPhaseType.ringColor,
                    style: StrokeStyle(lineWidth: 22, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: viewModel.currentPhaseType.ringColor.opacity(0.45),
                    radius: 12,
                    x: 0,
                    y: 0
                )
                .animation(.linear(duration: 0.05), value: viewModel.ringProgress)

            // Center Countdown Display (Extra Large Non-Rounded Typography)
            VStack(spacing: 4) {
                if viewModel.isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(Color(red: 0.19, green: 0.82, blue: 0.35))
                        .padding(.bottom, 4)

                    Text("DONE!")
                        .font(.system(size: 48, weight: .black, design: .default))
                        .foregroundStyle(.white)
                } else {
                    Text("\(viewModel.displaySeconds)")
                        .font(.system(size: 138, weight: .black, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: true))

                    if viewModel.isPaused {
                        Text("PAUSED")
                            .font(.system(size: 14, weight: .heavy, design: .default))
                            .tracking(2.0)
                            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1), in: Capsule())
                    } else if viewModel.isControlsLocked {
                        Label("LOCKED", systemImage: "lock.fill")
                            .font(.system(size: 12, weight: .bold, design: .default))
                            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15).opacity(0.85))
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: 340, maxHeight: 340)
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Bottom Controls

    private var bottomControlsSection: some View {
        VStack(spacing: 14) {
            if showLockedToast && viewModel.isControlsLocked {
                Text("Controls locked — hold Lock icon in top-left to unlock")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .transition(.opacity)
            }

            if viewModel.isCompleted {
                completedControls
            } else if viewModel.isPaused {
                pausedDecisionMenu
            } else {
                activeRunningControls
            }
        }
    }

    private var activeRunningControls: some View {
        HStack(spacing: 14) {
            Button {
                guard !viewModel.isControlsLocked else {
                    flashLockedHint()
                    return
                }
                viewModel.pauseWorkout()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 19, weight: .bold))
                    Text("Pause")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(Color(white: 0.18))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .opacity(viewModel.isControlsLocked ? 0.38 : 1.0)

            if viewModel.isRestPhase {
                Button {
                    guard !viewModel.isControlsLocked else {
                        flashLockedHint()
                        return
                    }
                    viewModel.addTenSecondsToRest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .heavy))
                        Text("10s")
                            .font(.system(size: 20, weight: .heavy, design: .default))
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(.black)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 28)
                    .background(
                        Capsule()
                            .fill(viewModel.currentPhaseType.ringColor)
                    )
                }
                .buttonStyle(.plain)
                .opacity(viewModel.isControlsLocked ? 0.38 : 1.0)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var pausedDecisionMenu: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if viewModel.isRestPhase {
                    Button {
                        viewModel.addTenSecondsToRest()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("+10s Rest")
                                .font(.system(size: 15, weight: .bold, design: .default))
                                .lineLimit(1)
                        }
                        .foregroundStyle(viewModel.currentPhaseType.ringColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(viewModel.currentPhaseType.badgeBackgroundColor, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showAdjustRemainingSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Adjust Remaining")
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(red: 1.0, green: 0.84, blue: 0.15).opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                viewModel.resumeWorkout()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("Resume")
                        .font(.system(size: 19, weight: .bold, design: .default))
                        .lineLimit(1)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.19, green: 0.82, blue: 0.35), in: Capsule())
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    viewModel.restartWorkout()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .bold))
                        Text("Restart")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(white: 0.18), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.stopAndCleanup()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                        Text("End Workout")
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.27, blue: 0.23))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 1.0, green: 0.23, blue: 0.19).opacity(0.16), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var completedControls: some View {
        HStack(spacing: 14) {
            Button {
                viewModel.restartWorkout()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Restart")
                        .lineLimit(1)
                }
                .font(.system(size: 18, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(white: 0.18), in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.stopAndCleanup()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                    Text("Done")
                        .lineLimit(1)
                }
                .font(.system(size: 18, weight: .bold, design: .default))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.19, green: 0.82, blue: 0.35), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Top-Left Lock Controls Button

    private var headerLockButton: some View {
        Group {
            if viewModel.isControlsLocked {
                // Hold 0.65s to unlock so sweat / accidental taps never unlock
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Hold")
                        .font(.system(size: 12, weight: .bold, design: .default))
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15))
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(Color(red: 1.0, green: 0.84, blue: 0.15).opacity(0.18))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(red: 1.0, green: 0.84, blue: 0.15).opacity(0.6), lineWidth: 1.2)
                        )
                )
                .onLongPressGesture(minimumDuration: 0.65) {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isControlsLocked = false
                        showLockedToast = false
                    }
                } onPressingChanged: { isPressing in
                    if isPressing {
                        flashLockedHint()
                    }
                }
            } else {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isControlsLocked = true
                    }
                } label: {
                    Image(systemName: "lock.open")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Lock Controls")
            }
        }
    }

    private func flashLockedHint() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
        withAnimation {
            showLockedToast = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            withAnimation {
                showLockedToast = false
            }
        }
    }
}

// MARK: - Adjust Remaining Session Sheet (Session-Only Modifications)

private struct AdjustRemainingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TimerViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Live Remaining Time Summary Banner
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Session Remaining Time")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(.white.opacity(0.65))
                            Text(Workout.formatMMSS(viewModel.totalRemainingSeconds))
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(red: 0.19, green: 0.82, blue: 0.35))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(viewModel.counterSubtitle)
                                .font(.system(size: 14, weight: .bold, design: .default))
                                .foregroundStyle(.white)
                            Text("Applies to this session only")
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15))
                        }
                    }
                    .padding(16)
                    .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Total Number of Exercises
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Exercises")
                                .font(.system(size: 16, weight: .bold, design: .default))
                                .foregroundStyle(.white)
                            Text("Currently on Exercise \(viewModel.currentExercise)")
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        HStack(spacing: 14) {
                            Button {
                                viewModel.adjustSessionExerciseCount(by: -1)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(
                                        viewModel.sessionExerciseCount > viewModel.minAllowedExercises
                                        ? .white
                                        : .gray.opacity(0.35)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.sessionExerciseCount <= viewModel.minAllowedExercises)

                            Text("\(viewModel.sessionExerciseCount)")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(minWidth: 36)

                            Button {
                                viewModel.adjustSessionExerciseCount(by: 1)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Work Duration Adjustment
                    sessionDurationCard(
                        title: "Remaining Work Duration",
                        valueSeconds: viewModel.sessionWorkDuration,
                        color: Color(red: 1.0, green: 0.23, blue: 0.19),
                        onDelta: { viewModel.adjustSessionWorkDuration(by: $0) }
                    )

                    // Standard Rest Duration Adjustment
                    sessionDurationCard(
                        title: "Remaining Standard Rest",
                        valueSeconds: viewModel.sessionRestDuration,
                        color: Color(red: 0.19, green: 0.82, blue: 0.35),
                        onDelta: { viewModel.adjustSessionRestDuration(by: $0) }
                    )

                    // Transition Rest Duration Adjustment
                    if viewModel.workout.enableTransitionRest {
                        sessionDurationCard(
                            title: "Remaining Transition Rest",
                            valueSeconds: viewModel.sessionTransitionRestDuration,
                            color: Color(red: 0.04, green: 0.52, blue: 1.0),
                            onDelta: { viewModel.adjustSessionTransitionRestDuration(by: $0) }
                        )
                    }
                }
                .padding(16)
            }
            .background(Color(white: 0.07).ignoresSafeArea())
            .navigationTitle("Adjust Remaining")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sessionDurationCard(
        title: String,
        valueSeconds: Int,
        color: Color,
        onDelta: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(valueSeconds)s")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
            }

            HStack(spacing: 10) {
                deltaPillButton(label: "-10s", delta: -10, action: onDelta)
                deltaPillButton(label: "-5s", delta: -5, action: onDelta)
                Spacer()
                deltaPillButton(label: "+5s", delta: 5, action: onDelta)
                deltaPillButton(label: "+10s", delta: 10, action: onDelta)
            }
        }
        .padding(16)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func deltaPillButton(
        label: String,
        delta: Int,
        action: @escaping (Int) -> Void
    ) -> some View {
        Button {
            action(delta)
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .default))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 56)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .foregroundStyle(.white)
                .background(Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
