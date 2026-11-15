import Foundation
import SceneKit

/// Simple recognisable furniture built from a few primitives. Back = local -Z, front = +Z.
/// Every shape spans exactly the product footprint with its base at y = 0 (centred in x/z), so the
/// container's bounding box equals `Dimensions`.
enum FurnitureShapes {
  private struct Builder {
    let w: Float, h: Float, d: Float
    let container = SCNNode()

    /// Box from (x0..x1, y0..y1, z0..z1) in container space (x/z centred, y from 0).
    func box(_ x0: Float, _ x1: Float, _ y0: Float, _ y1: Float, _ z0: Float, _ z1: Float, _ color: CGColor) {
      let sx = max(x1 - x0, 0.001), sy = max(y1 - y0, 0.001), sz = max(z1 - z0, 0.001)
      let chamfer = min(0.012, min(sx, min(sy, sz)) * 0.25)
      let g = SCNBox(width: CGFloat(sx), height: CGFloat(sy), length: CGFloat(sz), chamferRadius: CGFloat(chamfer))
      g.materials = [Self.material(color)]
      let n = SCNNode(geometry: g)
      n.position = SCNVector3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
      container.addChildNode(n)
    }

    func cylinder(x: Float, z: Float, y0: Float, y1: Float, radius: Float, _ color: CGColor) {
      let g = SCNCylinder(radius: CGFloat(radius), height: CGFloat(max(y1 - y0, 0.001)))
      g.radialSegmentCount = 16
      g.materials = [Self.material(color)]
      let n = SCNNode(geometry: g)
      n.position = SCNVector3(x, (y0 + y1) / 2, z)
      container.addChildNode(n)
    }

    static func material(_ c: CGColor) -> SCNMaterial {
      let m = SCNMaterial()
      m.diffuse.contents = c
      return m
    }
  }

  private static func cl(_ v: Float, _ lo: Float, _ hi: Float) -> Float { min(max(v, lo), hi) }

  private static func tone(_ c: CGColor, _ f: CGFloat) -> CGColor {
    let comps = c.components ?? [0.5, 0.5, 0.5, 1]
    func ch(_ i: Int) -> CGFloat { i < comps.count - 1 ? comps[i] : comps[0] }
    func adj(_ v: CGFloat) -> CGFloat { f >= 1 ? v + (1 - v) * (f - 1) : v * f }
    return CGColor(red: adj(ch(0)), green: adj(ch(1)), blue: adj(ch(2)), alpha: 1)
  }
  private static func darker(_ c: CGColor, _ amount: CGFloat = 0.78) -> CGColor { tone(c, amount) }
  private static func lighter(_ c: CGColor, _ amount: CGFloat = 1.35) -> CGColor { tone(c, amount) }

  /// Returns nil for `.other` (caller keeps the plain chamfered box).
  nonisolated static func node(category: FurnitureCategory, size: Dimensions, base: CGColor) -> SCNNode? {
    let b = Builder(w: size.width, h: size.height, d: size.depth)
    switch category {
    case .sofa: sofa(b, base)
    case .chair: chair(b, base)
    case .table: table(b, base)
    case .bed: bed(b, base)
    case .storage: storage(b, base)
    case .television: television(b, base)
    case .other: return nil
    }
    return b.container
  }

