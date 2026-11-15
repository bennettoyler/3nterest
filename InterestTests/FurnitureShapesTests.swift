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

  func testProductSpecificShapesFillDimensions() {
    let items: [(String, FurnitureCategory, Dimensions)] = [
      ("Vik White Stacking Chair", .chair, .init(width: 0.48, depth: 0.52, height: 0.85)),
      ("Aero Mesh Task Chair", .chair, .init(width: 0.62, depth: 0.66, height: 1.10)),
      ("Flip-Top Rolling Table", .table, .init(width: 1.6, depth: 0.8, height: 0.75)),
      ("Rattan Cane Sideboard", .storage, .init(width: 1.6, depth: 0.45, height: 0.85)),
      ("Lumen 75-inch Wall TV", .television, .init(width: 1.85, depth: 0.08, height: 1.0)),
    ]
    for (name, cat, d) in items {
      let product = Product.fixture(name: name, category: cat, dimensions: d)
      guard let node = FurnitureShapes.node(for: product) else { XCTFail("nil for \(name)"); continue }
      let (lo, hi) = node.boundingBox
      XCTAssertEqual(hi.x - lo.x, d.width, accuracy: 0.02, name)
      XCTAssertEqual(hi.y - lo.y, d.height, accuracy: 0.02, name)
      XCTAssertEqual(hi.z - lo.z, d.depth, accuracy: 0.02, name)
      XCTAssertEqual(lo.y, 0, accuracy: 0.02, name)
    }
    XCTAssertNil(FurnitureShapes.node(for: Product.fixture(name: "Walnut Dining Chair")))
  }
}
