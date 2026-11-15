import SwiftUI

@main
struct InterestApp: App {
  @State private var session = Session(primary: StubBackend(), fallback: StubBackend())
  @State private var checkoutFlow: CheckoutFlow?

  var body: some Scene {
    WindowGroup {
      RootTabView()
        .environment(session)
        .environment(checkoutFlow)
        .tint(Theme.orange)
        .preferredColorScheme(.light)
        .task {
          await session.start()
          checkoutFlow = CheckoutFlow(backend: session.backend)
        }
        .onOpenURL { url in
          Task { await checkoutFlow?.handleReturn(url: url) }
        }
    }
  }
}
