import Foundation
import ActivityKit
import UIKit

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

        let bgTask = Self.beginBackgroundAssertion(name: "PulseCoach.LiveActivityStart")
        let preExisting = Activity<PulseCoachActivityAttributes>.activities

        let attributes = PulseCoachActivityAttributes(workoutName: workoutName)
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            let newActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = newActivity

            let newID = newActivity.id
            Task(priority: .userInitiated) {
                for existing in preExisting where existing.id != newID {
                    await existing.end(nil, dismissalPolicy: .immediate)
                }
                await MainActor.run {
                    Self.endBackgroundAssertion(bgTask)
                }
            }
        } catch {
            currentActivity = nil
            Self.endBackgroundAssertion(bgTask)
            print("[LiveActivityManager] Live Activity unavailable (safe fallback): \(error.localizedDescription)")
        }
    }

    public func updateActivity(with state: PulseCoachActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let targets = resolveTargetActivities()
        guard !targets.isEmpty else { return }

        let bgTask = Self.beginBackgroundAssertion(name: "PulseCoach.LiveActivityUpdate")
        let content = ActivityContent(state: state, staleDate: nil)

        Task(priority: .userInitiated) {
            for activity in targets {
                await activity.update(content)
            }
            await MainActor.run {
                Self.endBackgroundAssertion(bgTask)
            }
        }
    }

    public func endActivity(finalState: PulseCoachActivityAttributes.ContentState? = nil) {
        let targets = resolveTargetActivities()
        currentActivity = nil
        guard !targets.isEmpty else { return }

        let bgTask = Self.beginBackgroundAssertion(name: "PulseCoach.LiveActivityEnd")
        Task(priority: .userInitiated) {
            for activity in targets {
                if let finalState {
                    let content = ActivityContent(state: finalState, staleDate: nil)
                    await activity.end(content, dismissalPolicy: .default)
                } else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            await MainActor.run {
                Self.endBackgroundAssertion(bgTask)
            }
        }
    }

    private func resolveTargetActivities() -> [Activity<PulseCoachActivityAttributes>] {
        var result: [Activity<PulseCoachActivityAttributes>] = []
        var seenIDs: Set<String> = []

        if let currentActivity,
           currentActivity.activityState == .active || currentActivity.activityState == .stale {
            result.append(currentActivity)
            seenIDs.insert(currentActivity.id)
        }

        for activity in Activity<PulseCoachActivityAttributes>.activities {
            if (activity.activityState == .active || activity.activityState == .stale),
               !seenIDs.contains(activity.id) {
                result.append(activity)
                seenIDs.insert(activity.id)
            }
        }

        return result
    }

    private static func beginBackgroundAssertion(name: String) -> UIBackgroundTaskIdentifier {
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: name) {
            if taskID != .invalid {
                UIApplication.shared.endBackgroundTask(taskID)
                taskID = .invalid
            }
        }
        return taskID
    }

    private static func endBackgroundAssertion(_ taskID: UIBackgroundTaskIdentifier) {
        guard taskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(taskID)
    }
}
