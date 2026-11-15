import XCTest
import SceneKit
@testable import Interest

final class ModelCacheTests: XCTestCase {
  func testMissingModelFallsBackToBoxAtProductSize() async {
    let p = Product.fixture(dimensions: .init(width: 0.8, depth: 0.6, height: 0.9), modelUrl: URL(string: "https://invalid.invalid/x.usdz"))
    let node = await ModelCache.shared.node(for: p)
    let (lo, hi) = node.boundingBox
    XCTAssertEqual(hi.x - lo.x, 0.8, accuracy: 0.01); XCTAssertEqual(hi.y - lo.y, 0.9, accuracy: 0.01)
    XCTAssertEqual(lo.y, 0, accuracy: 0.01)
  }
}
