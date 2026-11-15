import Combine
import ConvexMobile
import Foundation

final class ConvexBackend: Backend {
  enum BackendError: Error { case notImplemented, noResult, uploadFailed }

  private let client: ConvexClient

  init(deploymentUrl: String) {
    client = ConvexClient(deploymentUrl: deploymentUrl)
  }

  func users() async throws -> [User] {
    try await query("users:list")
  }

  func feed() -> AsyncStream<[Room]> {
    AsyncStream { continuation in
      let cancellable = client.subscribe(to: "rooms:feed", yielding: [Room].self)
        .sink(
          receiveCompletion: { _ in continuation.finish() },
          receiveValue: { continuation.yield($0) })
      continuation.onTermination = { _ in cancellable.cancel() }
    }
  }

  func room(id: String) async throws -> Room {
    try await query("rooms:get", ["id": id])
  }

  func rooms(ownerId: String) async throws -> [Room] {
    try await query("rooms:byOwner", ["ownerId": ownerId])
  }

  func saveRoom(_ room: Room) async throws -> String {
    try await client.mutation("rooms:save", with: ["room": room])
  }

  func publish(roomId: String, title: String, thumbnailJPEG: Data) async throws {
    let uploadUrl: String = try await client.mutation("files:generateUploadUrl")
    guard let url = URL(string: uploadUrl) else { throw BackendError.uploadFailed }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
    let (data, response) = try await URLSession.shared.upload(for: request, from: thumbnailJPEG)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw BackendError.uploadFailed }
    let storageId = try JSONDecoder().decode(StorageUpload.self, from: data).storageId
    try await client.mutation("rooms:publish", with: ["roomId": roomId, "title": title, "storageId": storageId])
  }

  func remix(roomId: String, as userId: String) async throws -> Room {
    try await client.mutation("rooms:remix", with: ["roomId": roomId, "userId": userId])
  }

  func products() async throws -> [Product] {
    let products: [ProductDTO] = try await query("products:list")
    return products.map(\.product)
  }

  func collections(userId: String) async throws -> [SavedCollection] {
    try await query("collections:mine", ["userId": userId])
  }

  func save(roomId: String?, productId: String?, userId: String) async throws {
    var args: [String: ConvexEncodable?] = ["userId": userId]
    if let roomId { args["roomId"] = roomId }
    if let productId { args["productId"] = productId }
    try await client.mutation("collections:save", with: args)
  }

  func generateDesign(prompt: String, userId: String) async throws -> Design {
    throw BackendError.notImplemented
  }

  func designs(ids: [String]) async throws -> [Design] {
    throw BackendError.notImplemented
  }

  func listForSale(designId: String, priceCents: Int) async throws -> Product {
    throw BackendError.notImplemented
  }

  func createCheckout(productId: String, buyerId: String) async throws -> Checkout {
    throw BackendError.notImplemented
  }

  func confirmOrder(id: String) async throws -> Order {
    throw BackendError.notImplemented
  }

  func earnings(sellerId: String) async throws -> [Order] {
    throw BackendError.notImplemented
  }

  func seller(forUserId: String) async throws -> Seller? {
    try await query("sellers:forUser", ["userId": forUserId])
  }

  private func query<T: Decodable>(_ name: String, _ args: [String: ConvexEncodable?]? = nil) async throws -> T {
    for try await value in client.subscribe(to: name, with: args, yielding: T.self).values {
      return value
    }
    throw BackendError.noResult
  }
}

extension Room: ConvexEncodable {}

private struct StorageUpload: Decodable { var storageId: String }

// Convex numbers arrive as JSON floats; Swift's JSONDecoder will not decode 18900.0 into Int,
// so Int fields of the shared models are decoded as Double here and rounded.
private struct ProductDTO: Decodable {
  var id: String
  var sellerId: String
  var sellerName: String
  var name: String
  var category: FurnitureCategory
  @ConvexFloat var priceCents: Double
  var dimensions: Dimensions
  var modelUrl: URL?
  var thumbnailUrl: URL?
  var instructionsUrl: URL?
  var vendorUrl: URL?
  var designId: String?

  var product: Product {
    Product(
      id: id, sellerId: sellerId, sellerName: sellerName, name: name, category: category,
      priceCents: Int(priceCents.rounded()), dimensions: dimensions, modelUrl: modelUrl,
      thumbnailUrl: thumbnailUrl, instructionsUrl: instructionsUrl, vendorUrl: vendorUrl, designId: designId)
  }
}
