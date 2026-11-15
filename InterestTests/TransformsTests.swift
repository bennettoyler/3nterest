import XCTest
@testable import Interest

final class TransformsTests: XCTestCase {
  func testTransformRoundTrip() {
    let t = transformArray(position: [1, 0, 2], yawRadians: .pi / 2)
    XCTAssertEqual(t.count, 16)
    XCTAssertEqual(t[12], 1, accuracy: 1e-5); XCTAssertEqual(t[14], 2, accuracy: 1e-5)
    XCTAssertEqual(yaw(of: t), .pi / 2, accuracy: 1e-4)
  }
}
