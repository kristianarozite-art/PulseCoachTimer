import SwiftUI
import UIKit

public final class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }
}

@main
public struct PulseCoachApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    public init() {}

    public var body: some Scene {
        WindowGroup {
            WorkoutLibraryView()
                .preferredColorScheme(.dark)
        }
    }
}
