import XCTest
@testable import Interest

final class StubBackendTests: XCTestCase {
  func testSampleRoomDecodesAsClosedRectangle() throws {
    let url = try XCTUnwrap(Bundle(for: StubBackend.self).url(forResource: "SampleRoom", withExtension: "json"))
    let room = try JSONDecoder().decode(Room.self, from: Data(contentsOf: url))
    XCTAssertEqual(room.shell.walls.count, 4)
    XCTAssertEqual(room.shell.doors.count, 1)
    XCTAssertEqual(room.shell.windows.count, 4)
    XCTAssertEqual(room.placements.count, 20)
    for surface in room.shell.walls + room.shell.doors + room.shell.windows {
      XCTAssertEqual(surface.transform.count, 16)
    }
    for placement in room.placements {
      XCTAssertEqual(placement.transform.count, 16)
      if placement.category != .television {
        XCTAssertEqual(placement.transform[13], 0, accuracy: 1e-3)
      }
    }
    var corners: [String: Int] = [:]
    var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
    var minZ = Float.greatestFiniteMagnitude, maxZ = -Float.greatestFiniteMagnitude
    for wall in room.shell.walls {
      XCTAssertEqual(wall.transform[13] - wall.height / 2, 0, accuracy: 1e-3)
      for side: Float in [-1, 1] {
        let x = wall.transform[12] + side * wall.width / 2 * wall.transform[0]
        let z = wall.transform[14] + side * wall.width / 2 * wall.transform[2]
        corners["\(Int((x * 100).rounded())),\(Int((z * 100).rounded()))", default: 0] += 1
        minX = min(minX, x); maxX = max(maxX, x); minZ = min(minZ, z); maxZ = max(maxZ, z)
      }
    }
    XCTAssertEqual(corners.count, 4)
    XCTAssertTrue(corners.values.allSatisfy { $0 == 2 }, "\(corners)")
    XCTAssertEqual(maxX - minX, 7.60, accuracy: 0.02)
    XCTAssertEqual(maxZ - minZ, 5.71, accuracy: 0.02)
  }

  func testFeedYieldsSixPublishedRooms() async {
    var iterator = StubBackend().feed().makeAsyncIterator()
    let rooms = await iterator.next()
    XCTAssertEqual(rooms?.count, 6)
    XCTAssertEqual(rooms?.allSatisfy(\.published), true)
    XCTAssertEqual(Set(rooms?.map(\.title) ?? []).count, 6)
  }

  func testStubCatalogAndCheckoutSplit() async throws {
    let backend = StubBackend()
    let products = try await backend.products()
    XCTAssertEqual(products.count, 31)
    XCTAssertEqual(Set(products.map(\.category)), Set(FurnitureCategory.allCases))
    let checkout = try await backend.createCheckout(productId: "stub-chair", buyerId: "stub-user-2")
    XCTAssertEqual(checkout.checkoutUrl.absoluteString, "https://example.com/checkout")
    let pending = try await backend.earnings(sellerId: "stub-seller-parcel")
    XCTAssertTrue(pending.isEmpty)
    let order = try await backend.confirmOrder(id: checkout.orderId)
    XCTAssertEqual(order.status, .paid)
    XCTAssertEqual(order.amountCents, 18900)
    XCTAssertEqual(order.platformFeeCents, 945)
    XCTAssertEqual(order.sellerCents, 17955)
  }

  func testCreateScannedProduct() async throws {
    let backend = StubBackend()
    let bytes = Data([1, 2, 3, 4, 5])
    let product = try await backend.createScannedProduct(
      name: "Scanned Vase", dimensions: Dimensions(width: 0.2, depth: 0.2, height: 0.4),
      modelUSDZ: bytes, thumbnailJPEG: nil, userId: "stub-user-1")
    XCTAssertEqual(product.priceCents, 0)
    XCTAssertEqual(product.category, .other)
    let url = try XCTUnwrap(product.modelUrl)
    XCTAssertTrue(url.isFileURL)
    XCTAssertEqual(try Data(contentsOf: url), bytes)
    let products = try await backend.products()
    XCTAssertEqual(products.count, 32)
    XCTAssertTrue(products.contains { $0.id == product.id })
  }
}
