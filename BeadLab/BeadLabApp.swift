import SwiftUI

@main
struct BeadLabApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
                .tint(.ochre)
        }
    }
}
