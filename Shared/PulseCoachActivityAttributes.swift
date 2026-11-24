import Foundation
import ActivityKit

public enum WorkoutPhaseType: String, Codable, Hashable, Sendable {
    case getReady = "GET READY"
    case work = "WORK"
    case rest = "REST"
    case transitionRest = "TRANSITION REST"
    case done = "DONE"

    public var displayTitle: String {
        rawValue
    }
}

public struct PulseCoachActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: WorkoutPhaseType
        public var currentExercise: Int
        public var totalExercises: Int
        public var currentRep: Int
        public var totalReps: Int
        public var isPaused: Bool
        public var phaseStartDate: Date
        public var phaseEndDate: Date
        public var workoutEndDate: Date
        public var pausedRemainingSeconds: Int
        public var totalRemainingSeconds: Int
        public var updateSequence: Int

        public init(
            phase: WorkoutPhaseType,
            currentExercise: Int,
            totalExercises: Int,
            currentRep: Int,
            totalReps: Int,
            isPaused: Bool,
            phaseStartDate: Date,
            phaseEndDate: Date,
            workoutEndDate: Date,
            pausedRemainingSeconds: Int,
            totalRemainingSeconds: Int,
            updateSequence: Int
        ) {
            self.phase = phase
            self.currentExercise = currentExercise
            self.totalExercises = totalExercises
            self.currentRep = currentRep
            self.totalReps = totalReps
            self.isPaused = isPaused
            self.phaseStartDate = phaseStartDate
            self.phaseEndDate = phaseEndDate
            self.workoutEndDate = workoutEndDate
            self.pausedRemainingSeconds = pausedRemainingSeconds
            self.totalRemainingSeconds = totalRemainingSeconds
            self.updateSequence = updateSequence
        }

        public var counterText: String {
            "Exercise \(currentExercise)/\(totalExercises) • Rep \(currentRep)/\(totalReps)"
        }
    }

    public var workoutName: String

    public init(workoutName: String) {
        self.workoutName = workoutName
    }
}
