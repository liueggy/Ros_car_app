import SwiftUI

struct EmergencyStopToolbar: ToolbarContent {
    @EnvironmentObject var model: RobotViewModel
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if model.connected {
                Button(role: .destructive) { model.stop() } label: {
                    Label("急停", systemImage: "stop.fill")
                }
                .tint(.red)
            }
        }
    }
}
