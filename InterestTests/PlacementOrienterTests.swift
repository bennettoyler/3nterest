import XCTest
@testable import Interest

final class PlacementOrienterTests: XCTestCase {
  private func place(_ id: String, _ cat: FurnitureCategory, _ x: Float, _ z: Float, yaw: Float,
                     size: Dimensions = .init(width: 0.5, depth: 0.6, height: 0.9)) -> Placement {
    Placement(id: id, transform: transformArray(position: [x, 0, z], yawRadians: yaw),
              productId: nil, designId: nil, category: cat, scannedSize: size)
  }
  private func room(_ ps: [Placement], walls: Bool = true) -> Room {
    var shell = RoomShell.rectangle(width: 6, depth: 6)
    if !walls { shell.walls = [] }
    return Room(id: "r", ownerId: "u", ownerName: "U", title: "T", thumbnailUrl: nil, published: false,
                shell: shell, placements: ps, remixedFromId: nil)
  }
  private func front(_ p: Placement) -> SIMD2<Float> { let a = yaw(of: p.transform); return [sin(a), cos(a)] }

  func testChairFacesNearbyTable() {
    // Table at origin, chair at +x 0.8; facing the table means front = (-1, 0). Start facing away (yaw +90deg).
    let out = PlacementOrienter.oriented(room([place("t", .table, 0, 0, yaw: 0), place("c", .chair, 0.8, 0, yaw: .pi / 2)], walls: false))
    let c = out.placements.first { $0.id == "c" }!
    XCTAssertGreaterThan(front(c).x * -1, 0.7)
  }

  func testChairFacesAwayFromWall() {
    let w = RoomShell.rectangle(width: 6, depth: 6).walls
    // Find the wall nearest to a point 0.4 m from the +x side.
    let out = PlacementOrienter.oriented(room([place("c", .chair, 2.6, 0, yaw: 0)]))
    let c = out.placements[0]
    XCTAssertFalse(w.isEmpty)
    XCTAssertLessThan(front(c).x, -0.7)
}

  func testStorageFacesIntoRoom() {
    let out = PlacementOrienter.oriented(room([place("s", .storage, 2.6, 0, yaw: .pi / 2)]))
    XCTAssertLessThan(front(out.placements[0]).x, -0.7)
  }

  func testTableUnchanged() {
    let t = place("t", .table, 2.8, 0, yaw: 0.3)
    XCTAssertEqual(PlacementOrienter.oriented(room([t])).placements[0].transform, t.transform)
  }

  func testOddRotationSwapsScannedSize() {
    let out = PlacementOrienter.oriented(room([place("s", .storage, 2.6, 0, yaw: 0, size: .init(width: 1.0, depth: 0.4, height: 2))]))
    let s = out.placements[0]
    XCTAssertEqual(s.scannedSize?.width ?? 0, 0.4, accuracy: 1e-5)
    XCTAssertEqual(s.scannedSize?.depth ?? 0, 1.0, accuracy: 1e-5)
  }
}
