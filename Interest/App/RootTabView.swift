import SwiftUI

struct RootTabView: View {
  @Environment(Session.self) private var session

  var body: some View {
    if session.isStarted {
      TabView {
        NavigationStack {
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

        NavigationStack {
          placeholder("Create", systemImage: "plus.circle.fill")
        }
        .tabItem { Label("Create", systemImage: "plus.circle.fill") }

        NavigationStack {
          placeholder("Builder", systemImage: "hammer.fill")
        }
        .tabItem { Label("Builder", systemImage: "hammer.fill") }

        NavigationStack {
          placeholder("Profile", systemImage: "person.fill")
        }
        .tabItem { Label("Profile", systemImage: "person.fill") }
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
