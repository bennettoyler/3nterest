import Foundation

protocol Backend {
  func users() async throws -> [User]
  func feed() -> AsyncStream<[Room]>                       // live; newest first
  func room(id: String) async throws -> Room
  func rooms(ownerId: String) async throws -> [Room]       // published and drafts, newest first
  func saveRoom(_ room: Room) async throws -> String       // returns id; creates if id is empty
  func publish(roomId: String, title: String, thumbnailJPEG: Data) async throws
  func remix(roomId: String, as userId: String) async throws -> Room
  func products() async throws -> [Product]
  func collections(userId: String) async throws -> [SavedCollection]
  func save(roomId: String?, productId: String?, userId: String) async throws   // into the user's default "Saved" collection
  func generateDesign(prompt: String, userId: String) async throws -> Design
  func designs(ids: [String]) async throws -> [Design]
  func listForSale(designId: String, priceCents: Int) async throws -> Product
  /// Stores a user-scanned object as a product (priceCents 0, category .other) owned by the user. Returns it with modelUrl set.
  func createScannedProduct(name: String, dimensions: Dimensions, modelUSDZ: Data, thumbnailJPEG: Data?, userId: String) async throws -> Product
  func createCheckout(productId: String, buyerId: String) async throws -> Checkout
  func confirmOrder(id: String) async throws -> Order
  func earnings(sellerId: String) async throws -> [Order]
  func seller(forUserId: String) async throws -> Seller?
}
