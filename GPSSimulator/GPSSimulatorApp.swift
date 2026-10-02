import SwiftUI

@main
struct GPSSimulatorApp: App {
    @StateObject private var auth = AuthSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appSettings) {
                Button("退出登录") { auth.signOut() }
                    .disabled(!auth.isSignedIn)
            }
        }
    }
}

/// 根视图：未登录时显示登录界面，登录后进入控制台
struct RootView: View {
    @EnvironmentObject private var auth: AuthSession

    var body: some View {
        if auth.isSignedIn {
            ContentView()
        } else {
            LoginView()
        }
    }
}
