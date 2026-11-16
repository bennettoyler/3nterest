import XCTest
import SceneKit
@testable import Interest

final class RoomDecorTests: XCTestCase {
  private func wall(_ x: Float, _ z: Float, yaw: Float, width: Float) -> Surface {
    Surface(transform: transformArray(position: SIMD3(x, 1.21, z), yawRadians: yaw), width: width, height: 2.42)
  }

  private func meetingShell() -> RoomShell {
    let walls = [
      wall(0, -2.855, yaw: 0, width: 7.60), wall(0, 2.855, yaw: .pi, width: 7.60),
      wall(-3.80, 0, yaw: .pi / 2, width: 5.71), wall(3.80, 0, yaw: -.pi / 2, width: 5.71)]
    let door = Surface(transform: transformArray(position: SIMD3(-2.53, 1.10, -2.855), yawRadians: 0), width: 0.81, height: 2.19)
    func win(_ x: Float, _ z: Float, _ yw: Float) -> Surface {
      Surface(transform: transformArray(position: SIMD3(x, 1.6, z), yawRadians: yw), width: 1.3, height: 1.2)
    }
    return RoomShell(walls: walls, doors: [door],
                     windows: [win(1.95, 2.855, .pi), win(0.20, 2.855, .pi), win(-3.0, 2.855, .pi), win(3.80, -0.34, -.pi / 2)])
  }

  private func smallShell() -> RoomShell {
    RoomShell(walls: [wall(0, -2, yaw: 0, width: 4), wall(0, 2, yaw: .pi, width: 4),
                      wall(-2.5, 0, yaw: .pi / 2, width: 5), wall(2.5, 0, yaw: -.pi / 2, width: 5)],
              doors: [], windows: [])
  }

  func testMatches() {
    XCTAssertTrue(RoomDecor.matches(meetingShell()))
    XCTAssertFalse(RoomDecor.matches(smallShell()))
  }

  private func room(_ shell: RoomShell, ids: [String]) -> Room {
    let pls = ids.map { Placement(id: $0, transform: transformArray(position: [0, 0, 0], yawRadians: 0),
                                  productId: nil, designId: nil, category: .table, scannedSize: .init(width: 1, depth: 1, height: 1)) }
    return Room(id: "r", ownerId: "u", ownerName: "U", title: "T", thumbnailUrl: nil, published: false,
                shell: shell, placements: pls, remixedFromId: nil)
  }

  func testAppliesOnlyToBundledSample() {
    XCTAssertTrue(RoomDecor.applies(to: StubBackend.sampleRoom()))
    XCTAssertFalse(RoomDecor.applies(to: room(meetingShell(), ids: [UUID().uuidString])))
    XCTAssertFalse(RoomDecor.applies(to: room(smallShell(), ids: ["sample-1"])))
  }

  func testNodes() {
    let nodes = RoomDecor.nodes(for: meetingShell())
    XCTAssertFalse(nodes.isEmpty)
    XCTAssertTrue(nodes.allSatisfy { ($0.name ?? "").hasPrefix("decor-") })
    let names = Set(nodes.compactMap { $0.name })
    for n in ["decor-rug", "decor-column", "decor-whiteboard"] { XCTAssertTrue(names.contains(n), n) }
    XCTAssertTrue(RoomDecor.nodes(for: smallShell()).isEmpty)
  }

  func testColors() {
    let shell = meetingShell()
    XCTAssertNotNil(RoomDecor.floorColor(for: shell))
    XCTAssertNil(RoomDecor.floorColor(for: smallShell()))
    let flags = shell.walls.map { RoomDecor.wallColor(for: $0, in: shell) != nil }
    XCTAssertEqual(flags, [false, false, true, false])
  }

  func testNodesInsideRoom() {
    for node in RoomDecor.nodes(for: meetingShell()) {
      let (lo, hi) = node.boundingBox
      for x in [lo.x, hi.x] { for y in [lo.y, hi.y] { for z in [lo.z, hi.z] {
        let p = node.convertPosition(SCNVector3(x, y, z), to: nil)
        let n = node.name ?? ""
        XCTAssertTrue(abs(p.x) <= 3.85 && abs(p.z) <= 2.905 && p.y >= -0.01 && p.y <= 2.47, "\(n) out of room: \(p)")
      } } }
    }
  }

  func testWallTelevisionSize() {
    let tv = FurnitureShapes.wallTelevision(size: Dimensions(width: 1.2, depth: 0.05, height: 0.7))
    let (lo, hi) = tv.boundingBox
    XCTAssertEqual(hi.x - lo.x, 1.2, accuracy: 0.02)
    XCTAssertEqual(hi.y - lo.y, 0.7, accuracy: 0.02)
    XCTAssertEqual(lo.y, 0, accuracy: 0.02)
  }
}
