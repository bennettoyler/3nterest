import SceneKit
import XCTest
@testable import Interest

final class FurnitureShapesBedroomTests: XCTestCase {
  private let cases: [(String, Dimensions)] = [
    ("twin bed", Dimensions(width: 1.0, depth: 2.0, height: 0.9)),
    ("king bed", Dimensions(width: 1.95, depth: 2.05, height: 1.0)),
    ("nightstand", Dimensions(width: 0.5, depth: 0.4, height: 0.55)),
    ("dresser", Dimensions(width: 1.4, depth: 0.5, height: 0.85)),
    ("wardrobe", Dimensions(width: 1.0, depth: 0.6, height: 2.0)),
  ]

  private func check(_ name: String, _ s: Dimensions, file: StaticString = #filePath, line: UInt = #line) {
    guard let node = FurnitureShapes.bedroomNode(named: name, size: s) else {
      return XCTFail("nil for \(name)", file: file, line: line)
    }
    let (lo, hi) = shapeBounds(node)
    XCTAssertEqual(hi.x - lo.x, s.width, accuracy: 0.02, "\(name) width", file: file, line: line)
    XCTAssertEqual(hi.y - lo.y, s.height, accuracy: 0.02, "\(name) height", file: file, line: line)
    XCTAssertEqual(hi.z - lo.z, s.depth, accuracy: 0.02, "\(name) depth", file: file, line: line)
    XCTAssertEqual(lo.y, 0, accuracy: 0.01, "\(name) base", file: file, line: line)
  }

  func testTypicalSizes() {
    for (n, s) in cases { check(n, s) }
  }

  func testScaledSizes() {
    for (n, s) in cases {
      check(n, Dimensions(width: s.width * 1.25, depth: s.depth * 1.25, height: s.height * 1.25))
    }
  }

  func testUnknownReturnsNil() {
    XCTAssertNil(FurnitureShapes.bedroomNode(named: "walnut dining chair", size: Dimensions(width: 0.5, depth: 0.5, height: 0.9)))
  }
}
