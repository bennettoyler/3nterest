import SwiftUI

struct RootTabView: View {
  @Environment(Session.self) private var session
  @State private var tab = AppTab.home
  @State private var homePath = NavigationPath()

  private enum AppTab {
    case home, create, builder, profile
  }

  var body: some View {
    if session.isStarted {
      TabView(selection: $tab) {
        NavigationStack(path: $homePath) {
          FeedView(backend: session.backend)
            .navigationDestination(for: Room.self) { room in
              RoomDetailView(
                room: room,
                products: session.products,
                backend: session.backend,
                currentUser: session.currentUser,
                onBuy: { _ in
                  // TODO(B4): present CheckoutView for the product.
                },
                onRemix: {
                  // TODO(B5): call backend.remix and open the copy in the editor.
                })
            }
        }
        .tabItem { Label("Home", systemImage: "house.fill") }
        .tag(AppTab.home)

        NavigationStack {
          CreateFlowView(
            backend: session.backend,
            products: session.products,
            currentUser: session.currentUser,
            onBuy: { _ in
              // TODO(B4): present CheckoutView for the product.
            },
            onPublished: {
              homePath = NavigationPath()
              tab = .home
            })
        }
        .tabItem { Label("Create", systemImage: "plus.circle.fill") }
        .tag(AppTab.create)

        NavigationStack {
          placeholder("Builder", systemImage: "hammer.fill")
        }
        .tabItem { Label("Builder", systemImage: "hammer.fill") }
        .tag(AppTab.builder)

        NavigationStack {
          placeholder("Profile", systemImage: "person.fill")
        }
        .tabItem { Label("Profile", systemImage: "person.fill") }
        .tag(AppTab.profile)
      }
    } else {
      VStack(spacing: 16) {
        PinLogo(size: 72)
        Text("Interest")
          .font(.largeTitle.bold())
          .foregroundStyle(Theme.orange)
        ProgressView()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Theme.white)
    }
  }

  private func placeholder(_ title: String, systemImage: String) -> some View {
    ContentUnavailableView(title, systemImage: systemImage, description: Text("Coming soon"))
      .navigationTitle(title)
  }
}
