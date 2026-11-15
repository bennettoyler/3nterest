import XCTest
import simd
@testable import Interest

final class RoomBoundsTests: XCTestCase {
    func testDragPastWallIsClamped() {
        let b = RoomBounds(shell: .rectangle(width: 4, depth: 5))       // walls at x=±2, z=±2.5
        let p = b.clamp([3.5, 0, 0], halfExtent: [0.5, 0.5])
        XCTAssertEqual(p.x, 1.5, accuracy: 1e-4); XCTAssertEqual(p.y, 0)
    }
}
