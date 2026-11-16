import Foundation
import SceneKit

extension FurnitureShapes {
  /// Office furniture keyed by lowercase name keyword. Returns nil when no keyword matches.
  /// Base at y = 0, centred in x/z, bounding box equals `size`, front = +Z.
  nonisolated static func officeNode(named name: String, size: Dimensions) -> SCNNode? {
    let b = OfficeBuilder(w: size.width, h: size.height, d: size.depth)
    if name.contains("round meeting table") {
      roundMeetingTable(b)
    } else if name.contains("conference table") {
      conferenceTable(b)
    } else if name.contains("writing desk") {
      writingDesk(b)
    } else if name.contains("filing cabinet") {
      filingCabinet(b)
    } else if name.contains("bookshelf") {
      bookshelf(b)
    } else if name.contains("whiteboard") {
      whiteboard(b)
    } else {
      return nil
    }
    return officeFit(b.container, size)
  }

  // MARK: Shapes

  private nonisolated static func writingDesk(_ b: OfficeBuilder) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let oak = officeHex(0xC9A46B), dark = officeHex(0x2B2B2E)
    let top: Float = 0.03, leg: Float = 0.05, inset: Float = 0.02
    b.box(-hx, hx, h - top, h, -hz, hz, oak)
    for sx: Float in [-1, 1] {
      for sz: Float in [-1, 1] {
        let x0 = sx < 0 ? -hx + inset : hx - inset - leg
        let z0 = sz < 0 ? -hz + inset : hz - inset - leg
        b.box(x0, x0 + leg, 0, h - top, z0, z0 + leg, oak)
      }
    }
    // Drawer unit under the right side of the top.
    let ux0 = hx - min(0.42, w * 0.3), ux1 = hx - inset - leg
    let dh = min(h * 0.42, h - top - 0.1)
    let y1 = h - top, y0 = y1 - dh
    let zf = hz - 0.04
    b.box(ux0, ux1, y0, y1, -hz + inset, zf, officeShade(oak, 0.92))
    let gap: Float = 0.006
    let mid = (y0 + y1) / 2
    b.box(ux0 + 0.01, ux1 - 0.01, y0 + 0.01, mid - gap, zf, zf + 0.01, officeShade(oak, 1.05))
    b.box(ux0 + 0.01, ux1 - 0.01, mid + gap, y1 - 0.01, zf, zf + 0.01, officeShade(oak, 1.05))
    let cx = (ux0 + ux1) / 2, pw = min(0.08, (ux1 - ux0) * 0.4)
    b.box(cx - pw / 2, cx + pw / 2, (y0 + mid) / 2 - 0.008, (y0 + mid) / 2 + 0.008, zf + 0.01, zf + 0.025, dark)
    b.box(cx - pw / 2, cx + pw / 2, (mid + y1) / 2 - 0.008, (mid + y1) / 2 + 0.008, zf + 0.01, zf + 0.025, dark)
  }

  private nonisolated static func filingCabinet(_ b: OfficeBuilder) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let metal = officeHex(0xC9CDD2), inner = officeHex(0x5B6066), dark = officeHex(0x2B2B2E)
    b.box(-hx, hx, 0, h, -hz, hz - 0.012, inner)
    let n = h > 0.9 ? 4 : 3
    let gap: Float = 0.008, margin: Float = 0.012
    let fh = (h - 2 * margin - gap * Float(n - 1)) / Float(n)
    for i in 0..<n {
      let y0 = margin + Float(i) * (fh + gap)
      b.box(-hx + 0.008, hx - 0.008, y0, y0 + fh, hz - 0.012, hz, metal)
      let cy = y0 + fh * 0.7
      let hw = w * 0.3
      b.box(-hw / 2, hw / 2, cy - 0.01, cy + 0.01, hz - 0.012, hz, dark)
    }
  }

  private nonisolated static func bookshelf(_ b: OfficeBuilder) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let oak = officeHex(0xC9A46B), back = officeShade(oak, 0.72)
    let t: Float = 0.02
    b.box(-hx, -hx + t, 0, h, -hz, hz, oak)
    b.box(hx - t, hx, 0, h, -hz, hz, oak)
    b.box(-hx + t, hx - t, h - t, h, -hz, hz, oak)
    b.box(-hx + t, hx - t, 0, t, -hz, hz, oak)
    b.box(-hx + t, hx - t, t, h - t, -hz, -hz + 0.01, back)
    let span = h - 2 * t
    let comp = span / 5
    for i in 1...4 {
      let y = t + comp * Float(i)
      b.box(-hx + t, hx - t, y - t / 2, y + t / 2, -hz + 0.01, hz, oak)
    }
    let palette: [UInt32] = [0x8C3B3B, 0x3F5F7A, 0x5E7A4F, 0xB08A3E, 0x6B4E7A, 0x4A4F57, 0xA85E3A, 0x3E6F6A]
    var seed = 7
    func rnd() -> Float {
      seed = (seed &* 1103515245 &+ 12345) & 0x7fffffff
      return Float(seed % 1000) / 1000
    }
    for c in [0, 1, 3] {
      let base = t + comp * Float(c) + (c == 0 ? 0 : t / 2)
      let room = comp - (c == 0 ? 0 : t / 2) - (c == 0 ? t / 2 : 0)
      var x = -hx + t + 0.02
      let limit = hx - t - 0.02 - (c == 1 ? w * 0.25 : 0)
      var k = c * 3
      while true {
        let bw = 0.022 + rnd() * 0.022
        if x + bw > limit { break }
        let bh = room * (0.68 + rnd() * 0.25)
        b.box(x, x + bw, base, base + bh, -hz + 0.03, hz - 0.04, officeHex(palette[k % palette.count]))
        x += bw + 0.002
        k += 1
      }
    }
  }

  private nonisolated static func whiteboard(_ b: OfficeBuilder) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let grey = officeHex(0x9AA0A6), white = officeHex(0xF7F8FA), dark = officeHex(0x2B2B2E)
    let boardH = h * 0.6, y0 = h - boardH
    let fr: Float = 0.025
    // Board
    b.box(-hx, hx, y0, h, 0.0, 0.03, grey)
    b.box(-hx + fr, hx - fr, y0 + fr, h - fr, 0.0, 0.034, white)
    // Marker tray
    b.box(-hx * 0.7, hx * 0.7, y0 - 0.02, y0, 0.0, 0.07, grey)
    // Uprights and feet
    let ux = hx * 0.8
    for s: Float in [-1, 1] {
      let x = s * ux
      b.box(x - 0.02, x + 0.02, 0.09, y0 + boardH * 0.8, -0.04, 0.0, grey)
      b.box(x - 0.025, x + 0.025, 0.05, 0.09, -hz, hz, grey)
      for z: Float in [-1, 1] {
        b.cylinder(x: x, z: z * (hz - 0.04), y0: 0, y1: 0.05, radius: 0.025, dark)
      }
    }
  }

  private nonisolated static func roundMeetingTable(_ b: OfficeBuilder) {
    let w = b.w, h = b.h, d = b.d
    let white = officeHex(0xF5F5F3), grey = officeHex(0x8E949A)
    let top: Float = 0.03
    // Unit-radius shapes are built with radius w/2 and squashed in z for ellipses.
    let zs = d / max(w, 0.001)
    let r = w / 2
    b.cylinder(x: 0, z: 0, y0: h - top, y1: h, radius: r, white, zScale: zs, segments: 48)
    b.cylinder(x: 0, z: 0, y0: 0.04, y1: h - top, radius: min(w, d) * 0.05, grey)
    b.cylinder(x: 0, z: 0, y0: 0, y1: 0.04, radius: r * 0.45, grey, zScale: zs, segments: 48)
  }

  private nonisolated static func conferenceTable(_ b: OfficeBuilder) {
    let w = b.w, h = b.h, d = b.d
    let hx = w / 2, hz = d / 2
    let walnut = officeHex(0x5A3D28), leg = officeShade(walnut, 0.8)
    let top: Float = 0.04
    let cap = min(0.05, w * 0.03)
    b.box(-hx + cap, hx - cap, h - top, h, -hz, hz, walnut)
    b.box(-hx, -hx + cap, h - top, h, -hz + cap, hz - cap, walnut)
    b.box(hx - cap, hx, h - top, h, -hz + cap, hz - cap, walnut)
    for s: Float in [-1, 1] {
      let x = s * w * 0.3
      b.box(x - 0.05, x + 0.05, 0.03, h - top, -hz * 0.6, hz * 0.6, leg)
      b.box(x - 0.1, x + 0.1, 0, 0.03, -hz * 0.75, hz * 0.75, leg)
    }
  }
}

