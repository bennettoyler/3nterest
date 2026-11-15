import SwiftUI

struct CollectionView: View {
  let collection: SavedCollection
  let backend: any Backend

  @State private var rooms: [Room] = []
  @State private var products: [Product] = []
  @State private var isLoaded = false

  var body: some View {
    List {
      ForEach(rooms) { room in
        row(systemImage: "sofa.fill", title: room.title, subtitle: "Room by \(room.ownerName)", trailing: nil)
      }
      ForEach(products) { product in
        row(systemImage: "shippingbox.fill", title: product.name, subtitle: product.sellerName, trailing: collectionDollars(product.priceCents))
      }
    }
    .overlay {
      if !isLoaded {
        ProgressView()
      } else if rooms.isEmpty && products.isEmpty {
        ContentUnavailableView("Nothing saved yet", systemImage: "bookmark", description: Text("Save a room or a product and it shows up here."))
      }
    }
    .navigationTitle(collection.name)
    .task(id: collection) {
      var loadedRooms: [Room] = []
      for id in collection.roomIds {
        if let room = try? await backend.room(id: id) { loadedRooms.append(room) }
      }
      let catalog = (try? await backend.products()) ?? []
      rooms = loadedRooms
      products = collection.productIds.compactMap { id in catalog.first(where: { $0.id == id }) }
      isLoaded = true
    }
  }

  private func row(systemImage: String, title: String, subtitle: String, trailing: String?) -> some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .foregroundStyle(Theme.orange)
        .frame(width: 44, height: 44)
        .background(Theme.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if let trailing {
        Text(trailing)
          .font(.subheadline)
          .monospacedDigit()
      }
    }
  }
}

private func collectionDollars(_ cents: Int) -> String {
  String(format: "$%d.%02d", cents / 100, cents % 100)
}

#Preview {
  NavigationStack {
    CollectionView(
      collection: SavedCollection(
        id: "preview-saved", name: "Saved",
        roomIds: ["stub-room-1", "stub-room-4"],
        productIds: ["stub-sofa", "stub-chair", "stub-stool"]),
      backend: StubBackend())
  }
}
