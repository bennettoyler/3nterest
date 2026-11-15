import Foundation
import RoomPlan
import simd

/// Pure geometry (simd only) so the maths is independent of RoomPlan types.
struct RoomGeometry {
  struct SurfaceInput { var transform: simd_float4x4; var width: Float; var height: Float }

  /// Translation that puts the lowest wall edge at y = 0 and the walls' x/z bounding box centre at the origin.
  let shift: SIMD3<Float>

  init(walls: [SurfaceInput]) {
    guard !walls.isEmpty else { shift = .zero; return }
    var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
    var minZ = Float.greatestFiniteMagnitude, maxZ = -Float.greatestFiniteMagnitude
    var floorY = Float.greatestFiniteMagnitude
    for w in walls {
      let c = SIMD3<Float>(w.transform.columns.3.x, w.transform.columns.3.y, w.transform.columns.3.z)
      let axis = SIMD3<Float>(w.transform.columns.0.x, w.transform.columns.0.y, w.transform.columns.0.z) * (w.width / 2)
      for p in [c - axis, c, c + axis] {
        minX = min(minX, p.x); maxX = max(maxX, p.x)
        minZ = min(minZ, p.z); maxZ = max(maxZ, p.z)
      }
      floorY = min(floorY, c.y - w.height / 2)
    }
    shift = SIMD3<Float>(-(minX + maxX) / 2, -floorY, -(minZ + maxZ) / 2)
  }

  /// Full rotation kept, translation shifted. Column-major 16 floats.
  func surfaceTransform(_ m: simd_float4x4) -> [Float] {
    var out = [Float]()
    out.reserveCapacity(16)
    for col in 0..<4 { for row in 0..<4 { out.append(m[col][row]) } }
    out[12] += shift.x; out[13] += shift.y; out[14] += shift.z
    return out
  }

  /// Position + yaw only; position is the BASE centre on the floor (RoomPlan gives the object's centre).
  func objectTransform(_ m: simd_float4x4, height: Float) -> [Float] {
    let c = m.columns.3
    let base = SIMD3<Float>(c.x, c.y - height / 2, c.z) + shift
    let yaw = atan2(m.columns.2.x, m.columns.2.z)
    return transformArray(position: base, yawRadians: yaw)
  }
}

enum CapturedRoomConverter {
  static func room(from captured: CapturedRoom, ownerId: String, ownerName: String, products: [Product]) -> Room {
    func input(_ s: CapturedRoom.Surface) -> RoomGeometry.SurfaceInput {
      RoomGeometry.SurfaceInput(transform: s.transform, width: s.dimensions.x, height: s.dimensions.y)
    }
    let geo = RoomGeometry(walls: captured.walls.map(input))
    func surface(_ s: CapturedRoom.Surface) -> Surface {
      Surface(transform: geo.surfaceTransform(s.transform), width: s.dimensions.x, height: s.dimensions.y)
    }
    let placements = captured.objects.map { o -> Placement in
      let category = map(o.category)
      let size = Dimensions(width: o.dimensions.x, depth: o.dimensions.z, height: o.dimensions.y)
      return Placement(id: UUID().uuidString,
                       transform: geo.objectTransform(o.transform, height: o.dimensions.y),
                       productId: ProductMatcher.match(category: category, size: size, in: products)?.id,
                       designId: nil, category: category, scannedSize: size)
    }
    return Room(id: "", ownerId: ownerId, ownerName: ownerName, title: "My room",
                thumbnailUrl: nil, published: false,
                shell: RoomShell(walls: captured.walls.map(surface),
                                 doors: captured.doors.map(surface),
                                 windows: captured.windows.map(surface)),
                placements: placements, remixedFromId: nil)
  }

  static func map(_ c: CapturedRoom.Object.Category) -> FurnitureCategory {
    switch c {
    case .chair: return .chair
    case .table: return .table
    case .sofa: return .sofa
    case .bed: return .bed
    case .storage: return .storage
    case .television: return .television
    default: return .other
    }
  }
}
