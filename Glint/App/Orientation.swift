import SwiftUI
import UIKit

/// R5 (founder): regular iPhones play portrait only; a Duo (and its cover display) takes any orientation, because
/// its layout follows the canvas (book or laptop pose). Info.plist lists every orientation; this mask narrows it at
/// run time (`GlintAppDelegate`), once the controller knows whether this is a Duo.
@MainActor
enum OrientationRules {
    private(set) static var mask: UIInterfaceOrientationMask = .all
    private static var decided = false

    /// Pure; tested.
    nonisolated static func mask(isDuo: Bool) -> UIInterfaceOrientationMask {
        isDuo ? .all : .portrait
    }

    static func update(isDuo: Bool) {
        let next = mask(isDuo: isDuo)
        guard !decided || next != mask else { return }
        decided = true
        mask = next
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            if next == .portrait {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
            }
        }
        AppTrace.note("orientations \(isDuo ? "all" : "portrait")")
    }
}

final class GlintAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationRules.mask
    }
}
