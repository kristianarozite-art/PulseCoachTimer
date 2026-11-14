import Foundation
import ActivityKit

@MainActor
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()

    private var currentActivity: Activity<PulseCoachActivityAttributes>?

    private init() {}

    public func startActivity(
        workoutName: String,
        state: PulseCoachActivityAttributes.ContentState
    ) {
        endAllActivitiesImmediate()

        // Safely guard when sideloaded with a free Apple ID where Live Activities or PlugIns may not be provisioned
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let attributes = PulseCoachActivityAttributes(workoutName: workoutName)
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // Gracefully ignore if Widget Extension wasn't provisioned during sideloading
            currentActivity = nil
            print("[LiveActivityManager] Live Activity unavailable (safe fallback): \(error.localizedDescription)")
        }
    }

    public func updateActivity(with state: PulseCoachActivityAttributes.ContentState) {
        guard let activity = currentActivity else { return }
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity.update(content)
        }
    }

    public func endActivity(finalState: PulseCoachActivityAttributes.ContentState? = nil) {
        guard let activity = currentActivity else { return }
        currentActivity = nil

        Task {
            if let finalState {
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: .default)
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func endAllActivitiesImmediate() {
        currentActivity = nil
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for activity in Activity<PulseCoachActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
