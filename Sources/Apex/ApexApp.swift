import SwiftUI

// MARK: - ApexApp
//
// App entry. Dark-first by design (DESIGN_PRINCIPLES §3), so we pin the color
// scheme. In v1 the root is the Ride Library, seeded from SampleData; live
// data (SwiftData + CoreLocation) is wired in once the UI clears the design bar.

@main
struct ApexApp: App {
    var body: some Scene {
        WindowGroup {
            RideLibraryView()
                .preferredColorScheme(.dark)
        }
    }
}
