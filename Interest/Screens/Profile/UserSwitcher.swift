import SwiftUI

struct UserSwitcher: View {
  @Environment(Session.self) private var session

  @State private var users: [User] = []

  var body: some View {
    HStack(spacing: 12) {
      Text(String(session.currentUser.name.prefix(1)))
        .font(.title2.bold())
        .foregroundStyle(Theme.white)
        .frame(width: 52, height: 52)
        .background(Theme.orange, in: Circle())
      VStack(alignment: .leading, spacing: 2) {
        Text(session.currentUser.name)
          .font(.headline)
        Text("Demo account")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Menu {
        ForEach(users) { user in
          Button {
            session.currentUser = user
          } label: {
            if user.id == session.currentUser.id {
              Label(user.name, systemImage: "checkmark")
            } else {
              Text(user.name)
            }
          }
        }
      } label: {
        Label("Switch", systemImage: "arrow.left.arrow.right")
          .font(.subheadline.weight(.medium))
      }
      .disabled(users.isEmpty)
    }
    .task {
      users = (try? await session.backend.users()) ?? []
    }
  }
}

#Preview {
  let session = Session(primary: StubBackend(), fallback: StubBackend())
  List {
    UserSwitcher()
  }
  .environment(session)
  .task { await session.start() }
}
