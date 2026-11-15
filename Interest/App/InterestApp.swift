import SwiftUI

@main
struct InterestApp: App {
  private static let useConvex = true
  @State private var session = Session(
    primary: useConvex ? ConvexBackend(deploymentUrl: "https://frugal-squirrel-172.convex.cloud") : StubBackend(),
    fallback: StubBackend())
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
