import Foundation
import SceneKit

extension FurnitureShapes {
  /// `name` is already lowercased. Returns nil when no keyword matches.
  nonisolated static func bedroomNode(named name: String, size: Dimensions) -> SCNNode? {
    let p = BedroomParts(w: size.width, h: size.height, d: size.depth)
    if name.contains("twin bed") {
      twinBed(p)
    } else if name.contains("king bed") {
      kingBed(p)
    } else if name.contains("nightstand") {
      nightstand(p)
    } else if name.contains("dresser") {
      dresser(p)
    } else if name.contains("wardrobe") {
      wardrobe(p)
    } else {
      return nil
    }
    return p.finish()
  }

  // MARK: Shapes

  private nonisolated static func twinBed(_ p: BedroomParts) {
    let w = p.w, h = p.h, d = p.d
    let hx = w / 2, hz = d / 2
    let oak = bedHex(0xC9A46B)
    let legH = h * 0.14, frameTop = h * 0.30
    let headT = max(d * 0.04, 0.03)
    // Legs
    let lr = max(w * 0.025, 0.015)
    for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
      p.cyl(x: sx * (hx - lr - 0.01), z: sz * (hz - lr - 0.01), y0: 0, y1: legH, r: lr, oak)
    } }
    // Frame, headboard
    p.box(-hx, hx, legH, frameTop, -hz, hz, oak)
    p.box(-hx, hx, 0, h, -hz, -hz + headT, oak)
    // Mattress
    let mTop = frameTop + h * 0.16
    let mz0 = -hz + headT, inset: Float = 0.02
    p.box(-hx + inset, hx - inset, frameTop, mTop, mz0, hz, bedHex(0xF3F1EC))
    // Pillow
    let pw = w * 0.6
    p.box(-pw / 2, pw / 2, mTop, mTop + h * 0.07, mz0 + 0.05, mz0 + 0.05 + d * 0.16, bedHex(0xFFFFFF), chamfer: 0.03)
    // Folded blanket band across the foot third
    p.box(-hx + inset - 0.005, hx - inset + 0.005, frameTop, mTop + 0.02, hz - d * 0.33, hz - 0.01, bedHex(0x9DB09A), chamfer: 0.02)
  }

  private nonisolated static func kingBed(_ p: BedroomParts) {
    let w = p.w, h = p.h, d = p.d
    let hx = w / 2, hz = d / 2
    let grey = bedHex(0x8E9399), dark = bedHex(0x5E6268)
    let headT = max(d * 0.07, 0.05)
    let baseTop = h * 0.32
    // Headboard (full height) and frame/base
    p.box(-hx, hx, h * 0.04, h, -hz, -hz + headT, grey, chamfer: 0.02)
    p.box(-hx, hx, 0, baseTop, -hz + headT * 0.5, hz, dark)
    // Mattress
    let mTop = baseTop + h * 0.2
    let inset: Float = 0.03
    let mz0 = -hz + headT
    p.box(-hx + inset, hx - inset, baseTop, mTop, mz0, hz - 0.02, bedHex(0xFFFFFF), chamfer: 0.015)
    // Two pillows
    let pw = (w - 2 * inset) * 0.4
    let pz0 = mz0 + 0.06, pz1 = pz0 + d * 0.15
    for sx: Float in [-1, 1] {
      let cx = sx * w * 0.22
      p.box(cx - pw / 2, cx + pw / 2, mTop, mTop + h * 0.08, pz0, pz1, bedHex(0xFFFFFF), chamfer: 0.035)
    }
    // Duvet over lower two-thirds
    let dz0 = hz - d * 0.64
    p.box(-hx + 0.005, hx - 0.005, baseTop, mTop + 0.04, dz0, hz, bedHex(0xE9E3D8), chamfer: 0.025)
    // Contrast throw band near the foot
    p.box(-hx, hx, baseTop, mTop + 0.055, hz - d * 0.28, hz - d * 0.14, bedHex(0x39485C), chamfer: 0.02)
  }

  private nonisolated static func nightstand(_ p: BedroomParts) {
    let w = p.w, h = p.h, d = p.d
    let hx = w / 2, hz = d / 2
    let oak = bedHex(0xC9A46B), gap = bedHex(0x3B2F24), knob = bedHex(0x2B2B2B)
    let legH = h * 0.14, lr = max(min(w, d) * 0.04, 0.012)
    for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
      p.cyl(x: sx * (hx - lr - 0.005), z: sz * (hz - lr - 0.005), y0: 0, y1: legH, r: lr, oak)
    } }
    let bodyBottom = legH
    p.box(-hx, hx, bodyBottom, h, -hz, hz, oak)
    drawerFronts(p, x0: -hx + 0.02, x1: hx - 0.02, y0: bodyBottom + 0.02, y1: h - 0.03, z: hz,
                 cols: 1, rows: 2, face: oak, gap: gap, knob: knob, knobR: 0.014)
  }

  private nonisolated static func dresser(_ p: BedroomParts) {
    let w = p.w, h = p.h, d = p.d
    let hx = w / 2, hz = d / 2
    let white = bedHex(0xF2F2EF), brass = bedHex(0xB08D57), oak = bedHex(0xC9A46B), gap = bedHex(0x8A8A86)
    let legH = h * 0.08, topT = max(h * 0.035, 0.02)
    let lr = max(min(w, d) * 0.025, 0.012)
    for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
      p.cyl(x: sx * (hx - 0.05 - lr), z: sz * (hz - 0.04 - lr), y0: 0, y1: legH, r: lr, oak)
    } }
    let ov: Float = 0.015
    p.box(-hx + ov, hx - ov, legH, h - topT, -hz + ov, hz - ov, white)
    p.box(-hx, hx, h - topT, h, -hz, hz, oak)
    drawerFronts(p, x0: -hx + ov + 0.02, x1: hx - ov - 0.02, y0: legH + 0.02, y1: h - topT - 0.02, z: hz - ov,
                 cols: 2, rows: 3, face: white, gap: gap, knob: brass, knobR: 0.014)
  }

  private nonisolated static func wardrobe(_ p: BedroomParts) {
    let w = p.w, h = p.h, d = p.d
    let hx = w / 2, hz = d / 2
    let walnut = bedHex(0x6B4A2F), gap = bedHex(0x2A1C10), handle = bedHex(0x44464A)
    let plinthH = max(h * 0.04, 0.05), topT = max(h * 0.025, 0.03)
    let ov: Float = 0.015
    p.box(-hx + 0.03, hx - 0.03, 0, plinthH, -hz + 0.03, hz - 0.03, bedHex(0x4A321F))
    p.box(-hx + ov, hx - ov, plinthH, h - topT, -hz + ov, hz - ov, walnut)
    p.box(-hx, hx, h - topT, h, -hz, hz, walnut)
    // Doors with centre gap
    let zf = hz - ov
    let dy0 = plinthH + 0.03, dy1 = h - topT - 0.03
    let dx0 = -hx + ov + 0.02, dx1 = hx - ov - 0.02
    let gw: Float = 0.006
    p.box(dx0, -gw, dy0, dy1, zf - 0.005, zf + 0.012, walnut)
    p.box(gw, dx1, dy0, dy1, zf - 0.005, zf + 0.012, walnut)
    p.box(-gw, gw, dy0, dy1, zf - 0.005, zf + 0.004, gap, chamfer: 0)
    // Bar handles near the centre
    let hy0 = h * 0.42, hy1 = h * 0.62
    for sx: Float in [-1, 1] {
      p.box(sx * 0.04 - 0.008, sx * 0.04 + 0.008, hy0, hy1, zf + 0.012, zf + 0.04, handle, chamfer: 0.004)
    }
  }

  /// Grid of drawer fronts at z-plane `z` with thin dark gaps (the body behind shows through as `gap`).
  private nonisolated static func drawerFronts(_ p: BedroomParts, x0: Float, x1: Float, y0: Float, y1: Float, z: Float,
                                               cols: Int, rows: Int, face: CGColor, gap: CGColor, knob: CGColor, knobR: Float) {
    let g: Float = 0.008
    // Dark backing panel provides the gap lines.
    p.box(x0, x1, y0, y1, z - 0.004, z + 0.004, gap, chamfer: 0)
    let cw = (x1 - x0 - g * Float(cols - 1)) / Float(cols)
    let rh = (y1 - y0 - g * Float(rows - 1)) / Float(rows)
    for c in 0..<cols { for r in 0..<rows {
      let fx0 = x0 + Float(c) * (cw + g), fy0 = y0 + Float(r) * (rh + g)
      p.box(fx0, fx0 + cw, fy0, fy0 + rh, z - 0.004, z + 0.012, face, chamfer: 0.003)
      let kx = fx0 + cw / 2, ky = fy0 + rh * 0.55
      p.knob(x: kx, y: ky, z: z + 0.012, r: knobR, knob)
    } }
  }
}

