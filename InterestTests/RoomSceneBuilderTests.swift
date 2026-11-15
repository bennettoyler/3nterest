import XCTest
import SceneKit
@testable import Interest

final class RoomSceneBuilderTests: XCTestCase {
  func testUnmatchedPlacementUsesScannedSize() {
    let pl = Placement(id: "pl1", transform: transformArray(position: [0, 0, 0], yawRadians: 0),
                       productId: nil, designId: nil, category: .table,
                       scannedSize: .init(width: 2, depth: 0.5, height: 1.6))
    let room = Room(id: "r", ownerId: "u", ownerName: "U", title: "T", thumbnailUrl: nil, published: false,
                    shell: .rectangle(width: 4, depth: 5), placements: [pl], remixedFromId: nil)
    let scene = RoomSceneBuilder.scene(for: room, products: [], designs: [])
    let node = scene.rootNode.childNode(withName: "pl1", recursively: false)
    XCTAssertNotNil(node)
    let (lo, hi) = node!.boundingBox
    XCTAssertEqual(hi.x - lo.x, 2, accuracy: 0.01)
    XCTAssertEqual(hi.y - lo.y, 1.6, accuracy: 0.01)
    XCTAssertEqual(hi.z - lo.z, 0.5, accuracy: 0.01)
  }

  func testFloorCoversWallEndPointsOfRotatedRoom() throws {
    let a: Float = 30 * .pi / 180
    let c = cos(a), sn = sin(a)
    func rot(_ t: [Float]) -> [Float] {
      var o = t
      for col in 0..<4 { let x = t[col * 4], z = t[col * 4 + 2]; o[col * 4] = x * c + z * sn; o[col * 4 + 2] = -x * sn + z * c }
      return o
    }
    var shell = RoomShell.rectangle(width: 4, depth: 5)
    shell.walls = shell.walls.map { Surface(transform: rot($0.transform), width: $0.width, height: $0.height) }
    let room = Room(id: "r", ownerId: "u", ownerName: "U", title: "T", thumbnailUrl: nil, published: false,
                    shell: shell, placements: [], remixedFromId: nil)
    let ends = RoomSceneBuilder.wallEndPoints(room)
    XCTAssertEqual(ends.count, 8)
    let expW = ends.map(\.x).max()! - ends.map(\.x).min()!
    let expD = ends.map(\.y).max()! - ends.map(\.y).min()!
    // Centres extent would be smaller; make sure the test distinguishes them.
    let centresW = shell.walls.map { $0.transform[12] }.max()! - shell.walls.map { $0.transform[12] }.min()!
    XCTAssertGreaterThan(expW - centresW, 0.5)

    let scene = RoomSceneBuilder.scene(for: room, products: [], designs: [])
    let floor = try XCTUnwrap(scene.rootNode.childNode(withName: "floor", recursively: false))
    let (lo, hi) = floor.boundingBox
    XCTAssertEqual(Float(hi.x - lo.x), expW, accuracy: 1e-3)
    XCTAssertEqual(Float(hi.z - lo.z), expD, accuracy: 1e-3)
    XCTAssertEqual(Float(hi.y - lo.y), 0, accuracy: 1e-6)
  }
}
