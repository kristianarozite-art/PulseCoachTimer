import Foundation
import SwiftUI
import UIKit
import Observation

@MainActor
@Observable
public final class TimerViewModel {
    public let workout: Workout
    public private(set) var phases: [WorkoutPhaseStep] = []
    public private(set) var currentPhaseIndex: Int = 0
    public private(set) var currentPhaseType: WorkoutPhaseType = .getReady

    public private(set) var currentExercise: Int = 1
    public private(set) var totalExercises: Int = 1
    public private(set) var currentRep: Int = 1
    public private(set) var totalReps: Int = 1

    public private(set) var remainingTimeInPhase: TimeInterval = 0
    public private(set) var currentPhaseTotalDuration: TimeInterval = 1
    public private(set) var futurePhasesDuration: TimeInterval = 0

    public private(set) var isPaused: Bool = false
    public private(set) var isCompleted: Bool = false
    public var isControlsLocked: Bool = false

    private var phaseStartDate: Date = Date()
    private var phaseEndDate: Date = Date()
    private var pausedRemainingInPhase: TimeInterval = 0
    private var spokenCountdownSeconds: Set<Int> = []
    private var timer: Timer?
    private var notificationObserver: NSObjectProtocol?

    public init(workout: Workout) {
        self.workout = workout
        self.totalExercises = workout.exerciseCount
        self.totalReps = workout.repsPerExercise
        self.phases = workout.buildPhases()
        setupLiveActivityObserver()
    }

    // MARK: - Computed Display Properties

    public var displaySeconds: Int {
        if isCompleted {
            return 0
        }
        return max(0, Int(ceil(remainingTimeInPhase)))
    }

    public var ringProgress: Double {
        if isCompleted {
            return 1.0
        }
        guard currentPhaseTotalDuration > 0 else { return 0.0 }
        let elapsed = max(0, currentPhaseTotalDuration - remainingTimeInPhase)
        return min(1.0, max(0.0, elapsed / currentPhaseTotalDuration))
    }

    public var totalRemainingSeconds: Int {
        if isCompleted {
            return 0
        }
        return max(0, Int(ceil(remainingTimeInPhase + futurePhasesDuration)))
    }

    public var formattedTotalRemaining: String {
        "Total left: \(Workout.formatMMSS(totalRemainingSeconds))"
    }

    public var counterSubtitle: String {
        "Exercise \(currentExercise)/\(totalExercises) • Rep \(currentRep)/\(totalReps)"
    }

    public var isRestPhase: Bool {
        !isCompleted && (currentPhaseType == .rest || currentPhaseType == .transitionRest)
    }

    // MARK: - Workout Control Actions

    public func startWorkout() {
        UIApplication.shared.isIdleTimerDisabled = true
        AudioEngine.shared.startWorkoutAudioSession(spotifyBehavior: workout.spotifyBehavior)

        phases = workout.buildPhases()
        isPaused = false
        isCompleted = false
        isControlsLocked = false

        guard !phases.isEmpty else {
            completeWorkout()
            return
        }

        WorkoutLiveActivityBridge.shared.onTogglePause = { [weak self] in
            self?.togglePauseFromLiveActivity()
        }

        enterPhase(at: 0, anchorDate: Date(), isInitialStart: true)
        startRunLoopTimer()
    }

    public func pauseWorkout() {
        guard !isPaused, !isCompleted else { return }
        let now = Date()
        pausedRemainingInPhase = max(0, phaseEndDate.timeIntervalSince(now))
        remainingTimeInPhase = pausedRemainingInPhase
        isPaused = true
        stopRunLoopTimer()
        triggerImpactHaptic(.medium)
        syncLiveActivity()
    }

    public func resumeWorkout() {
        guard isPaused, !isCompleted else { return }
        let now = Date()
        phaseEndDate = now.addingTimeInterval(pausedRemainingInPhase)
        phaseStartDate = phaseEndDate.addingTimeInterval(-currentPhaseTotalDuration)
        remainingTimeInPhase = pausedRemainingInPhase
        isPaused = false
        triggerImpactHaptic(.light)
        startRunLoopTimer()
        syncLiveActivity()
    }

    public func togglePauseFromLiveActivity() {
        if isPaused {
            resumeWorkout()
        } else {
            pauseWorkout()
        }
    }

    public func restartWorkout() {
        triggerImpactHaptic(.medium)
        stopRunLoopTimer()
        startWorkout()
    }

    public func addTenSecondsToRest() {
        guard isRestPhase, !isCompleted else { return }
        triggerImpactHaptic(.rigid)

        currentPhaseTotalDuration += 10.0
        if isPaused {
            pausedRemainingInPhase += 10.0
            remainingTimeInPhase = pausedRemainingInPhase
        } else {
            phaseEndDate = phaseEndDate.addingTimeInterval(10.0)
            remainingTimeInPhase = max(0, phaseEndDate.timeIntervalSince(Date()))
        }

        // Re-allow 3-2-1 countdown if adding +10s pushed remaining time above 3 seconds
        if remainingTimeInPhase > 3.5 {
            spokenCountdownSeconds.removeAll()
        }

        syncLiveActivity()
    }