// MARK: - Helpers

private func bedHex(_ rgb: Int) -> CGColor {
  CGColor(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
          blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
}

private final class BedroomParts {
  let w: Float, h: Float, d: Float
  let container = SCNNode()
  init(w: Float, h: Float, d: Float) { self.w = w; self.h = h; self.d = d }

  private func mat(_ c: CGColor) -> SCNMaterial {
    let m = SCNMaterial(); m.diffuse.contents = c; return m
  }

  func box(_ x0: Float, _ x1: Float, _ y0: Float, _ y1: Float, _ z0: Float, _ z1: Float, _ c: CGColor, chamfer: Float = 0.01) {
    let sx = max(x1 - x0, 0.001), sy = max(y1 - y0, 0.001), sz = max(z1 - z0, 0.001)
    let ch = min(chamfer, min(sx, min(sy, sz)) * 0.25)
    let g = SCNBox(width: CGFloat(sx), height: CGFloat(sy), length: CGFloat(sz), chamferRadius: CGFloat(ch))
    g.materials = [mat(c)]
    let n = SCNNode(geometry: g)
    n.position = SCNVector3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    container.addChildNode(n)
  }

  func cyl(x: Float, z: Float, y0: Float, y1: Float, r: Float, _ c: CGColor) {
    let g = SCNCylinder(radius: CGFloat(r), height: CGFloat(max(y1 - y0, 0.001)))
    g.radialSegmentCount = 16
    g.materials = [mat(c)]
    let n = SCNNode(geometry: g)
    n.position = SCNVector3(x, (y0 + y1) / 2, z)
    container.addChildNode(n)
  }

  /// Knob: short cylinder pointing along +Z.
  func knob(x: Float, y: Float, z: Float, r: Float, _ c: CGColor) {
    let g = SCNCylinder(radius: CGFloat(r), height: 0.016)
    g.radialSegmentCount = 12
    g.materials = [mat(c)]
    let n = SCNNode(geometry: g)
    n.eulerAngles.x = .pi / 2
    n.position = SCNVector3(x, y, z + 0.008)
    container.addChildNode(n)
  }

  /// Wraps the parts so the outer bounding box equals (w, h, d) with base at y = 0, centred in x/z.
  func finish() -> SCNNode {
    let (lo, hi) = container.boundingBox
    let mw = hi.x - lo.x, mh = hi.y - lo.y, md = hi.z - lo.z
    let sx = mw > 0 ? w / mw : 1, sy = mh > 0 ? h / mh : 1, sz = md > 0 ? d / md : 1
    container.scale = SCNVector3(sx, sy, sz)
    container.position = SCNVector3(-(lo.x + hi.x) / 2 * sx, -lo.y * sy, -(lo.z + hi.z) / 2 * sz)
    let outer = SCNNode()
    outer.addChildNode(container)
    return outer
  }
}
