import Foundation
import SwiftUI

@main
struct GlaceApp: App {
    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-GlaceForceRightToLeft") {
            OnboardingView()
                .environment(\.layoutDirection, .rightToLeft)
        } else {
            OnboardingView()
        }
#else
        OnboardingView()
#endif
    }
}
