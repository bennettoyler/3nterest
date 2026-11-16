import Foundation
import SceneKit

/// Procedural kitchen and bathroom fixtures. Back = local -Z, front = +Z, base at y = 0.
fileprivate final class KBParts {
  let w: Float, h: Float, d: Float
  let inner = SCNNode()
  init(_ s: Dimensions) { w = s.width; h = s.height; d = s.depth }

  static func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
  }

  private func mat(_ hex: UInt32) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = KBParts.color(hex)
    return m
  }

  /// Box from extents in container space (x/z centred, y from 0).
  func box(_ x0: Float, _ x1: Float, _ y0: Float, _ y1: Float, _ z0: Float, _ z1: Float, _ hex: UInt32) {
    let sx = max(x1 - x0, 0.002), sy = max(y1 - y0, 0.002), sz = max(z1 - z0, 0.002)
    let g = SCNBox(width: CGFloat(sx), height: CGFloat(sy), length: CGFloat(sz),
                   chamferRadius: CGFloat(min(0.008, min(sx, min(sy, sz)) * 0.25)))
    g.materials = [mat(hex)]
    let n = SCNNode(geometry: g)
    n.position = SCNVector3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    inner.addChildNode(n)
  }

  /// Vertical cylinder (axis Y); `sx`/`sz` scale the footprint for oval shapes.
  func cyl(x: Float, z: Float, y0: Float, y1: Float, r: Float, sx: Float = 1, sz: Float = 1, _ hex: UInt32) {
    let g = SCNCylinder(radius: CGFloat(r), height: CGFloat(max(y1 - y0, 0.002)))
    g.radialSegmentCount = 24
    g.materials = [mat(hex)]
    let n = SCNNode(geometry: g)
    n.position = SCNVector3(x, (y0 + y1) / 2, z)
    n.scale = SCNVector3(sx, 1, sz)
    inner.addChildNode(n)
  }

  /// Flat disc facing +Z centred at (x, y), thickness from z0 to z1.
  func disc(x: Float, y: Float, z0: Float, z1: Float, r: Float, _ hex: UInt32) {
    let g = SCNCylinder(radius: CGFloat(r), height: CGFloat(max(z1 - z0, 0.002)))
    g.radialSegmentCount = 24
    g.materials = [mat(hex)]
    let n = SCNNode(geometry: g)
    n.eulerAngles.x = .pi / 2
    n.position = SCNVector3(x, y, (z0 + z1) / 2)
    inner.addChildNode(n)
  }

  /// Wrap in an outer node whose bounding box equals `size`, base at y = 0, centred in x/z.
  func finish(_ size: Dimensions) -> SCNNode {
    let outer = SCNNode()
    outer.addChildNode(inner)
    var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    func visit(_ n: SCNNode) {
      if n.geometry != nil {
        let (a, b) = n.boundingBox
        for i in 0..<8 {
          let p = SCNVector3(i & 1 == 0 ? a.x : b.x, i & 2 == 0 ? a.y : b.y, i & 4 == 0 ? a.z : b.z)
          let q = n.convertPosition(p, to: inner)
          lo = simd_min(lo, SIMD3(Float(q.x), Float(q.y), Float(q.z)))
          hi = simd_max(hi, SIMD3(Float(q.x), Float(q.y), Float(q.z)))
        }
      }
      n.childNodes.forEach(visit)
    }
    visit(inner)
    let ext = hi - lo
    let sx = ext.x > 1e-5 ? size.width / ext.x : 1
    let sy = ext.y > 1e-5 ? size.height / ext.y : 1
    let sz = ext.z > 1e-5 ? size.depth / ext.z : 1
    inner.scale = SCNVector3(sx, sy, sz)
    inner.position = SCNVector3(-(lo.x + hi.x) / 2 * sx, -lo.y * sy, -(lo.z + hi.z) / 2 * sz)
    return outer
  }
}

