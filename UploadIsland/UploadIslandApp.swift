import SwiftUI

@main
struct UploadIslandApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await UploadCenter.shared.endStaleActivities()
                    UploadCenter.shared.handleLaunchArguments()
                }
        }
    }
}
