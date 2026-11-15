import SwiftUI

struct FeedView: View {
  let backend: any Backend

  @State private var rooms: [Room] = []

  private static let thumbnailHeights: [CGFloat] = [220, 160, 190, 250, 170, 210]

  var body: some View {
    ScrollView {
      HStack(alignment: .top, spacing: 12) {
        column(parity: 0)
        column(parity: 1)
      }
      .padding(.horizontal, 12)
      .padding(.top, 8)
    }
    .overlay {
      if rooms.isEmpty { ProgressView() }
    }
    .navigationTitle("3nterest")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        HStack(spacing: 8) {
          PinLogo()
          Text("3nterest")
            .font(.title3.bold())
            .foregroundStyle(Theme.orange)
        }
      }
    }
    .task {
      for await latest in backend.feed() {
        rooms = latest
      }
    }
  }

  private func column(parity: Int) -> some View {
    LazyVStack(spacing: 16) {
      ForEach(Array(rooms.enumerated()).filter { $0.offset % 2 == parity }, id: \.element.id) { index, room in
        NavigationLink(value: room) {
          RoomCard(room: room, thumbnailHeight: Self.thumbnailHeights[index % Self.thumbnailHeights.count])
        }
        .buttonStyle(.plain)
      }
    }
  }
}
