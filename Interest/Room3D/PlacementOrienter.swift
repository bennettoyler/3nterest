import Foundation
import simd

/// Pure: picks a sensible facing for each placement (RoomPlan yaw is ambiguous by multiples of 90 degrees).
enum PlacementOrienter {
  static func oriented(_ room: Room) -> Room {
    var r = room
    let walls = room.shell.walls.filter { $0.transform.count == 16 }
    let tables = room.placements.filter { $0.category == .table && $0.transform.count == 16 }
      .map { SIMD2<Float>($0.transform[12], $0.transform[14]) }

    r.placements = room.placements.map { p in
      guard p.transform.count == 16 else { return p }
      let pos = SIMD2<Float>(p.transform[12], p.transform[14])
      var target: SIMD2<Float>?   // desired front direction (not necessarily normalised)

      func awayFromWall() -> SIMD2<Float>? {
        var best: (Float, SIMD2<Float>)?
        for w in walls {
          let t = w.transform
          let c = SIMD2<Float>(t[12], t[14])
          let a = SIMD2<Float>(t[0], t[2]) * (w.width / 2)
          let ab = 2 * a
          let len2 = simd_dot(ab, ab)
          let u = len2 > 1e-9 ? max(0, min(1, simd_dot(pos - (c - a), ab) / len2)) : 0.5
          let closest = (c - a) + ab * u
          let v = pos - closest
          let d = simd_length(v)
          if best == nil || d < best!.0 { best = (d, v) }
        }
        if let best, best.0 <= 1.0, best.0 > 1e-4 { return best.1 }
        return nil
      }

      switch p.category {
      case .chair:
        let near = tables.map { ($0 - pos, simd_length($0 - pos)) }.filter { $0.1 <= 1.6 }.min { $0.1 < $1.1 }
        if let near, near.1 > 1e-4 { target = near.0 } else { target = awayFromWall() }
      case .sofa, .storage, .television, .bed:
        target = awayFromWall()
      default: break
      }
      guard let target, simd_length(target) > 1e-6 else { return p }
      let dir = simd_normalize(target)
      let base = yaw(of: p.transform)
      var bestK = 0, bestDot = -Float.greatestFiniteMagnitude
      for k in 0..<4 {
        let a = base + Float(k) * .pi / 2
        let dot = sin(a) * dir.x + cos(a) * dir.y
        if dot > bestDot + 1e-4 { bestDot = dot; bestK = k }
      }
      guard bestK != 0 else { return p }
      var q = p
      q.transform = transformArray(position: SIMD3<Float>(p.transform[12], p.transform[13], p.transform[14]),
                                   yawRadians: base + Float(bestK) * .pi / 2)
      if bestK % 2 == 1, let s = p.scannedSize {
        q.scannedSize = Dimensions(width: s.depth, depth: s.width, height: s.height)
      }
      return q
    }
    return r
  }
}
