import SwiftUI

struct RootTabView: View {
  @Environment(Session.self) private var session
  @Environment(CheckoutFlow.self) private var checkout: CheckoutFlow?
  @State private var tab = AppTab.home
  @State private var homePath = NavigationPath()
  @State private var createRequest: CreateRequest?
  @State private var showingEarnings = false

  private enum AppTab {
    case home, create, builder, profile
  }

  var body: some View {
    if session.isStarted, let checkout {
      TabView(selection: $tab) {
        NavigationStack(path: $homePath) {
          FeedView(backend: session.backend)
            .navigationDestination(for: Room.self) { room in
              RoomDetailView(
                room: room,
                products: session.products,
                backend: session.backend,
                currentUser: session.currentUser,
                checkout: checkout,
                onRemix: {
                  Task {
                    guard let copy = try? await session.backend.remix(roomId: room.id, as: session.currentUser.id) else { return }
                    createRequest = .edit(copy)
                    tab = .create
                  }
                })
            }
        }
        .tabItem { Label("Home", systemImage: "house.fill") }
        .tag(AppTab.home)

        NavigationStack {
          CreateFlowView(
            request: $createRequest,
            backend: session.backend,
            products: session.products,
            currentUser: session.currentUser,
            checkout: checkout,
            onPublished: {
              homePath = NavigationPath()
              tab = .home
            })
        }
        .tabItem { Label("Create", systemImage: "plus.circle.fill") }
        .tag(AppTab.create)

        NavigationStack {
          BuilderChatView(
            backend: session.backend,
            currentUser: session.currentUser,
            onPlace: { design in
              createRequest = .place(design)
              tab = .create
            })
        }
        .tabItem { Label("Builder", systemImage: "hammer.fill") }
        .tag(AppTab.builder)

        NavigationStack {
          ProfileView(onShowEarnings: { showingEarnings = true })
            .navigationDestination(isPresented: $showingEarnings) {
              EarningsView(backend: session.backend, products: session.products)
            }
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
}