extension FurnitureShapes {
  /// `name` is already lowercased. Returns nil when no keyword matches.
  nonisolated static func kitchenBathNode(named name: String, size: Dimensions) -> SCNNode? {
    let p = KBParts(size)
    if name.contains("refrigerator") { fridge(p) }
    else if name.contains("stove") { stove(p) }
    else if name.contains("sink") { sink(p) }
    else if name.contains("dishwasher") { dishwasher(p) }
    else if name.contains("washer") { washer(p) }
    else if name.contains("toilet") { toilet(p) }
    else if name.contains("bathtub") { bathtub(p) }
    else { return nil }
    return p.finish(size)
  }

  private nonisolated static func fridge(_ p: KBParts) {
    let hx = p.w / 2, hz = p.d / 2, h = p.h
    let kick = min(0.08, h * 0.05)
    p.box(-hx, hx, 0, kick, -hz + 0.03, hz - 0.03, 0x3A3C40)
    p.box(-hx, hx, kick, h, -hz, hz, 0xC4C8CC)
    let split = h * 0.35
    p.box(-hx + 0.01, hx - 0.01, split - 0.006, split + 0.006, hz, hz + 0.004, 0x2A2C30)
    let bx = hx * 0.78
    p.box(bx - 0.012, bx + 0.012, split + 0.05, split + h * 0.4, hz, hz + 0.03, 0x5A5D62)
    p.box(bx - 0.012, bx + 0.012, split - h * 0.2, split - 0.04, hz, hz + 0.03, 0x5A5D62)
  }

  private nonisolated static func stove(_ p: KBParts) {
    let hx = p.w / 2, hz = p.d / 2, h = p.h
    let topY = h * 0.92
    let backT = min(0.06, p.d * 0.1)
    p.box(-hx, hx, 0, topY, -hz, hz, 0xD9DCDF)
    p.box(-hx * 0.8, hx * 0.8, h * 0.12, h * 0.55, hz, hz + 0.004, 0x2A2C30)
    p.box(-hx * 0.85, hx * 0.85, h * 0.6, h * 0.6 + 0.025, hz + 0.005, hz + 0.04, 0x8A8E93)
    p.box(-hx, hx, topY, h * 0.94, -hz, hz, 0x1C1D20)
    let r = min(p.w, p.d) * 0.17
    for sx: Float in [-1, 1] {
      for sz: Float in [-1, 1] {
        p.cyl(x: sx * hx * 0.45, z: sz * hz * 0.4 - hz * 0.05, y0: h * 0.94, y1: h * 0.94 + 0.006, r: r, 0x3A3C40)
      }
    }
    p.box(-hx, hx, h * 0.94, h, -hz, -hz + backT, 0xD9DCDF)
    for i in 0..<4 {
      let kx = (Float(i) - 1.5) * hx * 0.45
      p.cyl(x: kx, z: -hz + backT + 0.012, y0: h * 0.95, y1: h * 0.985, r: 0.012, 0x2A2C30)
    }
  }

  private nonisolated static func sink(_ p: KBParts) {
    let hx = p.w / 2, hz = p.d / 2, h = p.h
    let ctY = h * 0.94
    p.box(-hx, hx, 0, ctY, -hz, hz, 0xF2F2EF)
    p.box(-0.005, 0.005, h * 0.05, ctY - 0.04, hz, hz + 0.003, 0xBBBBB6)
    for s: Float in [-1, 1] {
      p.box(s * hx * 0.45 - 0.01, s * hx * 0.45 + 0.01, h * 0.6, h * 0.8, hz, hz + 0.025, 0x8A8E93)
    }
    p.box(-hx, hx, ctY, h * 0.97, -hz, hz, 0xB9BDC2)
    p.box(-hx * 0.55, hx * 0.55, h * 0.968, h * 0.975, -hz * 0.55, hz * 0.55, 0x7C8086)
    p.cyl(x: 0, z: -hz * 0.8, y0: h * 0.97, y1: h, r: 0.012, 0xD8DADD)
    p.box(-0.01, 0.01, h * 0.99, h, -hz * 0.8, -hz * 0.8 + hz * 0.45, 0xD8DADD)
  }

