import XCTest
import SceneKit
@testable import Interest

final class DesignNodeBuilderTests: XCTestCase {
  func testDeskBuildsOneChildPerPartInMetres() {
    let d = Design.fixture(parts: [
      .init(name: "top", shape: .box, sizeCm: [120, 3, 60], positionCm: [0, 73.5, 0], rotationDeg: [0,0,0], material: "walnut", colorHex: "#6B4226"),
      .init(name: "leg", shape: .cylinder, sizeCm: [5, 72, 5], positionCm: [-55, 36, -25], rotationDeg: [0,0,0], material: "steel", colorHex: "#222222")])
    let n = DesignNodeBuilder.node(for: d)
    XCTAssertEqual(n.childNodes.count, 2)
    let (lo, hi) = n.boundingBox
    XCTAssertEqual(hi.x - lo.x, 1.2, accuracy: 0.01); XCTAssertEqual(lo.y, 0, accuracy: 0.01)
  }
}
