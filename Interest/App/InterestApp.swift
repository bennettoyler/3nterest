import SwiftUI

@main
struct InterestApp: App {
  @State private var session = Session(primary: StubBackend(), fallback: StubBackend())

  var body: some Scene {
    WindowGroup {
      RootTabView()
        .environment(session)
        .tint(Theme.orange)
        .preferredColorScheme(.light)
        .task { await session.start() }
    }
  }
}
