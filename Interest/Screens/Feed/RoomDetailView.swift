import SwiftUI

struct RoomDetailView: View {
  let room: Room
  let products: [Product]
  let backend: any Backend
  let currentUser: User
  let checkout: CheckoutFlow
  let onRemix: () -> Void

  @State private var selectedProduct: Product?
  @State private var buying: Product?
  @State private var saveMessage: String?

  private var items: [(placement: Placement, product: Product)] {
    room.placements.compactMap { placement in
      guard let product = products.first(where: { $0.id == placement.productId }) else { return nil }
      return (placement, product)
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        ZStack {
          Color(.systemGray4)
          Label("3D room", systemImage: "cube").foregroundStyle(.secondary)
        }
        .frame(height: 300)

        VStack(alignment: .leading, spacing: 4) {
          Text(room.title).font(.title2.bold())
          Text("by \(room.ownerName)").foregroundStyle(.secondary)
        }
        .padding(.horizontal)

        HStack(spacing: 12) {
          Button {
            Task { await saveRoom() }
          } label: {
            Label("Save", systemImage: "bookmark").frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)

          Button(action: onRemix) {
            Label("Remix", systemImage: "arrow.triangle.branch").frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .padding(.horizontal)

        VStack(alignment: .leading, spacing: 0) {
          Text("In this room").font(.headline).padding(.horizontal).padding(.bottom, 8)
          ForEach(items, id: \.placement.id) { item in
            Button {
              selectedProduct = item.product
            } label: {
              HStack(spacing: 12) {
                ProductThumbnail(product: item.product)
                  .frame(width: 56, height: 56)
                  .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                  Text(item.product.name).font(.subheadline.weight(.semibold))
                  Text(item.product.sellerName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.product.priceText).font(.subheadline)
              }
              .padding(.horizontal)
              .padding(.vertical, 8)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider().padding(.leading)
          }
        }
      }
    }
    .tint(Color.accentColor)
    .navigationTitle(room.title)
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $selectedProduct) { product in
      ProductSheet(
        product: product,
        onBuy: { buying = product },
        onSave: {
          Task { try? await backend.save(roomId: nil, productId: product.id, userId: currentUser.id) }
        }
      )
      .sheet(item: $buying) { product in
        CheckoutView(flow: checkout, product: product, buyer: currentUser)
      }
    }
    .alert(saveMessage ?? "", isPresented: Binding(get: { saveMessage != nil }, set: { if !$0 { saveMessage = nil } })) {
      Button("OK", role: .cancel) {}
    }
  }

  private func saveRoom() async {
    do {
      try await backend.save(roomId: room.id, productId: nil, userId: currentUser.id)
      saveMessage = "Saved to your collection"
    } catch {
      saveMessage = "Couldn't save this room"
    }
  }
}

private struct RoomDetailPreview: View {
  let backend = StubBackend()
  @State private var room: Room?
  @State private var products: [Product] = []
  @State private var user: User?

  var body: some View {
    NavigationStack {
      if let room, let user {
        RoomDetailView(room: room, products: products, backend: backend, currentUser: user, checkout: CheckoutFlow(backend: backend), onRemix: {})
      } else {
        ProgressView()
      }
    }
    .task {
      products = (try? await backend.products()) ?? []
      user = try? await backend.users().first
      room = try? await backend.room(id: "stub-room-1")
    }
  }
}

#Preview {
  RoomDetailPreview()
}
