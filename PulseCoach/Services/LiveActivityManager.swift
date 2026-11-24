import Foundation
import ActivityKit
import UIKit

@MainActor
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()

    private var currentActivity: Activity<PulseCoachActivityAttributes>?
    private var updateQueueTask: Task<Void, Never>?

    private init() {}

    public func startActivity(
        workoutName: String,
        state: PulseCoachActivityAttributes.ContentState
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let bgTask = Self.beginBackgroundAssertion(name: "PulseCoach.LiveActivityStart")
        let previousActivities = Activity<PulseCoachActivityAttributes>.activities

        let attributes = PulseCoachActivityAttributes(workoutName: workoutName)
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            let newActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = newActivity

            // Clean up any older lingering activities without touching the newly requested one
            let newID = newActivity.id
            Task { @MainActor in
                for existing in previousActivities where existing.id != newID {
                    await existing.end(nil, dismissalPolicy: .immediate)
                }
                Self.endBackgroundAssertion(bgTask)
            }
        } catch {
            currentActivity = nil
            Self.endBackgroundAssertion(bgTask)
            print("[LiveActivityManager] Live Activity unavailable (safe fallback): \(error.localizedDescription)")
        }
    }

    public func updateActivity(
        with state: PulseCoachActivityAttributes.ContentState,
        isPhaseTransition: Bool = false
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Acquire a background execution assertion so iOS never suspends the ActivityKit XPC update when locked
        let bgTask = Self.beginBackgroundAssertion(name: "PulseCoach.LiveActivityUpdate")
        let content = ActivityContent(state: state, staleDate: nil)
        let previousTask = updateQueueTask

        updateQueueTask = Task(priority: .userInitiated) { @MainActor [weak self] in
            _ = await previousTask?.value
            guard let self else {
                Self.endBackgroundAssertion(bgTask)
                return
            }

            let targets = self.resolveActiveActivities()
            for activity in targets {
                await activity.update(content)
            }

            // On phase transitions while locked, send a second confirmation push 200ms later
            // so SpringBoard/chronod never misses the new timerInterval boundary at 0:00
            if isPhaseTransition {
                try? await Task.sleep(nanoseconds: 200_000_000)
                let confirmTargets = self.resolveActiveActivities()
                for activity in confirmTargets {
                    await activity.update(content)
                }
            }

            Self.endBackgroundAssertion(bgTask)
        }
    }

    public func endActivity(finalState: PulseCoachActivityAttributes.ContentState? = nil) {
        let bgTask = Self.beginBackgroundAssertion(name: "PulseCoach.LiveActivityEnd")
        let targets = resolveActiveActivities()
        currentActivity = nil

        guard !targets.isEmpty else {
            Self.endBackgroundAssertion(bgTask)
            return
        }

        let previousTask = updateQueueTask
        updateQueueTask = Task(priority: .userInitiated) { @MainActor in
            _ = await previousTask?.value
            for activity in targets {
                if let finalState {
                    let content = ActivityContent(state: finalState, staleDate: nil)
                    await activity.end(content, dismissalPolicy: .default)
                } else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            Self.endBackgroundAssertion(bgTask)
        }
    }

    private func resolveActiveActivities() -> [Activity<PulseCoachActivityAttributes>] {
        let all = Activity<PulseCoachActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
        if !all.isEmpty {
            return all
        }
        if let currentActivity,
           currentActivity.activityState == .active || currentActivity.activityState == .stale {
            return [currentActivity]
        }
        return []
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