  private nonisolated static func dishwasher(_ p: KBParts) {
    let hx = p.w / 2, hz = p.d / 2, h = p.h
    let kick = min(0.08, h * 0.08)
    p.box(-hx, hx, 0, kick, -hz + 0.03, hz - 0.03, 0x3A3C40)
    p.box(-hx, hx, kick, h, -hz, hz, 0xC4C8CC)
    p.box(-hx + 0.01, hx - 0.01, h * 0.9, h * 0.97, hz, hz + 0.004, 0x2A2C30)
    p.box(-hx * 0.8, hx * 0.8, h * 0.8, h * 0.8 + 0.022, hz, hz + 0.035, 0x5A5D62)
  }

  private nonisolated static func washer(_ p: KBParts) {
    let hx = p.w / 2, hz = p.d / 2, h = p.h
    p.box(-hx, hx, 0, h, -hz, hz, 0xF4F4F2)
    p.box(-hx + 0.01, hx - 0.01, h * 0.84, h * 0.97, hz, hz + 0.004, 0xDADBD8)
    p.disc(x: hx * 0.5, y: h * 0.905, z0: hz, z1: hz + 0.015, r: min(h * 0.05, 0.03), 0x5A5D62)
    let r = min(p.w * 0.36, h * 0.34)
    let cy = h * 0.42
    p.disc(x: 0, y: cy, z0: hz, z1: hz + 0.012, r: r * 1.15, 0xD0D2D0)
    p.disc(x: 0, y: cy, z0: hz, z1: hz + 0.02, r: r, 0x2A2C30)
  }

  private nonisolated static func toilet(_ p: KBParts) {
    let hx = p.w / 2, hz = p.d / 2, h = p.h
    let tankD = p.d * 0.28
    p.box(-hx, hx, h * 0.45, h, -hz, -hz + tankD, 0xF6F6F4)
    p.box(-hx * 0.9, hx * 0.9, h, h * 1.0 + 0.001, -hz + 0.01, -hz + tankD - 0.01, 0xE8E8E6)
    let bowlLen = p.d - tankD
    let bowlZ = -hz + tankD + bowlLen / 2
    p.cyl(x: 0, z: bowlZ, y0: h * 0.18, y1: h * 0.5, r: 0.5, sx: p.w * 0.46 / 0.5, sz: bowlLen / 2 / 0.5, 0xF6F6F4)
    p.cyl(x: 0, z: bowlZ, y0: h * 0.5, y1: h * 0.5 + 0.015, r: 0.5, sx: p.w * 0.46 / 0.5, sz: bowlLen / 2 / 0.5 * 0.96, 0xD4D6D8)
    p.cyl(x: 0, z: -hz + tankD + bowlLen * 0.35, y0: 0, y1: h * 0.2, r: 0.5, sx: p.w * 0.26 / 0.5, sz: bowlLen * 0.3 / 0.5, 0xEDEDEB)
    p.box(-hx * 0.4, hx * 0.4, h * 0.45, h * 0.45 + 0.01, -hz, -hz + tankD, 0xF6F6F4)
  }

  private nonisolated static func bathtub(_ p: KBParts) {
    let hx = p.w / 2, hz = p.d / 2, h = p.h
    let wall = min(0.07, min(p.w, p.d) * 0.12)
    p.box(-hx, hx, 0, h, -hz, hz, 0xF6F6F4)
    p.box(-hx + wall, hx - wall, h * 0.2, h + 0.004, -hz + wall, hz - wall, 0xDCE6EC)
    let fx = -hx + wall * 0.5
    p.cyl(x: fx, z: 0, y0: h, y1: h + min(0.12, h * 0.2), r: 0.012, 0xD8DADD)
    p.box(fx - 0.01, fx + 0.07, h + min(0.12, h * 0.2) - 0.02, h + min(0.12, h * 0.2), -0.01, 0.01, 0xD8DADD)
  }
}
