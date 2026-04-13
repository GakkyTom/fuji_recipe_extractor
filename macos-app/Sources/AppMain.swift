import SwiftUI

@main
struct FujiRecipeExtractorMacApp: App {
    @StateObject private var viewModel = AppViewModel()

    init() {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = image
        }
    }

    var body: some Scene {
        WindowGroup("Fuji Recipe Extractor") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 760, minHeight: 560)
        }
        .windowResizability(.contentSize)
    }
}
