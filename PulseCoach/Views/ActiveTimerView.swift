import SwiftUI
import UIKit

public struct ActiveTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TimerViewModel
    @State private var showLockedToast: Bool = false

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
                // MARK: - Top Area
                topHeaderSection
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                Spacer(minLength: 16)

                // MARK: - Center Circular Progress Ring & Countdown
                centerRingSection
                    .padding(.horizontal, 28)

                Spacer(minLength: 16)

                // MARK: - Bottom Controls Area
                bottomControlsSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
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
            // Workout name & Total left pill
            HStack {
                Text(viewModel.workout.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)

                Spacer()

                Text(viewModel.formattedTotalRemaining)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1), in: Capsule())
                    .contentTransition(.numericText())
            }

            // Phase Title Badge
            Text(viewModel.currentPhaseType.displayTitle)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .tracking(1.5)
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
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 2)
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
                .animation(.linear(duration: 0.06), value: viewModel.ringProgress)

            // Center Countdown Display
            VStack(spacing: 8) {
                if viewModel.isCompleted {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(Color(red: 0.19, green: 0.82, blue: 0.35))
                        .padding(.bottom, 4)

                    Text("DONE!")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("\(viewModel.displaySeconds)")
                        .font(.system(size: 108, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(
                            viewModel.currentPhaseType == .getReady
                            ? Color.white
                            : Color.white
                        )
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: true))

                    if viewModel.isPaused {
                        Text("PAUSED")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .tracking(2.0)
                            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1), in: Capsule())
                    } else if viewModel.isControlsLocked {
                        Label("CONTROLS LOCKED", systemImage: "lock.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .padding(36)
        }
        .frame(maxWidth: 330, maxHeight: 330)
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Bottom Controls

    private var bottomControlsSection: some View {
        VStack(spacing: 16) {
            if showLockedToast && viewModel.isControlsLocked {
                Text("Controls locked — hold Lock icon in corner to unlock")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15))
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
        ZStack {
            // Center Main Controls (Pause & +10s during Rest/Transition Rest)
            HStack(spacing: 16) {
                Button {
                    guard !viewModel.isControlsLocked else {
                        flashLockedHint()
                        return
                    }
                    viewModel.pauseWorkout()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 20, weight: .bold))
                        Text("Pause")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(minWidth: 150)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 24)
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
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 24)
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

            // Corner Subtle Lock Button
            HStack {
                Spacer()
                cornerLockButton
            }
        }
    }

    private var pausedDecisionMenu: some View {
        VStack(spacing: 12) {
            if viewModel.isRestPhase {
                Button {
                    viewModel.addTenSecondsToRest()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add +10s to Current Rest")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(viewModel.currentPhaseType.ringColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(viewModel.currentPhaseType.badgeBackgroundColor, in: Capsule())
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
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.19, green: 0.82, blue: 0.35), in: Capsule())
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Button {
                    viewModel.restartWorkout()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .bold))
                        Text("Restart Workout")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(white: 0.18), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.stopAndCleanup()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                        Text("End Workout")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.27, blue: 0.23))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
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
                }
                .font(.system(size: 18, weight: .bold, design: .rounded))
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
                }
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(red: 0.19, green: 0.82, blue: 0.35), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Subtle Corner Lock Button

    private var cornerLockButton: some View {
        Group {
            if viewModel.isControlsLocked {
                // Require holding (0.65s) to unlock so accidental sweat taps don't unlock
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.15))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color(red: 1.0, green: 0.84, blue: 0.15).opacity(0.18))
                            .overlay(
                                Circle()
                                    .strokeBorder(Color(red: 1.0, green: 0.84, blue: 0.15).opacity(0.6), lineWidth: 1.5)
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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
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
