import Foundation
import SceneKit
import simd

extension Array where Element == Float {
  /// 16 floats, column-major, to SCNMatrix4.
  var scnMatrix: SCNMatrix4 {
    guard count == 16 else { return SCNMatrix4Identity }
    let m = simd_float4x4(columns: (
      SIMD4<Float>(self[0], self[1], self[2], self[3]),
      SIMD4<Float>(self[4], self[5], self[6], self[7]),
      SIMD4<Float>(self[8], self[9], self[10], self[11]),
      SIMD4<Float>(self[12], self[13], self[14], self[15])))
    return SCNMatrix4(m)
  }
}

/// Yaw about +Y: columns [c,0,-s,0], [0,1,0,0], [s,0,c,0], [x,y,z,1].
func transformArray(position: SIMD3<Float>, yawRadians: Float) -> [Float] {
  let c = cos(yawRadians), s = sin(yawRadians)
  return [c, 0, -s, 0,
          0, 1, 0, 0,
          s, 0, c, 0,
          position.x, position.y, position.z, 1]
}

func yaw(of transform: [Float]) -> Float {
  guard transform.count == 16 else { return 0 }
  return atan2(transform[8], transform[10])
}
