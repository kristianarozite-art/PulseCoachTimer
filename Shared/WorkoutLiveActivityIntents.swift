import Foundation
import AppIntents

public extension Notification.Name {
    static let pulseCoachTogglePauseFromLiveActivity = Notification.Name("pulseCoach.togglePauseFromLiveActivity")
    static let pulseCoachAddTenSecondsFromLiveActivity = Notification.Name("pulseCoach.addTenSecondsFromLiveActivity")
}

@MainActor
public final class WorkoutLiveActivityBridge {
    public static let shared = WorkoutLiveActivityBridge()
    public var onTogglePause: (() -> Void)?
    public var onAddTenSeconds: (() -> Void)?

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

public struct AddTenSecondsIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Add 10 Seconds Rest"
    public static var description = IntentDescription("Adds 10 seconds to the current rest interval.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        if let handler = WorkoutLiveActivityBridge.shared.onAddTenSeconds {
            handler()
        } else {
            NotificationCenter.default.post(name: .pulseCoachAddTenSecondsFromLiveActivity, object: nil)
        }
        return .result()
    }
}
