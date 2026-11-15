import XCTest
import simd
@testable import Interest

final class RoomNormalizerTests: XCTestCase {
  private func rotated(_ t: [Float], by a: Float, offset: SIMD3<Float>) -> [Float] {
    let c = cos(a), s = sin(a)
    var o = t
    for col in 0..<4 { let x = t[col * 4], z = t[col * 4 + 2]; o[col * 4] = x * c + z * s; o[col * 4 + 2] = -x * s + z * c }
    o[12] += offset.x; o[13] += offset.y; o[14] += offset.z
    return o
  }

  func testRotatedOffsetRoomIsAlignedAndCentred() {
    let a: Float = 22 * .pi / 180
    let off = SIMD3<Float>(1, 0, 2)
    let base = RoomShell.rectangle(width: 4, depth: 5)
    func tf(_ s: Surface) -> Surface { Surface(transform: rotated(s.transform, by: a, offset: off), width: s.width, height: s.height) }
    let shell = RoomShell(walls: base.walls.map(tf), doors: [], windows: [])
    let placeTransform = rotated(transformArray(position: [0.7, 0, -0.4], yawRadians: 0.3), by: a, offset: off)
    let pl = Placement(id: "p", transform: placeTransform, productId: nil, designId: nil, category: .table, scannedSize: nil)
    let room = Room(id: "r", ownerId: "u", ownerName: "U", title: "T", thumbnailUrl: nil, published: false,
                    shell: shell, placements: [pl], remixedFromId: nil)

    let n = RoomNormalizer.normalized(room)
    for w in n.shell.walls {
      let deg = yaw(of: w.transform) * 180 / .pi
      let ok = [0, 90, -90, 180, -180].contains { abs(deg - Float($0)) < 1e-3 }
      XCTAssertTrue(ok, "yaw \(deg)")
    }
    var lo = SIMD2<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
    for w in n.shell.walls {
      let t = w.transform
      let c = SIMD2<Float>(t[12], t[14]), ax = SIMD2<Float>(t[0], t[2]) * (w.width / 2)
      for p in [c - ax, c + ax] { lo = simd_min(lo, p); hi = simd_max(hi, p) }
    }
    XCTAssertEqual((lo.x + hi.x) / 2, 0, accuracy: 1e-3)
    XCTAssertEqual((lo.y + hi.y) / 2, 0, accuracy: 1e-3)
    XCTAssertEqual(hi.x - lo.x, 5, accuracy: 1e-3)   // longest wall (5 m) now along X
    XCTAssertEqual(hi.y - lo.y, 4, accuracy: 1e-3)

    // Placement keeps its position relative to the walls: distances to each wall centre are unchanged.
    for (w0, w1) in zip(room.shell.walls, n.shell.walls) {
      let d0 = simd_distance(SIMD2<Float>(placeTransform[12], placeTransform[14]), SIMD2<Float>(w0.transform[12], w0.transform[14]))
      let t = n.placements[0].transform
      let d1 = simd_distance(SIMD2<Float>(t[12], t[14]), SIMD2<Float>(w1.transform[12], w1.transform[14]))
      XCTAssertEqual(d0, d1, accuracy: 1e-3)
    }
    XCTAssertEqual(n.placements[0].transform[13], 0, accuracy: 1e-6)
  }

  func testRoomWithoutWallsIsUnchanged() {
    let pl = Placement(id: "p", transform: transformArray(position: [1, 0, 2], yawRadians: 0.4),
                       productId: nil, designId: nil, category: .table, scannedSize: nil)
    let room = Room(id: "r", ownerId: "u", ownerName: "U", title: "T", thumbnailUrl: nil, published: false,
                    shell: RoomShell(walls: [], doors: [], windows: []), placements: [pl], remixedFromId: nil)
    XCTAssertEqual(RoomNormalizer.normalized(room), room)
  }
}
