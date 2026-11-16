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

    /// Box centred at (cx, cy, cz) with the given size, rotated about Y by `yaw`.
    func boxYaw(cx: Float, cy: Float, cz: Float, sx: Float, sy: Float, sz: Float, yaw: Float, _ color: CGColor) {
      let g = SCNBox(width: CGFloat(sx), height: CGFloat(sy), length: CGFloat(sz), chamferRadius: 0)
      g.materials = [Self.material(color)]
      let n = SCNNode(geometry: g)
      n.position = SCNVector3(cx, cy, cz)
      n.eulerAngles.y = yaw
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

  /// A wall-mounted flat-panel TV: thin black panel `size.width` x `size.height`, depth `size.depth` clamped to
  /// 0.03...0.1, with a dark-grey bezel and a slightly lighter screen face on local +Z. Bottom edge at y = 0, centred in x/z.
  nonisolated static func wallTelevision(size: Dimensions) -> SCNNode {
    let depth = cl(size.depth, 0.03, 0.1)
    let b = Builder(w: size.width, h: size.height, d: depth)
    let hx = size.width / 2, h = size.height, hz = depth / 2
    let bezel = cl(min(size.width, h) * 0.03, 0.008, 0.03)
    let f = hz - 0.005
    let black = CGColor(red: 0.04, green: 0.04, blue: 0.045, alpha: 1)
    let grey = CGColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
    let screen = CGColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1)
    b.box(-hx, hx, 0, h, -hz, f, black)                                                    // panel
    b.box(-hx, hx, h - bezel, h, f, hz, grey)                                              // bezel
    b.box(-hx, hx, 0, bezel, f, hz, grey)
    b.box(-hx, -hx + bezel, bezel, h - bezel, f, hz, grey)
    b.box(hx - bezel, hx, bezel, h - bezel, f, hz, grey)
    b.box(-hx + bezel, hx - bezel, bezel, h - bezel, f, hz, screen)                        // screen face
    return b.container
  }

  /// Purpose-built shapes for specific catalogue products (matched by name); nil for everything else.
  nonisolated static func node(for product: Product) -> SCNNode? {
    node(named: product.name, size: product.dimensions)
  }

  /// Shape for a sample-room product id the current catalogue does not know (a backend seeded before these products existed).
  nonisolated static func node(forUnmatchedProductId id: String, size: Dimensions) -> SCNNode? {
    let names = [
      "stub-stacking-chair": "stacking chair", "stub-task-chair": "task chair", "stub-flip-table": "rolling table",
      "stub-cane-sideboard": "cane sideboard", "stub-wall-tv": "wall tv",
      "stub-writing-desk": "writing desk", "stub-filing-cabinet": "filing cabinet", "stub-bookshelf": "bookshelf",
      "stub-whiteboard": "whiteboard", "stub-round-meeting-table": "round meeting table",
      "stub-conference-table": "conference table", "stub-refrigerator": "refrigerator", "stub-stove": "stove",
      "stub-sink": "sink", "stub-dishwasher": "dishwasher", "stub-washer": "washer", "stub-toilet": "toilet",
      "stub-bathtub": "bathtub", "stub-twin-bed": "twin bed", "stub-king-bed": "king bed",
      "stub-nightstand": "nightstand", "stub-dresser": "dresser", "stub-wardrobe": "wardrobe",
    ]
    return names[id].flatMap { node(named: $0, size: size) }
  }

  private nonisolated static func node(named rawName: String, size: Dimensions) -> SCNNode? {
    let name = rawName.lowercased()
    let b = Builder(w: size.width, h: size.height, d: size.depth)
    if name.contains("stacking chair") { stackingChair(b) }
    else if name.contains("task chair") { taskChair(b) }
    else if name.contains("rolling table") { rollingTable(b) }
    else if name.contains("cane sideboard") { caneSideboard(b) }
    else if name.contains("wall tv") { return wallTelevision(size: size) }
    else {
      return officeNode(named: name, size: size) ?? kitchenBathNode(named: name, size: size) ?? bedroomNode(named: name, size: size)
    }
    return b.container
  }

  private nonisolated static func stackingChair(_ b: Builder) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let white = CGColor(red: 0.957, green: 0.957, blue: 0.949, alpha: 1)
    let leg = darker(white, 0.93)
    let seatY = h * 0.53, st = cl(h * 0.035, 0.015, 0.04)
    let lt = cl(min(w, d) * 0.07, 0.015, 0.03)
    b.box(-hx, hx, seatY - st, seatY, -hz + lt * 0.5, hz, white)                 // seat
    for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {                        // four slim legs
      let x0 = sx < 0 ? -hx : hx - lt, z0 = sz < 0 ? -hz : hz - lt
      b.box(x0, x0 + lt, 0, seatY - st, z0, z0 + lt, leg)
    } }
    for sx: Float in [-1, 1] {                                                   // back posts
      let x0 = sx < 0 ? -hx : hx - lt
      b.box(x0, x0 + lt, seatY - st, h, -hz, -hz + lt, white)
    }
    let slatH = cl((h - seatY) * 0.22, 0.03, 0.08)
    b.box(-hx, hx, h - slatH, h, -hz, -hz + lt, white)                           // upper slat
    let lowY = seatY + (h - seatY) * 0.28
    b.box(-hx, hx, lowY, lowY + slatH, -hz, -hz + lt, white)                     // lower slat
  }

  private nonisolated static func taskChair(_ b: Builder) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let black = CGColor(red: 0.137, green: 0.141, blue: 0.153, alpha: 1)
    let mesh = CGColor(red: 0.26, green: 0.27, blue: 0.29, alpha: 1)
    let casterH: Float = 0.04
    let baseR = min(w, d) * 0.46
    let seatY = h * 0.45, st = cl(h * 0.08, 0.04, 0.09)
    let seatW = w * 0.80, seatHz = hz
    // star base
    for i in 0..<5 {
      let a = Float(i) * 2 * .pi / 5 + 0.3
      let mx = sin(a) * baseR / 2, mz = cos(a) * baseR / 2
      b.boxYaw(cx: mx, cy: casterH + 0.015, cz: mz, sx: 0.04, sy: 0.03, sz: baseR, yaw: a, black)
      let tipX = sin(a) * baseR, tipZ = cos(a) * baseR
      b.cylinder(x: tipX, z: tipZ, y0: 0, y1: casterH, radius: 0.022, CGColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1))
    }
    b.cylinder(x: 0, z: 0, y0: casterH, y1: seatY - st, radius: 0.025, CGColor(red: 0.45, green: 0.46, blue: 0.48, alpha: 1)) // gas lift
    b.box(-seatW / 2, seatW / 2, seatY - st, seatY, -hz * 0.75, seatHz, black)   // seat
    // armrests reach the full width
    let armY = seatY + h * 0.17
    for sx: Float in [-1, 1] {
      let x0 = sx < 0 ? -hx : hx - 0.04
      b.box(x0, x0 + 0.04, armY, armY + 0.03, -hz * 0.3, hz * 0.45, black)       // arm pad
      b.box(sx < 0 ? -hx + 0.005 : hx - 0.035, sx < 0 ? -hx + 0.035 : hx - 0.005, seatY, armY, hz * 0.05, hz * 0.15, black)
    }
    // back: frame + lighter semi-transparent mesh panel, with the top reaching h and rear reaching -hz
    let backB = seatY + 0.06
    b.box(-seatW / 2, seatW / 2, backB, h, -hz, -hz + 0.04, black)
    let panel = SCNBox(width: CGFloat(seatW - 0.08), height: CGFloat(h - backB - 0.08), length: 0.01, chamferRadius: 0)
    let m = SCNMaterial()
    m.diffuse.contents = mesh
    m.transparency = 0.7
    panel.materials = [m]
    let pn = SCNNode(geometry: panel)
    pn.position = SCNVector3(0, (backB + h) / 2, -hz + 0.045)
    b.container.addChildNode(pn)
  }

  private nonisolated static func rollingTable(_ b: Builder) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let white = CGColor(red: 0.961, green: 0.961, blue: 0.953, alpha: 1)
    let frame = darker(white, 0.95)
    let dark = CGColor(red: 0.1, green: 0.1, blue: 0.11, alpha: 1)
    let tt: Float = 0.03
    let casterH: Float = 0.06
    b.box(-hx, hx, h - tt, h, -hz, hz, white)                                    // top
    let legX = hx * 0.72, bar: Float = 0.05
    let footH0 = casterH, footH1 = casterH + 0.04
    let footZ = hz - 0.04
    for sx: Float in [-1, 1] {
      let cx = sx * legX
      b.box(cx - bar / 2, cx + bar / 2, footH0, footH1, -footZ, footZ, frame)    // foot bar (T-leg base)
      b.box(cx - bar / 2, cx + bar / 2, footH1, h - tt, -0.025, 0.025, frame)    // post
      for sz: Float in [-1, 1] {
        b.cylinder(x: cx, z: sz * (footZ - 0.02), y0: 0, y1: casterH, radius: 0.025, dark) // caster
      }
    }
    b.box(-legX, legX, h - tt - 0.08, h - tt, -0.02, 0.02, frame)                // stretcher under the top
  }

  private nonisolated static func caneSideboard(_ b: Builder) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let walnut = CGColor(red: 0.42, green: 0.29, blue: 0.184, alpha: 1)
    let cane = CGColor(red: 0.847, green: 0.769, blue: 0.604, alpha: 1)
    let knob = CGColor(red: 0.12, green: 0.1, blue: 0.09, alpha: 1)
    let legH = cl(h * 0.14, 0.05, 0.14), lt: Float = 0.04
    let fr: Float = 0.018                                                        // front slab depth
    for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
      let x0 = sx < 0 ? -hx + 0.02 : hx - 0.02 - lt, z0 = sz < 0 ? -hz : hz - lt
      b.box(x0, x0 + lt, 0, legH, z0, z0 + lt, walnut)
    } }
    b.box(-hx, hx, legH, h, -hz, hz - fr, walnut)                                // carcass
    let n = 4
    let gap: Float = 0.006, m: Float = 0.012
    let dw = (w - 2 * m - gap * Float(n - 1)) / Float(n)
    let y0 = legH + m, y1 = h - m
    let rail = cl(dw * 0.1, 0.02, 0.04)
    for i in 0..<n {
      let x0 = -hx + m + Float(i) * (dw + gap)
      b.box(x0, x0 + dw, y0, y1, hz - fr, hz - 0.004, walnut)                    // door frame slab
      b.box(x0 + rail, x0 + dw - rail, y0 + rail, y1 - rail, hz - fr, hz - 0.002, cane) // cane insert
      let kx = i % 2 == 0 ? x0 + dw - rail * 0.5 : x0 + rail * 0.5
      let ky = (y0 + y1) / 2
      b.box(kx - 0.008, kx + 0.008, ky - 0.02, ky + 0.02, hz - 0.01, hz, knob)   // knob
    }
  }
}
