import SwiftUI

@main
struct EggyRobotClientApp: App {
    @StateObject private var model = RobotViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .task { model.connect() }
        }
    }
}
