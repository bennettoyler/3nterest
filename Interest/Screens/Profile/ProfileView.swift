import SwiftUI

struct ProfileView: View {
  let onShowEarnings: () -> Void

  @Environment(Session.self) private var session

  @State private var rooms: [Room] = []
  @State private var saved: SavedCollection?

  var body: some View {
    List {
      Section {
        UserSwitcher()
      }
      Section("My rooms") {
        if rooms.isEmpty {
          Text("No rooms yet").foregroundStyle(.secondary)
        }
        ForEach(rooms) { room in
          HStack(spacing: 12) {
            Image(systemName: "sofa.fill")
              .foregroundStyle(Theme.orange)
              .frame(width: 44, height: 44)
              .background(Theme.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
              Text(room.title)
                .font(.subheadline.weight(.semibold))
              Text("\(room.published ? "Published" : "Draft") · \(room.placements.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      Section("Collections") {
        if let saved {
          NavigationLink {
            CollectionView(collection: saved, backend: session.backend)
          } label: {
            LabeledContent {
              Text("\(saved.roomIds.count + saved.productIds.count)")
            } label: {
              Label(saved.name, systemImage: "bookmark.fill")
            }
          }
        } else {
          Label("Saved", systemImage: "bookmark.fill")
            .foregroundStyle(.secondary)
        }
      }
      Section {
        Button(action: onShowEarnings) {
          HStack {
            Label("Seller earnings", systemImage: "dollarsign.circle.fill")
            Spacer()
            Image(systemName: "chevron.right")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.tertiary)
          }
        }
        .foregroundStyle(.primary)
      }
    }
    .navigationTitle("Profile")
    .task(id: session.currentUser.id) { await load() }
    .refreshable { await load() }
  }

  private func load() async {
    let userId = session.currentUser.id
    let backend = session.backend
    let loadedRooms = (try? await backend.rooms(ownerId: userId)) ?? []
    let collections = (try? await backend.collections(userId: userId)) ?? []
    guard userId == session.currentUser.id else { return }
    rooms = loadedRooms
    saved = collections.first(where: { $0.name == "Saved" }) ?? collections.first
  }
}

#Preview {
  let session = Session(primary: StubBackend(), fallback: StubBackend())
  NavigationStack {
    ProfileView(onShowEarnings: {})
  }
  .environment(session)
  .tint(Theme.orange)
  .task { await session.start() }
}
