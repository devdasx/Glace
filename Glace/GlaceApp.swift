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
            WatchSetupFlowView()
                .environment(\.layoutDirection, .rightToLeft)
        } else {
            WatchSetupFlowView()
        }
#else
        WatchSetupFlowView()
#endif
    }
}
