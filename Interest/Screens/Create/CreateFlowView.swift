import SwiftUI
import UIKit

struct CreateFlowView: View {
  let backend: any Backend
  let products: [Product]
  let currentUser: User
  let checkout: CheckoutFlow
  let onPublished: () -> Void

  @State private var room = Room(
    id: "", ownerId: "", ownerName: "", title: "", thumbnailUrl: nil, published: false,
    shell: RoomShell(walls: [], doors: [], windows: []), placements: [], remixedFromId: nil)
  @State private var editing = false
  @State private var selection: String?
  @State private var sheet: Sheet?
  @State private var buying: Product?

  private enum Sheet: Identifiable {
    case info(Product)
    case swap(Placement)
    case add
    case publish

    var id: String {
      switch self {
      case .info(let product): return "info-\(product.id)"
      case .swap(let placement): return "swap-\(placement.id)"
      case .add: return "add"
      case .publish: return "publish"
      }
    }
  }

  private var selectedPlacement: Placement? {
    room.placements.first { $0.id == selection }
  }

  private var selectedProduct: Product? {
    guard let productId = selectedPlacement?.productId else { return nil }
    return products.first { $0.id == productId }
  }

  var body: some View {
    Group {
      if editing {
        editor
          .safeAreaInset(edge: .bottom) { editorToolbar }
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Start over") {
                selection = nil
                editing = false
              }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Publish") { sheet = .publish }
            }
          }
      } else {
        start
      }
    }
    .navigationTitle("Create")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $sheet) { sheet in
      switch sheet {
      case .info(let product):
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
      case .swap(let placement):
        catalog(title: "Swap \(placement.category.rawValue)", products: products.filter { $0.category == placement.category }) { product in
          guard let index = room.placements.firstIndex(where: { $0.id == placement.id }) else { return }
          room.placements[index].productId = product.id
          room.placements[index].designId = product.designId
        }
      case .add:
        catalog(title: "Add a product", products: products) { product in
          let placement = Placement(
            id: UUID().uuidString, transform: Self.roomCentreTransform(),
            productId: product.id, designId: product.designId,
            category: product.category, scannedSize: nil)
          room.placements.append(placement)
          selection = placement.id
        }
      case .publish:
        PublishSheet(onPublish: publish)
      }
    }
  }

  // TODO(A3): swap this seam for Dev 1's editor once dev1-3d is merged:
  // RoomEditorView(room: $room, products: products, designs: [], selection: $selection, onSnapshot: { snapshot = $0 })
  private var editor: some View {
    PlaceholderRoomEditor(room: $room, products: products, selection: $selection)
  }

  // TODO(A4): swap the sample-room button for Dev 1's scanner once dev1-3d is merged:
  // RoomScanView(products: products, owner: currentUser, onFinish: { room = $0; editing = true })
  private var start: some View {
    VStack(spacing: 16) {
      PinLogo(size: 72)
      Text("Create a room").font(.title2.bold())
      Text("Scan your room, then move, swap and add pieces before you publish it.")
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
      Button {
        var draft = StubBackend.sampleRoom()
        draft.id = ""
        draft.ownerId = currentUser.id
        draft.ownerName = currentUser.name
        draft.title = "My room"
        draft.published = false
        draft.thumbnailUrl = nil
        draft.remixedFromId = nil
        room = draft
        selection = nil
        editing = true
      } label: {
        Label("Start from sample room", systemImage: "cube.transparent").frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var editorToolbar: some View {
    HStack(spacing: 8) {
      toolbarButton("Info", systemImage: "info.circle", disabled: selectedProduct == nil) {
        if let selectedProduct { sheet = .info(selectedProduct) }
      }
      toolbarButton("Swap", systemImage: "arrow.left.arrow.right", disabled: selectedPlacement == nil) {
        if let selectedPlacement { sheet = .swap(selectedPlacement) }
      }
      toolbarButton("Delete", systemImage: "trash", disabled: selectedPlacement == nil) {
        room.placements.removeAll { $0.id == selection }
        selection = nil
      }
      toolbarButton("Add", systemImage: "plus", disabled: false) {
        sheet = .add
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(.bar)
  }

  private func toolbarButton(_ title: String, systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: systemImage).font(.title3)
        Text(title).font(.caption)
      }
      .frame(maxWidth: .infinity)
    }
    .disabled(disabled)
  }

  private func catalog(title: String, products: [Product], onPick: @escaping (Product) -> Void) -> some View {
    NavigationStack {
      CatalogView(products: products) { product in
        onPick(product)
        sheet = nil
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { sheet = nil }
        }
      }
    }
  }

  private func publish(title: String) async throws {
    var draft = room
    draft.title = title
    let id = try await backend.saveRoom(draft)
    room.id = id
    room.title = title
    // TODO(A3): take the JPEG from RoomEditorView's onSnapshot instead of the placeholder.
    try await backend.publish(roomId: id, title: title, thumbnailJPEG: Self.placeholderThumbnailJPEG())
    sheet = nil
    selection = nil
    editing = false
    onPublished()
  }

  // TODO(A3): replace with Dev 1's transformArray(position: .zero, yawRadians: 0) once dev1-3d is merged.
  // Column-major identity: no rotation, translation (0, 0, 0), which is the room centre on the floor.
  private static func roomCentreTransform() -> [Float] {
    [1, 0, 0, 0,
     0, 1, 0, 0,
     0, 0, 1, 0,
     0, 0, 0, 1]
  }

  private static func placeholderThumbnailJPEG() -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let size = CGSize(width: 600, height: 450)
    return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.8) { context in
      UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1).setFill()
      context.fill(CGRect(origin: .zero, size: size))
      UIColor.white.setFill()
      context.fill(CGRect(x: 40, y: 40, width: size.width - 80, height: size.height - 80))
    }
  }
}

// PLACEHOLDER: stands in for Dev 1's RoomEditorView (A3). It lists the placements and lets one be selected,
// so Info, Swap, Delete and Add all work on the Room value. It cannot move or rotate anything.
private struct PlaceholderRoomEditor: View {
  @Binding var room: Room
  let products: [Product]
  @Binding var selection: String?

  var body: some View {
    List {
      Section {
        ForEach(room.placements) { placement in
          let product = products.first { $0.id == placement.productId }
          Button {
            selection = selection == placement.id ? nil : placement.id
          } label: {
            HStack(spacing: 12) {
              if let product {
                ProductThumbnail(product: product)
                  .frame(width: 44, height: 44)
                  .clipShape(RoundedRectangle(cornerRadius: 8))
              }
              VStack(alignment: .leading, spacing: 2) {
                Text(product?.name ?? "Scanned \(placement.category.rawValue)")
                  .font(.subheadline.weight(.semibold))
                Text(product.map { "\($0.sellerName) · \($0.priceText)" } ?? "No matching product")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              if selection == placement.id {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
              }
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      } header: {
        Text("Placeholder editor")
      } footer: {
        Text("The 3D editor replaces this list. Tap a piece to select it.")
      }
    }
  }
}

private struct CreateFlowPreview: View {
  let backend = StubBackend()
  @State private var products: [Product] = []
  @State private var user: User?

  var body: some View {
    NavigationStack {
      if let user {
        CreateFlowView(backend: backend, products: products, currentUser: user, checkout: CheckoutFlow(backend: backend), onPublished: {})
      } else {
        ProgressView()
      }
    }
    .task {
      products = (try? await backend.products()) ?? []
      user = try? await backend.users().first
    }
  }
}

#Preview {
  CreateFlowPreview()
}
