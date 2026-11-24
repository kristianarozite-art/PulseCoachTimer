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

    // Session-only adjustable settings (never overwrites saved WorkoutStore preset)
    public private(set) var sessionWorkDuration: Int
    public private(set) var sessionRestDuration: Int
    public private(set) var sessionTransitionRestDuration: Int
    public private(set) var sessionExerciseCount: Int

    private var phaseStartDate: Date = Date()
    private var phaseEndDate: Date = Date()
    private var pausedRemainingInPhase: TimeInterval = 0
    private var spokenCountdownSeconds: Set<Int> = []
    private var lastKeepAliveCheckSecond: Int = -1
    private var liveActivityUpdateSequence: Int = 0

    private var dispatchTimer: DispatchSourceTimer?
    private var runLoopTimer: Timer?
    private var pauseObserver: NSObjectProtocol?
    private var addTenObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    public init(workout: Workout) {
        self.workout = workout
        self.totalExercises = workout.exerciseCount
        self.totalReps = workout.repsPerExercise
        self.sessionWorkDuration = workout.workDuration
        self.sessionRestDuration = workout.restDuration
        self.sessionTransitionRestDuration = workout.transitionRestDuration
        self.sessionExerciseCount = workout.exerciseCount
        self.phases = workout.buildPhases()
        setupLiveActivityObservers()
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

    public var minAllowedExercises: Int {
        max(1, currentExercise)
    }

    // MARK: - Workout Control Actions

    public func startWorkout() {
        UIApplication.shared.isIdleTimerDisabled = true
        AudioEngine.shared.startWorkoutAudioSession(spotifyBehavior: workout.spotifyBehavior)

        sessionWorkDuration = workout.workDuration
        sessionRestDuration = workout.restDuration
        sessionTransitionRestDuration = workout.transitionRestDuration
        sessionExerciseCount = workout.exerciseCount
        totalExercises = workout.exerciseCount
        totalReps = workout.repsPerExercise
        liveActivityUpdateSequence = 0

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
        WorkoutLiveActivityBridge.shared.onAddTenSeconds = { [weak self] in
            self?.addTenSecondsToRest()
        }

        enterPhase(at: 0, anchorDate: Date(), isInitialStart: true)
        startBackgroundSafeTimer()
    }

    public func pauseWorkout() {
        guard !isPaused, !isCompleted else { return }
        let now = Date()
        pausedRemainingInPhase = max(0, phaseEndDate.timeIntervalSince(now))
        remainingTimeInPhase = pausedRemainingInPhase
        isPaused = true
        stopBackgroundSafeTimer()
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
        startBackgroundSafeTimer()
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
        stopBackgroundSafeTimer()
        startWorkout()
    }

    public func addTenSecondsToRest() {
        guard isRestPhase, !isCompleted else { return }
        triggerImpactHaptic(.rigid)

        currentPhaseTotalDuration += 10.0
        if isPaused {
            pausedRemainingInPhase += 10.0
            remainingTimeInPhase = pausedRemainingInPhase
            let now = Date()
            phaseEndDate = now.addingTimeInterval(pausedRemainingInPhase)
            phaseStartDate = phaseEndDate.addingTimeInterval(-currentPhaseTotalDuration)
        } else {
            phaseEndDate = phaseEndDate.addingTimeInterval(10.0)
            remainingTimeInPhase = max(0, phaseEndDate.timeIntervalSince(Date()))
        }

        if remainingTimeInPhase > 3.2 {
            spokenCountdownSeconds.removeAll()
        }

        syncLiveActivity()
    }

    // MARK: - Session-Only Adjustments While Paused

    public func adjustSessionWorkDuration(by delta: Int) {
        let oldVal = sessionWorkDuration
        let newVal = min(600, max(5, oldVal + delta))
        let appliedDelta = newVal - oldVal
        guard appliedDelta != 0 else { return }
        sessionWorkDuration = newVal
        triggerImpactHaptic(.light)

        if currentPhaseType == .work {
            applyDeltaToCurrentPausedPhase(TimeInterval(appliedDelta))
        }
        rebuildUpcomingPhases()
    }

    public func adjustSessionRestDuration(by delta: Int) {
        let oldVal = sessionRestDuration
        let newVal = min(300, max(0, oldVal + delta))
        let appliedDelta = newVal - oldVal
        guard appliedDelta != 0 else { return }
        sessionRestDuration = newVal
        triggerImpactHaptic(.light)

        if currentPhaseType == .rest {
            applyDeltaToCurrentPausedPhase(TimeInterval(appliedDelta))
        }
        rebuildUpcomingPhases()
    }

    public func adjustSessionTransitionRestDuration(by delta: Int) {
        let oldVal = sessionTransitionRestDuration
        let newVal = min(600, max(0, oldVal + delta))
        let appliedDelta = newVal - oldVal
        guard appliedDelta != 0 else { return }
        sessionTransitionRestDuration = newVal
        triggerImpactHaptic(.light)

        if currentPhaseType == .transitionRest {
            applyDeltaToCurrentPausedPhase(TimeInterval(appliedDelta))
        }
        rebuildUpcomingPhases()
    }

    public func adjustSessionExerciseCount(by delta: Int) {
        let minAllowed = minAllowedExercises
        let oldVal = sessionExerciseCount
        let newVal = min(50, max(minAllowed, oldVal + delta))
        guard newVal != oldVal else { return }
        sessionExerciseCount = newVal
        totalExercises = newVal
        triggerImpactHaptic(.light)
        rebuildUpcomingPhases()
    }

    private func applyDeltaToCurrentPausedPhase(_ deltaSeconds: TimeInterval) {
        let newRemaining = max(1.0, pausedRemainingInPhase + deltaSeconds)
        let actualChange = newRemaining - pausedRemainingInPhase
        pausedRemainingInPhase = newRemaining
        remainingTimeInPhase = newRemaining
        currentPhaseTotalDuration = max(newRemaining, currentPhaseTotalDuration + actualChange)
        if phases.indices.contains(currentPhaseIndex) {
            phases[currentPhaseIndex].duration = currentPhaseTotalDuration
        }
        let now = Date()
        phaseEndDate = now.addingTimeInterval(pausedRemainingInPhase)
        phaseStartDate = phaseEndDate.addingTimeInterval(-currentPhaseTotalDuration)
    }

    private func rebuildUpcomingPhases() {
        guard !isCompleted, phases.indices.contains(currentPhaseIndex) else { return }

        var newUpcoming: [WorkoutPhaseStep] = []
        let totalEx = max(currentExercise, sessionExerciseCount)
        let repsCount = max(1, totalReps)

        func appendRestAfter(ex: Int, rep: Int) {
            let isLastEx = (ex == totalEx)
            let isLastRep = (rep == repsCount)
            if isLastEx && isLastRep {
                return
            }
            if isLastRep {
                if workout.enableTransitionRest {
                    if sessionTransitionRestDuration > 0 {
                        newUpcoming.append(
                            WorkoutPhaseStep(
                                type: .transitionRest,
                                duration: TimeInterval(sessionTransitionRestDuration),
                                exerciseIndex: ex,
                                totalExercises: totalEx,
                                repIndex: rep,
                                totalReps: repsCount
                            )
                        )
                    }
                } else if sessionRestDuration > 0 {
                    newUpcoming.append(
                        WorkoutPhaseStep(
                            type: .rest,
                            duration: TimeInterval(sessionRestDuration),
                            exerciseIndex: ex,
                            totalExercises: totalEx,
                            repIndex: rep,
                            totalReps: repsCount
                        )
                    )
                }
            } else if sessionRestDuration > 0 {
                newUpcoming.append(
                    WorkoutPhaseStep(
                        type: .rest,
                        duration: TimeInterval(sessionRestDuration),
                        exerciseIndex: ex,
                        totalExercises: totalEx,
                        repIndex: rep,
                        totalReps: repsCount
                    )
                )
            }
        }

        func appendWorkAndRest(ex: Int, rep: Int) {
            newUpcoming.append(
                WorkoutPhaseStep(
                    type: .work,
                    duration: TimeInterval(max(1, sessionWorkDuration)),
                    exerciseIndex: ex,
                    totalExercises: totalEx,
                    repIndex: rep,
                    totalReps: repsCount
                )
            )
            appendRestAfter(ex: ex, rep: rep)
        }

        switch currentPhaseType {
        case .getReady:
            for ex in 1...totalEx {
                for rep in 1...repsCount {
                    appendWorkAndRest(ex: ex, rep: rep)
                }
            }

        case .work:
            appendRestAfter(ex: currentExercise, rep: currentRep)
            if currentRep < repsCount {
                for rep in (currentRep + 1)...repsCount {
                    appendWorkAndRest(ex: currentExercise, rep: rep)
                }
            }
            if currentExercise < totalEx {
                for ex in (currentExercise + 1)...totalEx {
                    for rep in 1...repsCount {
                        appendWorkAndRest(ex: ex, rep: rep)
                    }
                }
            }

        case .rest, .transitionRest:
            if currentRep < repsCount {
                for rep in (currentRep + 1)...repsCount {
                    appendWorkAndRest(ex: currentExercise, rep: rep)
                }
            }
            if currentExercise < totalEx {
                for ex in (currentExercise + 1)...totalEx {
                    for rep in 1...repsCount {
                        appendWorkAndRest(ex: ex, rep: rep)
                    }
                }
            }

        case .done:
            break
        }

        let prefix = Array(phases[0...currentPhaseIndex])
        phases = prefix + newUpcoming
        totalExercises = totalEx
        futurePhasesDuration = newUpcoming.reduce(0) { $0 + $1.duration }
        syncLiveActivity()
    }

    public func stopAndCleanup() {
        stopBackgroundSafeTimer()
        UIApplication.shared.isIdleTimerDisabled = false
        WorkoutLiveActivityBridge.shared.onTogglePause = nil
        WorkoutLiveActivityBridge.shared.onAddTenSeconds = nil
        if let observer = pauseObserver {
            NotificationCenter.default.removeObserver(observer)
            pauseObserver = nil
        }
        if let observer = addTenObserver {
            NotificationCenter.default.removeObserver(observer)
            addTenObserver = nil
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
        AudioEngine.shared.stopWorkoutAudioSession()
        LiveActivityManager.shared.endActivity()
    }

    // MARK: - Internal Phase & Timestamp Engine (Dual DispatchSourceTimer + Common RunLoop Timer)

    private func startBackgroundSafeTimer() {
        stopBackgroundSafeTimer()

        // 1. Strict DispatchSourceTimer on main queue
        let source = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        source.schedule(deadline: .now() + .milliseconds(45), repeating: .milliseconds(45), leeway: .milliseconds(5))
        source.setEventHandler { [weak self] in
            self?.handleTimerTick()
        }
        source.resume()
        dispatchTimer = source

        // 2. Redundant RunLoop.main .common mode timer so background audio execution never stalls
        let rlTimer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTimerTick()
            }
        }
        RunLoop.main.add(rlTimer, forMode: .common)
        runLoopTimer = rlTimer
    }

    private func stopBackgroundSafeTimer() {
        dispatchTimer?.cancel()
        dispatchTimer = nil
        runLoopTimer?.invalidate()
        runLoopTimer = nil
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

        // Once per second, verify the background silent keep-alive loop is still active
        // NOTE: We NEVER call LiveActivityManager.updateActivity here on 1-second ticks!
        let curSec = Int(ceil(remainingTimeInPhase))
        if curSec != lastKeepAliveCheckSecond {
            lastKeepAliveCheckSecond = curSec
            AudioEngine.shared.ensureKeepAliveRunning()
        }

        checkAndPlayCountdownTicks()
    }

    private func enterPhase(at index: Int, anchorDate: Date, isInitialStart: Bool) {
        currentPhaseIndex = index
        let step = phases[index]

        currentPhaseType = step.type
        currentExercise = step.exerciseIndex
        totalExercises = sessionExerciseCount
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
        let effectiveStart = (now.timeIntervalSince(anchorDate) < step.duration) ? anchorDate : now
        phaseStartDate = effectiveStart
        phaseEndDate = effectiveStart.addingTimeInterval(step.duration)
        remainingTimeInPhase = max(0, phaseEndDate.timeIntervalSince(now))
        spokenCountdownSeconds.removeAll()
        lastKeepAliveCheckSecond = Int(ceil(remainingTimeInPhase))

        // Increment discrete state sequence and push Live Activity update immediately
        liveActivityUpdateSequence += 1
        let currentState = buildActivityState()
        if isInitialStart {
            LiveActivityManager.shared.startActivity(
                workoutName: workout.name,
                state: currentState
            )
        } else {
            LiveActivityManager.shared.updateActivity(with: currentState)
        }

        AudioEngine.shared.playPhaseStartCue(for: step.type, workout: workout)
        triggerPhaseHaptic(for: step.type)
    }

    private func checkAndPlayCountdownTicks() {
        guard workout.countdownMode == .threeTwoOne else { return }
        guard !isCompleted else { return }

        let ceilSec = Int(ceil(remainingTimeInPhase))
        guard (1...3).contains(ceilSec) else { return }

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
        stopBackgroundSafeTimer()
        isCompleted = true
        isPaused = false
        currentPhaseType = .done
        remainingTimeInPhase = 0
        futurePhasesDuration = 0

        liveActivityUpdateSequence += 1
        let finalState = buildActivityState()
        LiveActivityManager.shared.endActivity(finalState: finalState)

        AudioEngine.shared.playPhaseStartCue(for: .done, workout: workout)
        triggerPhaseHaptic(for: .done)
    }

    private func buildActivityState() -> PulseCoachActivityAttributes.ContentState {
        let totalEnd = phaseEndDate.addingTimeInterval(max(0, futurePhasesDuration))
        return PulseCoachActivityAttributes.ContentState(
            phase: currentPhaseType,
            currentExercise: currentExercise,
            totalExercises: totalExercises,
            currentRep: currentRep,
            totalReps: totalReps,
            isPaused: isPaused,
            phaseStartDate: phaseStartDate,
            phaseEndDate: phaseEndDate,
            workoutEndDate: totalEnd,
            pausedRemainingSeconds: displaySeconds,
            totalRemainingSeconds: totalRemainingSeconds,
            updateSequence: liveActivityUpdateSequence
        )
    }

    private func syncLiveActivity() {
        liveActivityUpdateSequence += 1
        LiveActivityManager.shared.updateActivity(with: buildActivityState())
    }

    private func setupLiveActivityObservers() {
        pauseObserver = NotificationCenter.default.addObserver(
            forName: .pulseCoachTogglePauseFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePauseFromLiveActivity()
            }
        }

        addTenObserver = NotificationCenter.default.addObserver(
            forName: .pulseCoachAddTenSecondsFromLiveActivity,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.addTenSecondsToRest()
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isCompleted else { return }
                self.handleTimerTick()
                self.syncLiveActivity()
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
