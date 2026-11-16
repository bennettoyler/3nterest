import SwiftUI
import UIKit

enum CreateRequest: Equatable {
  case place(Design)
  case edit(Room)
}

struct CreateFlowView: View {
  @Binding var request: CreateRequest?
  let backend: any Backend
  let products: [Product]
  let currentUser: User
  let checkout: CheckoutFlow
  let onPublished: () -> Void

  @State private var room = Room(
    id: "", ownerId: "", ownerName: "", title: "", thumbnailUrl: nil, published: false,
    shell: RoomShell(walls: [], doors: [], windows: []), placements: [], remixedFromId: nil)
  @State private var designs: [Design] = []
  @State private var editing = false
  @State private var selection: String?
  @State private var sheet: Sheet?
  @State private var buying: Product?
  @State private var snapshot: (() -> Data?)?
  @State private var scanningObject = false
  @State private var scannedProducts: [Product] = []
  @State private var savedLocallyOnly = false

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
    return (products + scannedProducts).first { $0.id == productId }
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
    .task(id: room.placements.compactMap(\.designId)) {
      let missing = room.placements.compactMap(\.designId).filter { id in !designs.contains { $0.id == id } }
      guard !missing.isEmpty, let loaded = try? await backend.designs(ids: missing) else { return }
      designs.append(contentsOf: loaded.filter { design in !designs.contains { $0.id == design.id } })
    }
    .task(id: request) {
      guard let request else { return }
      switch request {
      case .edit(let copy):
        room = copy
        selection = nil
      case .place(let design):
        if !editing {
          if let latest = try? await backend.rooms(ownerId: currentUser.id).first {
            room = latest
          } else {
            room = await sampleDraft()
          }
        }
        let placement = Placement(
          id: UUID().uuidString, transform: Self.roomCentreTransform(),
          productId: nil, designId: design.id, category: .other, scannedSize: nil)
        designs.append(design)
        room.placements.append(placement)
        selection = placement.id
      }
      editing = true
      self.request = nil
    }
    .fullScreenCover(isPresented: $scanningObject) {
      ObjectScanView(
        upload: uploadScanned,
        onFinish: { product, scanned in
          scanningObject = false
          placeScanned(product, scanned)
        },
        onCancel: { scanningObject = false }
      )
    }
    .alert("Saved on this phone only", isPresented: $savedLocallyOnly) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("The object is in your room, but it won't appear after publishing until the backend is updated.")
    }
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

  private var editor: some View {
    RoomEditorView(room: $room, products: products + scannedProducts, designs: designs, selection: $selection, onSnapshot: { snapshot = $0 })
      .id(designs.map(\.id))
  }

  private var start: some View {
    RoomScanView(products: products, owner: currentUser, onFinish: { scanned in
      Task {
        room = await withCatalogProducts(scanned)
        selection = nil
        editing = true
      }
    })
  }

  // The bundled sample room names StubBackend product ids; point them at the live catalog by product name.
  private func withCatalogProducts(_ room: Room) async -> Room {
    var room = room
    let stubProducts = (try? await StubBackend().products()) ?? []
    for index in room.placements.indices {
      guard let stub = stubProducts.first(where: { $0.id == room.placements[index].productId }),
        let match = products.first(where: { $0.name == stub.name })
      else { continue }
      room.placements[index].productId = match.id
    }
    return room
  }

  private func sampleDraft() async -> Room {
    var draft = StubBackend.sampleRoom()
    draft.id = ""
    draft.ownerId = currentUser.id
    draft.ownerName = currentUser.name
    draft.title = "My room"
    draft.published = false
    draft.thumbnailUrl = nil
    draft.remixedFromId = nil
    return await withCatalogProducts(draft)
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
      toolbarButton("Scan", systemImage: "viewfinder", disabled: false) {
        scanningObject = true
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

  private func uploadScanned(_ scanned: ScannedObject) async throws -> Product {
    do {
      let data = try Data(contentsOf: scanned.modelUSDZ)
      return try await backend.createScannedProduct(
        name: scanned.name, dimensions: scanned.dimensions, modelUSDZ: data,
        thumbnailJPEG: scanned.thumbnailJPEG, userId: currentUser.id)
    } catch {
      // ObjectScanView primes ModelCache for the returned product, so no prime here.
      return Product(
        id: "local-scan-\(UUID().uuidString)", sellerId: "", sellerName: currentUser.name,
        name: scanned.name, category: .other, priceCents: 0, dimensions: scanned.dimensions,
        modelUrl: scanned.modelUSDZ, thumbnailUrl: nil, instructionsUrl: nil, vendorUrl: nil, designId: nil)
    }
  }

  private func placeScanned(_ product: Product, _ scanned: ScannedObject) {
    if !scannedProducts.contains(where: { $0.id == product.id }) { scannedProducts.append(product) }
    var transform = Self.roomCentreTransform()
    if scanned.wallMounted { transform[13] = 1.0 }
    let placement = Placement(
      id: UUID().uuidString, transform: transform, productId: product.id, designId: nil,
      category: .other, scannedSize: nil)
    room.placements.append(placement)
    selection = placement.id
    if product.id.hasPrefix("local-scan-") { savedLocallyOnly = true }
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
    let jpeg = snapshot?() ?? Self.placeholderThumbnailJPEG()
    try await backend.publish(roomId: id, title: title, thumbnailJPEG: jpeg)
    sheet = nil
    selection = nil
    editing = false
    onPublished()
  }

  private static func roomCentreTransform() -> [Float] {
    transformArray(position: .zero, yawRadians: 0)
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

private struct CreateFlowPreview: View {
  let backend = StubBackend()
  @State private var products: [Product] = []
  @State private var user: User?

  var body: some View {
    NavigationStack {
      if let user {
        CreateFlowView(request: .constant(nil), backend: backend, products: products, currentUser: user, checkout: CheckoutFlow(backend: backend), onPublished: {})
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
