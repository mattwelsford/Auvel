import SwiftUI

@main
struct AuvelApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(.goldText)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.didBecomeActive()
            case .background: model.didEnterBackground()
            default: break
            }
        }
    }
}

/// Routes between onboarding (I01, I02), adding a Mac (I03 to I07) and the remote (I08 onwards).
struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let session = model.session {
            RemoteView(session: session)
                .id(session.mac.peerID)
        } else if !model.hasSeenOnboarding {
            OnboardingView()
        } else {
            NavigationStack {
                AddMacView(showsCancel: false)
            }
        }
    }
}
