import Foundation

enum FurnitureCategory: String, Codable, CaseIterable { case chair, table, sofa, bed, storage, television, other }
struct Dimensions: Codable, Hashable { var width: Float; var depth: Float; var height: Float }   // metres
struct Surface: Codable, Hashable { var transform: [Float]; var width: Float; var height: Float }
struct RoomShell: Codable, Hashable { var walls: [Surface]; var doors: [Surface]; var windows: [Surface] }
struct Placement: Codable, Identifiable, Hashable {
  var id: String; var transform: [Float]
  var productId: String?; var designId: String?
  var category: FurnitureCategory; var scannedSize: Dimensions?
}
struct Room: Codable, Identifiable, Hashable {
  var id: String; var ownerId: String; var ownerName: String; var title: String
  var thumbnailUrl: URL?; var published: Bool
  var shell: RoomShell; var placements: [Placement]; var remixedFromId: String?
}
struct Product: Codable, Identifiable, Hashable {
  var id: String; var sellerId: String; var sellerName: String; var name: String
  var category: FurnitureCategory; var priceCents: Int; var dimensions: Dimensions
  var modelUrl: URL?; var thumbnailUrl: URL?; var instructionsUrl: URL?; var vendorUrl: URL?
  var designId: String?
}
enum PartShape: String, Codable { case box, cylinder }
struct DesignPart: Codable, Hashable {
  var name: String; var shape: PartShape
  var sizeCm: [Float]; var positionCm: [Float]; var rotationDeg: [Float]   // 3 each; cylinder size = [diameter, height, diameter]
  var material: String; var colorHex: String
}
struct CutItem: Codable, Hashable { var part: String; var material: String; var lengthCm: Float; var widthCm: Float; var thicknessCm: Float; var quantity: Int }
struct Design: Codable, Identifiable, Hashable {
  var id: String; var ownerId: String; var prompt: String; var title: String
  var parts: [DesignPart]; var cutList: [CutItem]; var hardware: [String]; var steps: [String]
}
struct User: Codable, Identifiable, Hashable { var id: String; var name: String; var avatarUrl: URL? }
struct Seller: Codable, Identifiable, Hashable { var id: String; var name: String; var kind: String; var logoUrl: URL? }
enum OrderStatus: String, Codable { case pending, paid }
struct Order: Codable, Identifiable, Hashable {
  var id: String; var productId: String; var productName: String; var sellerId: String; var sellerName: String
  var amountCents: Int; var platformFeeCents: Int; var sellerCents: Int; var status: OrderStatus
}
struct Checkout: Codable { var orderId: String; var checkoutUrl: URL }
struct SavedCollection: Codable, Identifiable, Hashable { var id: String; var name: String; var roomIds: [String]; var productIds: [String] }
