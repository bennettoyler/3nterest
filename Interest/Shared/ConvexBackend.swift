import Combine
import ConvexMobile
import Foundation

final class ConvexBackend: Backend, @unchecked Sendable {
  enum BackendError: Error { case noResult, uploadFailed, timedOut }

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
    try await mutation("rooms:save", ["room": room])
  }

  func publish(roomId: String, title: String, thumbnailJPEG: Data) async throws {
    let uploadUrl: String = try await mutation("files:generateUploadUrl")
    guard let url = URL(string: uploadUrl) else { throw BackendError.uploadFailed }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
    let (data, response) = try await URLSession.shared.upload(for: request, from: thumbnailJPEG)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw BackendError.uploadFailed }
    let storageId = try JSONDecoder().decode(StorageUpload.self, from: data).storageId
    let _: String? = try await mutation("rooms:publish", ["roomId": roomId, "title": title, "storageId": storageId])
  }

  func remix(roomId: String, as userId: String) async throws -> Room {
    try await mutation("rooms:remix", ["roomId": roomId, "userId": userId])
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
    let _: String? = try await mutation("collections:save", args)
  }

  func generateDesign(prompt: String, userId: String) async throws -> Design {
    let design: DesignDTO = try await action("designs:generate", ["prompt": prompt, "userId": userId])
    return design.design
  }

  func designs(ids: [String]) async throws -> [Design] {
    let designs: [DesignDTO] = try await query("designs:byIds", ["ids": ids.map { $0 as ConvexEncodable? }])
    return designs.map(\.design)
  }

  func listForSale(designId: String, priceCents: Int) async throws -> Product {
    let product: ProductDTO = try await mutation(
      "designs:listForSale", ["designId": designId, "priceCents": Double(priceCents)])
    return product.product
  }

  func createCheckout(productId: String, buyerId: String) async throws -> Checkout {
    try await action("payments:createCheckout", ["productId": productId, "buyerId": buyerId])
  }

  func confirmOrder(id: String) async throws -> Order {
    let order: OrderDTO = try await mutation("orders:confirm", ["id": id])
    return order.order
  }

  func earnings(sellerId: String) async throws -> [Order] {
    let orders: [OrderDTO] = try await query("orders:bySeller", ["sellerId": sellerId])
    return orders.map(\.order)
  }

  func seller(forUserId: String) async throws -> Seller? {
    try await query("sellers:forUser", ["userId": forUserId])
  }

  // ConvexClient reconnects forever when the network is down, so every call is raced against a
  // timeout and throws, letting the app fall back to StubBackend.
  private func query<T: Decodable & Sendable>(_ name: String, _ args: [String: ConvexEncodable?]? = nil) async throws -> T {
    try await withTimeout(5) {
      for try await value in self.client.subscribe(to: name, with: args, yielding: T.self).values {
        return value
      }
      throw BackendError.noResult
    }
  }

  private func mutation<T: Decodable & Sendable>(_ name: String, _ args: [String: ConvexEncodable?]? = nil) async throws -> T {
    try await withTimeout(8) { try await self.client.mutation(name, with: args) }
  }

  private func action<T: Decodable & Sendable>(_ name: String, _ args: [String: ConvexEncodable?]? = nil) async throws -> T {
    try await withTimeout(15) { try await self.client.action(name, with: args) }
  }

  private func withTimeout<T: Sendable>(_ seconds: Double, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask { try await work() }
      group.addTask {
        try await Task.sleep(for: .seconds(seconds))
        throw BackendError.timedOut
      }
      defer { group.cancelAll() }
      guard let result = try await group.next() else { throw BackendError.noResult }
      return result
    }
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

private struct CutItemDTO: Decodable {
  var part: String
  var material: String
  var lengthCm: Float
  var widthCm: Float
  var thicknessCm: Float
  @ConvexFloat var quantity: Double

  var cutItem: CutItem {
    CutItem(
      part: part, material: material, lengthCm: lengthCm, widthCm: widthCm, thicknessCm: thicknessCm,
      quantity: Int(quantity.rounded()))
  }
}

private struct DesignDTO: Decodable {
  var id: String
  var ownerId: String
  var prompt: String
  var title: String
  var parts: [DesignPart]
  var cutList: [CutItemDTO]
  var hardware: [String]
  var steps: [String]

  var design: Design {
    Design(
      id: id, ownerId: ownerId, prompt: prompt, title: title, parts: parts, cutList: cutList.map(\.cutItem),
      hardware: hardware, steps: steps)
  }
}

private struct OrderDTO: Decodable {
  var id: String
  var productId: String
  var productName: String
  var sellerId: String
  var sellerName: String
  @ConvexFloat var amountCents: Double
  @ConvexFloat var platformFeeCents: Double
  @ConvexFloat var sellerCents: Double
  var status: OrderStatus

  var order: Order {
    Order(
      id: id, productId: productId, productName: productName, sellerId: sellerId, sellerName: sellerName,
      amountCents: Int(amountCents.rounded()), platformFeeCents: Int(platformFeeCents.rounded()),
      sellerCents: Int(sellerCents.rounded()), status: status)
  }
}
