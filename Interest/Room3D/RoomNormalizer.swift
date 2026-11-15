import Foundation
import simd

/// Pure maths (no RoomPlan types): aligns a scanned room with the world axes and centres it.
enum RoomNormalizer {
  /// Rotates the whole room about +Y so the longest wall has yaw 0 (parallel to world X), snaps near-axis
  /// yaws to exact multiples of 90 degrees, then translates x/z so the wall end points' bounding box is
  /// centred on the origin. Rooms without (valid) walls are returned unchanged.
  static func normalized(_ room: Room) -> Room {
    let walls = room.shell.walls.filter { $0.transform.count == 16 }
    guard let longest = walls.max(by: { $0.width < $1.width }) else { return room }

    let angle = -yaw(of: longest.transform)
    let c = cos(angle), s = sin(angle)

    func rotate(_ t: [Float]) -> [Float] {
      guard t.count == 16 else { return t }
      var out = t
      for col in 0..<4 {
        let x = t[col * 4], z = t[col * 4 + 2]
        out[col * 4] = x * c + z * s
        out[col * 4 + 2] = -x * s + z * c
      }
      return snap(out)
    }

    var r = room
    r.shell.walls = room.shell.walls.map { Surface(transform: rotate($0.transform), width: $0.width, height: $0.height) }
    r.shell.doors = room.shell.doors.map { Surface(transform: rotate($0.transform), width: $0.width, height: $0.height) }
    r.shell.windows = room.shell.windows.map { Surface(transform: rotate($0.transform), width: $0.width, height: $0.height) }
    r.placements = room.placements.map { p in var q = p; q.transform = rotate(p.transform); return q }

    var lo = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
    var hi = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
    for w in r.shell.walls where w.transform.count == 16 {
      let t = w.transform
      let centre = SIMD2<Float>(t[12], t[14])
      let axis = SIMD2<Float>(t[0], t[2]) * (w.width / 2)
      for p in [centre - axis, centre + axis] { lo = simd_min(lo, p); hi = simd_max(hi, p) }
    }
    let dx = -(lo.x + hi.x) / 2, dz = -(lo.y + hi.y) / 2

    func shift(_ t: [Float]) -> [Float] {
      guard t.count == 16 else { return t }
      var out = t
      out[12] += dx; out[14] += dz
      return out
    }
    r.shell.walls = r.shell.walls.map { Surface(transform: shift($0.transform), width: $0.width, height: $0.height) }
    r.shell.doors = r.shell.doors.map { Surface(transform: shift($0.transform), width: $0.width, height: $0.height) }
    r.shell.windows = r.shell.windows.map { Surface(transform: shift($0.transform), width: $0.width, height: $0.height) }
    r.placements = r.placements.map { p in var q = p; q.transform = shift(p.transform); return q }
    return r
  }

  /// If the yaw is within 9 degrees of a multiple of 90, rebuild the rotation part exactly (position kept).
  private static func snap(_ t: [Float]) -> [Float] {
    let y = yaw(of: t)
    let quarter = Float.pi / 2
    let nearest = (y / quarter).rounded() * quarter
    guard abs(y - nearest) <= 9 * .pi / 180 else { return t }
    var out = transformArray(position: SIMD3<Float>(t[12], t[13], t[14]), yawRadians: nearest)
    // Exact values for the multiples of 90 (cos/sin of pi/2 are not exactly 0).
    let k = Int(nearest / quarter) & 3   // 0,1,2,3 (mod 4)
    let cs: [(Float, Float)] = [(1, 0), (0, 1), (-1, 0), (0, -1)]
    let (cc, ss) = cs[k]
    out[0] = cc; out[2] = -ss; out[8] = ss; out[10] = cc
    return out
  }
}
