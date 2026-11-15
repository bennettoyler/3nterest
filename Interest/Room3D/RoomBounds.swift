import Foundation
import simd

/// Axis-aligned box (on the floor plane) over every wall end point.
struct RoomBounds {
    private let minX: Float, maxX: Float, minZ: Float, maxZ: Float
    private let hasWalls: Bool

    init(shell: RoomShell) {
        var lo = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
        var any = false
        for wall in shell.walls where wall.transform.count >= 16 {
            let t = wall.transform
            let half = wall.width / 2
            // Local X axis of the wall lies in the first matrix column.
            let centre = SIMD2<Float>(t[12], t[14])
            let axis = SIMD2<Float>(t[0], t[2])
            for end in [centre + axis * half, centre - axis * half] {
                lo = simd_min(lo, end)
                hi = simd_max(hi, end)
                any = true
            }
        }
        hasWalls = any
        minX = lo.x; minZ = lo.y; maxX = hi.x; maxZ = hi.y
    }

    /// Keeps an object with the given half extent (x, z) inside the walls; result is on the floor (y = 0).
    func clamp(_ p: SIMD3<Float>, halfExtent: SIMD2<Float>) -> SIMD3<Float> {
        guard hasWalls else { return SIMD3<Float>(p.x, 0, p.z) }
        return SIMD3<Float>(Self.clamp1(p.x, minX + halfExtent.x, maxX - halfExtent.x),
                            0,
                            Self.clamp1(p.z, minZ + halfExtent.y, maxZ - halfExtent.y))
    }

    /// If the object is larger than the room on this axis, centre it.
    private static func clamp1(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
        lo > hi ? (lo + hi) / 2 : min(max(v, lo), hi)
    }
}
