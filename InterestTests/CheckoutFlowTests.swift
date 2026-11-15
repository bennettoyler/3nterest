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
}
