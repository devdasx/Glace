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
            WatchSetupRootView()
                .environment(\.layoutDirection, .rightToLeft)
        } else {
            WatchSetupRootView()
        }
#else
        WatchSetupRootView()
#endif
    }
}

private struct WatchSetupRootView: View {
    @Environment(\.layoutDirection) private var inheritedLayoutDirection

    @State private var isShowingPasscodeSetup = false

    var body: some View {
        NavigationStack {
            OnboardingView {
                isShowingPasscodeSetup = true
            }
            .navigationDestination(isPresented: $isShowingPasscodeSetup) {
                PasscodeSetupView()
            }
        }
        .environment(
            \.layoutDirection,
            isShowingPasscodeSetup ? .leftToRight : inheritedLayoutDirection
        )
    }
}