  private nonisolated static func sofa(_ b: Builder, _ c: CGColor) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let arm = cl(w * 0.1, 0.02, w * 0.2)
    let backT = cl(d * 0.25, 0.03, d * 0.4)
    let seatH = h * 0.45
    let armH = h * 0.68
    let cushH = cl(h * 0.14, 0.01, h * 0.2)
    let dark = darker(c, 0.88), light = lighter(c, 1.2)
    b.box(-hx + arm, hx - arm, 0, seatH, -hz, hz, c)                    // seat base
    b.box(-hx, -hx + arm, 0, armH, -hz, hz, dark)                       // arms
    b.box(hx - arm, hx, 0, armH, -hz, hz, dark)
    b.box(-hx + arm, hx - arm, seatH, h, -hz, -hz + backT, c)           // back rest
    let n = w > 1.5 ? 3 : 2
    let inner = w - 2 * arm
    let gap: Float = 0.01
    let cw = max((inner - gap * Float(n - 1)) / Float(n), 0.005)
    for i in 0..<n {
      let x0 = -hx + arm + Float(i) * (cw + gap)
      b.box(x0, x0 + cw, seatH, seatH + cushH, -hz + backT, hz, light)  // seat cushions
    }
  }

  private nonisolated static func chair(_ b: Builder, _ c: CGColor) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let seatY = h * 0.5
    let st = cl(h * 0.07, 0.01, seatY * 0.5)
    let lt = cl(min(w, d) * 0.1, 0.01, min(w, d) * 0.2)
    let backT = cl(d * 0.12, 0.015, d * 0.3)
    let dark = darker(c, 0.7)
    b.box(-hx, hx, seatY - st, seatY, -hz, hz, c)                                // seat
    b.box(-hx, hx, seatY, h, -hz, -hz + backT, lighter(c, 1.08))                 // back rest
    for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {                        // legs
      let x0 = sx < 0 ? -hx : hx - lt, z0 = sz < 0 ? -hz : hz - lt
      b.box(x0, x0 + lt, 0, seatY - st, z0, z0 + lt, dark)
    } }
  }

  private nonisolated static func table(_ b: Builder, _ c: CGColor) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let coffee = h < 0.5
    let tt = cl(h * 0.07, 0.015, min(0.05, h * 0.3))
    let inset = cl(min(w, d) * 0.06, 0.005, 0.04)
    let r = cl(min(w, d) * (coffee ? 0.05 : 0.04), 0.01, min(w, d) * 0.15) 
    let dark = darker(c, 0.72)
    b.box(-hx, hx, h - tt, h, -hz, hz, c)                                        // top slab
    let lx = hx - inset - r, lz = hz - inset - r
    for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
      b.cylinder(x: sx * lx, z: sz * lz, y0: 0, y1: h - tt, radius: r, dark)
    } }
    if coffee {
      b.box(-lx, lx, h * 0.25, h * 0.25 + tt * 0.7, -lz, lz, darker(c, 0.88))   // lower shelf
    }
  }

  private nonisolated static func bed(_ b: Builder, _ c: CGColor) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let frameH = h * 0.28
    let mattH = h * 0.22
    let top = frameH + mattH
    let headT = cl(d * 0.04, 0.02, 0.08)
    let side = cl(w * 0.015, 0.005, 0.03)
    let foot = cl(d * 0.01, 0.005, 0.03)
    let frame = darker(c, 0.7)
    b.box(-hx, hx, 0, frameH, -hz, hz, frame)                                    // frame
    b.box(-hx, hx, 0, h, -hz, -hz + headT, frame)                                // headboard
    b.box(-hx + side, hx - side, frameH, top, -hz + headT, hz - foot, lighter(c, 1.1))  // mattress
    let gap = cl(w * 0.03, 0.005, 0.06)
    let pw = max((w - 2 * side - 3 * gap) / 2, 0.01)
    let pd = cl(d * 0.14, 0.02, 0.35)
    let ph = cl(h * 0.08, 0.01, 0.15)
    let pz0 = -hz + headT + cl(d * 0.02, 0.005, 0.06)
    for i in 0..<2 {
      let x0 = -hx + side + gap + Float(i) * (pw + gap)
      b.box(x0, x0 + pw, top, top + ph, pz0, pz0 + pd, lighter(c, 1.7))          // pillows
    }
  }

  private nonisolated static func storage(_ b: Builder, _ c: CGColor) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let e = cl(d * 0.06, 0.004, 0.015)                  // front depth for drawer / door slabs
    let m = cl(min(w, h) * 0.04, 0.005, 0.03)           // margin around fronts
    let plinth = cl(h * 0.04, 0.005, 0.05)
    let rows = h > 1.2 ? 4 : (h > 0.7 ? 3 : 2)
    let gap: Float = 0.008
    b.box(-hx, hx, 0, h, -hz, hz - e * 0.5, darker(c, 0.62))                     // dark carcass (shows in gaps)
    let fh = max((h - plinth - m - gap * Float(rows - 1)) / Float(rows), 0.005)
    let front = lighter(c, 1.1)
    for i in 0..<rows {
      let y0 = plinth + Float(i) * (fh + gap)
      b.box(-hx + m, hx - m, y0, y0 + fh, hz - e, hz, front)                     // drawer fronts
      let hw = cl(w * 0.15, 0.01, w * 0.3)
      let hy = y0 + fh / 2
      b.box(-hw / 2, hw / 2, hy - 0.004, hy + 0.004, hz - e, hz, darker(c, 0.5)) // handle slot (flush)
    }
  }

  private nonisolated static func television(_ b: Builder, _ c: CGColor) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let screen = c
    if d < 0.15 {
      // Thin panel on a small foot.
      let footH = cl(h * 0.08, 0.005, 0.05)
      let footW = cl(w * 0.3, 0.01, w)
      b.box(-footW / 2, footW / 2, 0, footH, -hz, hz, darker(c, 0.8))
      b.box(-hx, hx, footH, h, -hz, hz, screen)
      return
    }
    let consoleH = cl(h * 0.35, 0.01, h * 0.6)
    let wood = CGColor(red: 0.62, green: 0.50, blue: 0.38, alpha: 1)
    b.box(-hx, hx, 0, consoleH, -hz, hz, wood)                                   // console
    let neckH = cl(h * 0.03, 0.005, 0.04)
    let panelT = cl(d * 0.1, 0.015, 0.05)
    let panelZ0 = -hz + d * 0.3
    let m = cl(w * 0.04, 0.0, w * 0.2)
    b.box(-w * 0.1, w * 0.1, consoleH, consoleH + neckH + 0.002, panelZ0, panelZ0 + panelT, darker(c, 0.8)) // neck
    b.box(-hx + m, hx - m, consoleH + neckH, h, panelZ0, panelZ0 + panelT, screen)  // screen panel
  }
}
