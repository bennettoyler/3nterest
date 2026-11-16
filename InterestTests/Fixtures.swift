import Foundation
@testable import Interest

extension Product {
  static func fixture(
    id: String = "fixture-product",
    sellerId: String = "fixture-seller",
    sellerName: String = "Fixture Seller",
    name: String = "Fixture Product",
    category: FurnitureCategory = .chair,
    priceCents: Int = 4999,
    dimensions: Dimensions = Dimensions(width: 0.5, depth: 0.5, height: 0.9),
    modelUrl: URL? = nil,
    thumbnailUrl: URL? = nil,
    instructionsUrl: URL? = nil,
    vendorUrl: URL? = nil,
    designId: String? = nil
  ) -> Product {
    Product(
      id: id, sellerId: sellerId, sellerName: sellerName, name: name, category: category,
      priceCents: priceCents, dimensions: dimensions, modelUrl: modelUrl, thumbnailUrl: thumbnailUrl,
      instructionsUrl: instructionsUrl, vendorUrl: vendorUrl, designId: designId)
  }
}

extension Design {
  static func fixture(
    id: String = "fixture-design",
    ownerId: String = "fixture-user",
    prompt: String = "a fixture",
    title: String = "Fixture Design",
    parts: [DesignPart] = [],
    cutList: [CutItem] = [],
    hardware: [String] = [],
    steps: [String] = []
  ) -> Design {
    Design(id: id, ownerId: ownerId, prompt: prompt, title: title, parts: parts, cutList: cutList, hardware: hardware, steps: steps)
  }
}

extension User {
  static func fixture(id: String = "fixture-user", name: String = "Fixture User", avatarUrl: URL? = nil) -> User {
    User(id: id, name: name, avatarUrl: avatarUrl)
  }
}

extension RoomShell {
  static func rectangle(width: Float, depth: Float) -> RoomShell {
    let height: Float = 2.5
    let x = width / 2, y = height / 2, z = depth / 2
    return RoomShell(
      walls: [
        Surface(transform: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, y, -z, 1], width: width, height: height),
        Surface(transform: [0, 0, 1, 0, 0, 1, 0, 0, -1, 0, 0, 0, x, y, 0, 1], width: depth, height: height),
        Surface(transform: [-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, y, z, 1], width: width, height: height),
        Surface(transform: [0, 0, -1, 0, 0, 1, 0, 0, 1, 0, 0, 0, -x, y, 0, 1], width: depth, height: height),
      ],
      doors: [], windows: [])
  }
}

struct FailingBackend: Backend {
  struct Failure: Error {}

  func users() async throws -> [User] { throw Failure() }
  func feed() -> AsyncStream<[Room]> { AsyncStream { $0.finish() } }
  func room(id: String) async throws -> Room { throw Failure() }
  func rooms(ownerId: String) async throws -> [Room] { throw Failure() }
  func saveRoom(_ room: Room) async throws -> String { throw Failure() }
  func publish(roomId: String, title: String, thumbnailJPEG: Data) async throws { throw Failure() }
  func remix(roomId: String, as userId: String) async throws -> Room { throw Failure() }
  func products() async throws -> [Product] { throw Failure() }
  func collections(userId: String) async throws -> [SavedCollection] { throw Failure() }
  func save(roomId: String?, productId: String?, userId: String) async throws { throw Failure() }
  func generateDesign(prompt: String, userId: String) async throws -> Design { throw Failure() }
  func designs(ids: [String]) async throws -> [Design] { throw Failure() }
  func listForSale(designId: String, priceCents: Int) async throws -> Product { throw Failure() }
  func createScannedProduct(name: String, dimensions: Dimensions, modelUSDZ: Data, thumbnailJPEG: Data?, userId: String) async throws -> Product { throw Failure() }
  func createCheckout(productId: String, buyerId: String) async throws -> Checkout { throw Failure() }
  func confirmOrder(id: String) async throws -> Order { throw Failure() }
  func earnings(sellerId: String) async throws -> [Order] { throw Failure() }
  func seller(forUserId: String) async throws -> Seller? { throw Failure() }
}
