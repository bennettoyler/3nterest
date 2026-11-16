import XCTest
import SceneKit
@testable import Interest

final class FurnitureShapesKitchenBathTests: XCTestCase {
  private let cases: [(String, Dimensions)] = [
    ("refrigerator", Dimensions(width: 0.75, depth: 0.72, height: 1.8)),
    ("stove", Dimensions(width: 0.76, depth: 0.66, height: 0.92)),
    ("sink", Dimensions(width: 0.8, depth: 0.6, height: 0.9)),
    ("dishwasher", Dimensions(width: 0.6, depth: 0.6, height: 0.85)),
    ("washer", Dimensions(width: 0.6, depth: 0.62, height: 0.85)),
    ("toilet", Dimensions(width: 0.4, depth: 0.7, height: 0.78)),
    ("bathtub", Dimensions(width: 1.7, depth: 0.76, height: 0.56)),
  ]

  private func check(_ name: String, _ s: Dimensions) {
    guard let node = FurnitureShapes.kitchenBathNode(named: name, size: s) else {
      return XCTFail("nil for \(name)")
    }
    var lo = SCNVector3(Float.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude)
    var hi = SCNVector3(-Float.greatestFiniteMagnitude, -.greatestFiniteMagnitude, -.greatestFiniteMagnitude)
    func visit(_ n: SCNNode) {
      if n.geometry != nil {
        let (a, b) = n.boundingBox
        for i in 0..<8 {
          let q = n.convertPosition(SCNVector3(i & 1 == 0 ? a.x : b.x, i & 2 == 0 ? a.y : b.y, i & 4 == 0 ? a.z : b.z), to: node)
          lo = SCNVector3(min(lo.x, q.x), min(lo.y, q.y), min(lo.z, q.z))
          hi = SCNVector3(max(hi.x, q.x), max(hi.y, q.y), max(hi.z, q.z))
        }
      }
      n.childNodes.forEach(visit)
    }
    visit(node)
    XCTAssertEqual(Float(hi.x - lo.x), s.width, accuracy: 0.02, name)
    XCTAssertEqual(Float(hi.y - lo.y), s.height, accuracy: 0.02, name)
    XCTAssertEqual(Float(hi.z - lo.z), s.depth, accuracy: 0.02, name)
    XCTAssertEqual(Float(lo.y), 0, accuracy: 0.01, name)
  }

  func testTypicalSizes() { for (n, s) in cases { check(n, s) } }

  func testScaledSizes() {
    for (n, s) in cases {
      check(n, Dimensions(width: s.width * 1.25, depth: s.depth * 1.25, height: s.height * 1.25))
    }
  }

  func testKeywords() {
    let s = Dimensions(width: 0.6, depth: 0.6, height: 0.85)
    XCTAssertNotNil(FurnitureShapes.kitchenBathNode(named: "dishwasher", size: s))
    XCTAssertNotNil(FurnitureShapes.kitchenBathNode(named: "front-load washer", size: s))
    XCTAssertNil(FurnitureShapes.kitchenBathNode(named: "walnut dining chair", size: s))
  }
}
