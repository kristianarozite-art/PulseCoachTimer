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
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        // End any lingering activities before requesting a fresh one
        for existing in Activity<PulseCoachActivityAttributes>.activities {
            Task {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
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
            currentActivity = nil
            print("[LiveActivityManager] Live Activity unavailable (safe fallback): \(error.localizedDescription)")
        }
    }

    public func updateActivity(with state: PulseCoachActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let content = ActivityContent(state: state, staleDate: nil)
        let activities = Activity<PulseCoachActivityAttributes>.activities
        let targetActivities: [Activity<PulseCoachActivityAttributes>]
        if !activities.isEmpty {
            targetActivities = activities
        } else if let currentActivity {
            targetActivities = [currentActivity]
        } else {
            return
        }

        for activity in targetActivities {
            Task {
                await activity.update(content)
            }
        }
    }

    public func endActivity(finalState: PulseCoachActivityAttributes.ContentState? = nil) {
        let activities = Activity<PulseCoachActivityAttributes>.activities
        let targetActivities: [Activity<PulseCoachActivityAttributes>]
        if !activities.isEmpty {
            targetActivities = activities
        } else if let currentActivity {
            targetActivities = [currentActivity]
        } else {
            currentActivity = nil
            return
        }
        currentActivity = nil

        for activity in targetActivities {
            Task {
                if let finalState {
                    let content = ActivityContent(state: finalState, staleDate: nil)
                    await activity.end(content, dismissalPolicy: .default)
                } else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
}
