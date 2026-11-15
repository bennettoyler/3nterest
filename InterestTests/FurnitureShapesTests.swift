import XCTest
import SceneKit
@testable import Interest

final class FurnitureShapesTests: XCTestCase {
  func testBoundingBoxMatchesDimensionsForEveryCategoryAndSize() {
    let sizes: [Dimensions] = [
      .init(width: 0.9, depth: 0.7, height: 0.8),
      .init(width: 0.2, depth: 0.2, height: 0.2),
      .init(width: 2.2, depth: 0.9, height: 0.4),
    ]
    for category in FurnitureCategory.allCases {
      for d in sizes {
        let node = ModelCache.fallbackBox(for: Product.fixture(category: category, dimensions: d))
        let (lo, hi) = node.boundingBox
        let tag = "\(category) \(d)"
        XCTAssertEqual(hi.x - lo.x, d.width, accuracy: 0.01, tag)
        XCTAssertEqual(hi.y - lo.y, d.height, accuracy: 0.01, tag)
        XCTAssertEqual(hi.z - lo.z, d.depth, accuracy: 0.01, tag)
        XCTAssertEqual(lo.y, 0, accuracy: 0.01, tag)
        XCTAssertEqual((lo.x + hi.x) / 2, 0, accuracy: 0.01, tag)
        XCTAssertEqual((lo.z + hi.z) / 2, 0, accuracy: 0.01, tag)
      }
    }
  }
}
