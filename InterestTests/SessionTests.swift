import XCTest
@testable import Interest

final class SessionTests: XCTestCase {
  func testFallsBackWhenPrimaryFails() async {
    let s = Session(primary: FailingBackend(), fallback: StubBackend())   // FailingBackend: every call throws
    await s.start()
    XCTAssertTrue(s.backend is StubBackend); XCTAssertFalse(s.products.isEmpty)
  }
}
