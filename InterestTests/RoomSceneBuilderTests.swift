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
}
