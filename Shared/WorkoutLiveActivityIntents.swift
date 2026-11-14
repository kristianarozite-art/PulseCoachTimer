import Foundation
import AppIntents

public extension Notification.Name {
    static let pulseCoachTogglePauseFromLiveActivity = Notification.Name("pulseCoach.togglePauseFromLiveActivity")
}

@MainActor
public final class WorkoutLiveActivityBridge {
    public static let shared = WorkoutLiveActivityBridge()
    public var onTogglePause: (() -> Void)?

    private init() {}
}

public struct ToggleWorkoutPauseIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Pause or Resume Workout"
    public static var description = IntentDescription("Toggles pause and resume for the active PulseCoach workout.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        if let handler = WorkoutLiveActivityBridge.shared.onTogglePause {
            handler()
        } else {
            NotificationCenter.default.post(name: .pulseCoachTogglePauseFromLiveActivity, object: nil)
        }
        return .result()
    }
}