    public func stopAndCleanup() {
        stopRunLoopTimer()
        UIApplication.shared.isIdleTimerDisabled = false
        WorkoutLiveActivityBridge.shared.onTogglePause = nil
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        AudioEngine.shared.stopWorkoutAudioSession()
        LiveActivityManager.shared.endActivity()
    }

    // MARK: - Internal Phase & Timestamp Engine

    private func startRunLoopTimer() {
        stopRunLoopTimer()
        let newTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTimerTick()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func stopRunLoopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func handleTimerTick() {
        guard !isPaused, !isCompleted else { return }
        let now = Date()

        // Advance through one or more phases if timestamp has passed phaseEndDate
        while now >= phaseEndDate && !isCompleted {
            let previousEndDate = phaseEndDate
            let nextIndex = currentPhaseIndex + 1
            if nextIndex < phases.count {
                enterPhase(at: nextIndex, anchorDate: previousEndDate, isInitialStart: false)
            } else {
                completeWorkout()
                return
            }
        }

        remainingTimeInPhase = max(0, phaseEndDate.timeIntervalSince(now))
        checkAndPlayCountdownTicks()
    }

    private func enterPhase(at index: Int, anchorDate: Date, isInitialStart: Bool) {
        currentPhaseIndex = index
        let step = phases[index]

        currentPhaseType = step.type
        currentExercise = step.exerciseIndex
        totalExercises = step.totalExercises
        currentRep = step.repIndex
        totalReps = step.totalReps
        currentPhaseTotalDuration = step.duration

        // Calculate sum of all subsequent phases after this one
        if index + 1 < phases.count {
            futurePhasesDuration = phases[(index + 1)...].reduce(0) { $0 + $1.duration }
        } else {
            futurePhasesDuration = 0
        }

        let now = Date()
        // If anchorDate is far in the past (e.g. device was suspended), clamp cleanly
        let effectiveStart = (now.timeIntervalSince(anchorDate) < step.duration) ? anchorDate : now
        phaseStartDate = effectiveStart
        phaseEndDate = effectiveStart.addingTimeInterval(step.duration)
        remainingTimeInPhase = max(0, phaseEndDate.timeIntervalSince(now))
        spokenCountdownSeconds.removeAll()

        AudioEngine.shared.playPhaseStartCue(for: step.type, workout: workout)
        triggerPhaseHaptic(for: step.type)

        if isInitialStart {
            LiveActivityManager.shared.startActivity(
                workoutName: workout.name,
                state: buildActivityState()
            )
        } else {
            syncLiveActivity()
        }
    }

    private func checkAndPlayCountdownTicks() {
        guard workout.countdownMode == .threeTwoOne else { return }
        guard !isCompleted else { return }

        let ceilSec = Int(ceil(remainingTimeInPhase))
        guard (1...3).contains(ceilSec) else { return }

        // Avoid overlapping with the phase start cue at the exact start of Work/Rest
        let totalWholeSeconds = Int(round(currentPhaseTotalDuration))
        if currentPhaseType != .getReady && ceilSec >= totalWholeSeconds {
            return
        }

        if !spokenCountdownSeconds.contains(ceilSec) {
            spokenCountdownSeconds.insert(ceilSec)
            AudioEngine.shared.playCountdownTick(second: ceilSec, workout: workout)
            triggerImpactHaptic(.soft)
        }
    }

    private func completeWorkout() {
        stopRunLoopTimer()
        isCompleted = true
        isPaused = false
        currentPhaseType = .done
        remainingTimeInPhase = 0
        futurePhasesDuration = 0

        AudioEngine.shared.playPhaseStartCue(for: .done, workout: workout)
        triggerPhaseHaptic(for: .done)

        let finalState = buildActivityState()
        LiveActivityManager.shared.endActivity(finalState: finalState)
    }

    private func buildActivityState() -> PulseCoachActivityAttributes.ContentState {
        PulseCoachActivityAttributes.ContentState(
            phase: currentPhaseType,
            currentExercise: currentExercise,
            totalExercises: totalExercises,
            currentRep: currentRep,
            totalReps: totalReps,
            isPaused: isPaused,
            phaseStartDate: phaseStartDate,
            phaseEndDate: phaseEndDate,
            pausedRemainingSeconds: displaySeconds,
            totalRemainingSeconds: totalRemainingSeconds
        )
    }

    private func syncLiveActivity() {
        LiveActivityManager.shared.updateActivity(with: buildActivityState())
    }

    private func setupLiveActivityObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .pulseCoachTogglePauseFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePauseFromLiveActivity()
            }
        }
    }

    // MARK: - Haptics

    private func triggerImpactHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private func triggerPhaseHaptic(for phase: WorkoutPhaseType) {
        let generator = UINotificationFeedbackGenerator()
        switch phase {
        case .work:
            generator.notificationOccurred(.success)
        case .rest, .transitionRest:
            generator.notificationOccurred(.warning)
        case .done:
            generator.notificationOccurred(.success)
        case .getReady:
            triggerImpactHaptic(.light)
        }
    }
}
