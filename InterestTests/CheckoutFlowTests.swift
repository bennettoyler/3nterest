import XCTest
@testable import Interest

final class CheckoutFlowTests: XCTestCase {
  func testDismissWithoutPayingShowsNoReceipt() async throws {
    let f = CheckoutFlow(backend: StubBackend())
    _ = try await f.begin(product: .fixture(), buyer: .fixture())
    f.dismissedWithoutReturn()
    XCTAssertEqual(f.state, .cancelled)
  }

  func testReturnForDifferentOrderIsIgnored() async throws {
    let f = CheckoutFlow(backend: StubBackend())
    _ = try await f.begin(product: .fixture(), buyer: .fixture())
    await f.handleReturn(url: URL(string: "interest://paid?order=not-this-one")!)
    if case .paid = f.state { XCTFail("should not be paid") }
  }

  func testMatchingReturnReachesPaid() async throws {
    let f = CheckoutFlow(backend: StubBackend())
    _ = try await f.begin(product: .fixture(id: "stub-chair"), buyer: .fixture())
    guard case .inCheckout(let orderId) = f.state else { return XCTFail("should be in checkout") }
    await f.handleReturn(url: URL(string: "interest://paid?order=\(orderId)")!)
    guard case .paid(let order) = f.state else { return XCTFail("should be paid") }
    XCTAssertEqual(order.id, orderId)
    XCTAssertEqual(order.status, .paid)
    XCTAssertEqual(order.amountCents, 18900)
    XCTAssertEqual(order.platformFeeCents, 945)
    XCTAssertEqual(order.sellerCents, 17955)
  }

  func testUnpaidOrderStaysInCheckoutUntilPaymentIsFound() async throws {
    let backend = UnpaidBackend(error: UnpaidBackend.ServerError(message: "Uncaught Error: PAYMENT_NOT_FOUND: no payment for this order"))
    let f = CheckoutFlow(backend: backend)
    _ = try await f.begin(product: .fixture(id: "stub-chair"), buyer: .fixture())
    guard case .inCheckout(let orderId) = f.state else { return XCTFail("should be in checkout") }
    let done = URL(string: "interest://paid?order=\(orderId)")!

    await f.handleReturn(url: done)
    XCTAssertEqual(f.state, .inCheckout(orderId: orderId))
    XCTAssertEqual(f.confirmError, "We couldn't find your payment yet. Finish paying, then tap again.")
    XCTAssertFalse(f.isConfirming)

    backend.paid = true
    await f.handleReturn(url: done)
    guard case .paid(let order) = f.state else { return XCTFail("should be paid") }
    XCTAssertEqual(order.id, orderId)
    XCTAssertNil(f.confirmError)
  }

  func testOtherConfirmErrorStaysInCheckoutWithGenericMessage() async throws {
    let f = CheckoutFlow(backend: UnpaidBackend(error: UnpaidBackend.ServerError(message: "timed out")))
    _ = try await f.begin(product: .fixture(), buyer: .fixture())
    guard case .inCheckout(let orderId) = f.state else { return XCTFail("should be in checkout") }
    await f.handleReturn(url: URL(string: "interest://paid?order=\(orderId)")!)
    XCTAssertEqual(f.state, .inCheckout(orderId: orderId))
    XCTAssertEqual(f.confirmError, "Couldn't confirm the payment. Try again.")
  }

  func testDismissAfterFailedConfirmShowsNoReceipt() async throws {
    let f = CheckoutFlow(backend: UnpaidBackend(error: UnpaidBackend.ServerError(message: "PAYMENT_NOT_FOUND")))
    _ = try await f.begin(product: .fixture(), buyer: .fixture())
    guard case .inCheckout(let orderId) = f.state else { return XCTFail("should be in checkout") }
    await f.handleReturn(url: URL(string: "interest://paid?order=\(orderId)")!)
    f.dismissedWithoutReturn()
    XCTAssertEqual(f.state, .cancelled)
  }
}

private final class UnpaidBackend: Backend, @unchecked Sendable {
  struct ServerError: Error { var message: String }

  let stub = StubBackend()
  let error: Error
  var paid = false

  init(error: Error) { self.error = error }

  func confirmOrder(id: String) async throws -> Order {
    guard paid else { throw error }
    return try await stub.confirmOrder(id: id)
  }

  func users() async throws -> [User] { try await stub.users() }
  func feed() -> AsyncStream<[Room]> { stub.feed() }
  func room(id: String) async throws -> Room { try await stub.room(id: id) }
  func rooms(ownerId: String) async throws -> [Room] { try await stub.rooms(ownerId: ownerId) }
  func saveRoom(_ room: Room) async throws -> String { try await stub.saveRoom(room) }
  func publish(roomId: String, title: String, thumbnailJPEG: Data) async throws {
    try await stub.publish(roomId: roomId, title: title, thumbnailJPEG: thumbnailJPEG)
  }
  func remix(roomId: String, as userId: String) async throws -> Room { try await stub.remix(roomId: roomId, as: userId) }
  func products() async throws -> [Product] { try await stub.products() }
  func collections(userId: String) async throws -> [SavedCollection] { try await stub.collections(userId: userId) }
  func save(roomId: String?, productId: String?, userId: String) async throws {
    try await stub.save(roomId: roomId, productId: productId, userId: userId)
  }
  func generateDesign(prompt: String, userId: String) async throws -> Design {
    try await stub.generateDesign(prompt: prompt, userId: userId)
  }
  func designs(ids: [String]) async throws -> [Design] { try await stub.designs(ids: ids) }
  func listForSale(designId: String, priceCents: Int) async throws -> Product {
    try await stub.listForSale(designId: designId, priceCents: priceCents)
  }
  func createCheckout(productId: String, buyerId: String) async throws -> Checkout {
    try await stub.createCheckout(productId: productId, buyerId: buyerId)
  }
  func earnings(sellerId: String) async throws -> [Order] { try await stub.earnings(sellerId: sellerId) }
  func seller(forUserId: String) async throws -> Seller? { try await stub.seller(forUserId: forUserId) }
}
