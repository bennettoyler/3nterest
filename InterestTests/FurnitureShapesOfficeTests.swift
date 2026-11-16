import SceneKit
import XCTest
@testable import Interest

final class FurnitureShapesOfficeTests: XCTestCase {
  private let cases: [(String, Dimensions)] = [
    ("writing desk", Dimensions(width: 1.4, depth: 0.7, height: 0.75)),
    ("filing cabinet", Dimensions(width: 0.45, depth: 0.6, height: 1.1)),
    ("bookshelf", Dimensions(width: 0.9, depth: 0.32, height: 1.9)),
    ("whiteboard", Dimensions(width: 1.5, depth: 0.5, height: 1.9)),
    ("round meeting table", Dimensions(width: 1.2, depth: 1.2, height: 0.75)),
    ("conference table", Dimensions(width: 2.4, depth: 1.1, height: 0.75)),
  ]

  private func extents(_ root: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
    var lo = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
    var hi = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
    func walk(_ n: SCNNode) {
      if n.geometry != nil {
        let (a, b) = n.boundingBox
        for x in [a.x, b.x] { for y in [a.y, b.y] { for z in [a.z, b.z] {
          let p = n.convertPosition(SCNVector3(x, y, z), to: root)
          lo = SCNVector3(min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z))
          hi = SCNVector3(max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z))
        } } }
      }
      n.childNodes.forEach(walk)
    }
    walk(root)
    return (lo, hi)
  }

  private func check(_ name: String, _ size: Dimensions, file: StaticString = #filePath, line: UInt = #line) {
    guard let node = FurnitureShapes.officeNode(named: name, size: size) else {
      return XCTFail("nil node for \(name)", file: file, line: line)
    }
    let (lo, hi) = extents(node)
    XCTAssertEqual(hi.x - lo.x, size.width, accuracy: 0.02, "\(name) width", file: file, line: line)
    XCTAssertEqual(hi.y - lo.y, size.height, accuracy: 0.02, "\(name) height", file: file, line: line)
    XCTAssertEqual(hi.z - lo.z, size.depth, accuracy: 0.02, "\(name) depth", file: file, line: line)
    XCTAssertEqual(lo.y, 0, accuracy: 0.01, "\(name) base", file: file, line: line)
  }

  func testTypicalSizes() {
    for (name, size) in cases { check(name, size) }
  }

  func testScaledSizes() {
    for (name, s) in cases {
      check(name, Dimensions(width: s.width * 1.3, depth: s.depth * 1.3, height: s.height * 1.3))
    }
  }

  func testUnknownReturnsNil() {
    XCTAssertNil(FurnitureShapes.officeNode(named: "walnut dining chair",
                                            size: Dimensions(width: 0.5, depth: 0.5, height: 0.9)))
  }
}
