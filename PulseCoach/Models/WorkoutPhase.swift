import Foundation
import SwiftUI

public struct WorkoutPhaseStep: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let type: WorkoutPhaseType
    public var duration: TimeInterval
    public let exerciseIndex: Int
    public let totalExercises: Int
    public let repIndex: Int
    public let totalReps: Int

    public init(
        id: UUID = UUID(),
        type: WorkoutPhaseType,
        duration: TimeInterval,
        exerciseIndex: Int,
        totalExercises: Int,
        repIndex: Int,
        totalReps: Int
    ) {
        self.id = id
        self.type = type
        self.duration = duration
        self.exerciseIndex = exerciseIndex
        self.totalExercises = totalExercises
        self.repIndex = repIndex
        self.totalReps = totalReps
    }

    public var isRestPhase: Bool {
        type == .rest || type == .transitionRest
    }
}

public extension WorkoutPhaseType {
    var ringColor: Color {
        switch self {
        case .getReady:
            return Color(red: 1.0, green: 0.84, blue: 0.15) // High-contrast Yellow
        case .work:
            return Color(red: 1.0, green: 0.23, blue: 0.19) // Vibrant Red
        case .rest:
            return Color(red: 0.19, green: 0.82, blue: 0.35) // Vibrant Green
        case .transitionRest:
            return Color(red: 0.04, green: 0.52, blue: 1.0) // Vibrant Blue
        case .done:
            return Color.white
        }
    }

    var badgeBackgroundColor: Color {
        ringColor.opacity(0.18)
    }
}