// MARK: - Helpers

fileprivate func officeHex(_ v: UInt32) -> CGColor {
  CGColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
          blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

fileprivate func officeShade(_ c: CGColor, _ f: CGFloat) -> CGColor {
  let comps = c.components ?? [0.5, 0.5, 0.5, 1]
  func ch(_ i: Int) -> CGFloat { min(max((i < comps.count - 1 ? comps[i] : comps[0]) * f, 0), 1) }
  return CGColor(red: ch(0), green: ch(1), blue: ch(2), alpha: 1)
}

fileprivate struct OfficeBuilder {
  let w: Float, h: Float, d: Float
  let container = SCNNode()

  func material(_ c: CGColor) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = c
    return m
  }

  func box(_ x0: Float, _ x1: Float, _ y0: Float, _ y1: Float, _ z0: Float, _ z1: Float, _ color: CGColor) {
    let sx = max(x1 - x0, 0.001), sy = max(y1 - y0, 0.001), sz = max(z1 - z0, 0.001)
    let chamfer = min(0.008, min(sx, min(sy, sz)) * 0.25)
    let g = SCNBox(width: CGFloat(sx), height: CGFloat(sy), length: CGFloat(sz), chamferRadius: CGFloat(chamfer))
    g.materials = [material(color)]
    let n = SCNNode(geometry: g)
    n.position = SCNVector3((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    container.addChildNode(n)
  }

  func cylinder(x: Float, z: Float, y0: Float, y1: Float, radius: Float, _ color: CGColor,
                zScale: Float = 1, segments: Int = 16) {
    let g = SCNCylinder(radius: CGFloat(radius), height: CGFloat(max(y1 - y0, 0.001)))
    g.radialSegmentCount = segments
    g.materials = [material(color)]
    let n = SCNNode(geometry: g)
    n.position = SCNVector3(x, (y0 + y1) / 2, z)
    n.scale = SCNVector3(1, 1, zScale)
    container.addChildNode(n)
  }
}

/// World-space (relative to `root`) extents of all geometry under `root`.
fileprivate func officeExtents(_ root: SCNNode) -> (min: SCNVector3, max: SCNVector3)? {
  var lo = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
  var hi = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
  var found = false
  func walk(_ n: SCNNode) {
    if n.geometry != nil {
      let (a, b) = n.boundingBox
      for x in [a.x, b.x] { for y in [a.y, b.y] { for z in [a.z, b.z] {
        let p = n.convertPosition(SCNVector3(x, y, z), to: root)
        lo = SCNVector3(min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z))
        hi = SCNVector3(max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z))
        found = true
      } } }
    }
    n.childNodes.forEach(walk)
  }
  walk(root)
  return found ? (lo, hi) : nil
}

/// Wraps `container` so the result's box is exactly `size`, centred in x/z with base at y = 0.
fileprivate func officeFit(_ container: SCNNode, _ size: Dimensions) -> SCNNode {
  let outer = SCNNode()
  outer.addChildNode(container)
  guard let (lo, hi) = officeExtents(container) else { return outer }
  let sx = size.width / max(hi.x - lo.x, 0.0001)
  let sy = size.height / max(hi.y - lo.y, 0.0001)
  let sz = size.depth / max(hi.z - lo.z, 0.0001)
  container.scale = SCNVector3(sx, sy, sz)
  container.position = SCNVector3(-(lo.x + hi.x) / 2 * sx, -lo.y * sy, -(lo.z + hi.z) / 2 * sz)
  return outer
}
