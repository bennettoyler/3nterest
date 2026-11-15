import Foundation
import SceneKit

/// Hardcoded procedural decor for the bundled scanned meeting room. Empty / nil for any other room.
enum RoomDecor {
  static func matches(_ shell: RoomShell) -> Bool {
    guard shell.walls.count == 4 else { return false }
    let widths = shell.walls.map { $0.width }.sorted()
    let expected: [Float] = [5.71, 5.71, 7.60, 7.60]
    for (w, e) in zip(widths, expected) where abs(w - e) > 0.06 { return false }
    return shell.walls.allSatisfy { abs($0.height - 2.42) <= 0.06 }
  }

  static func floorColor(for shell: RoomShell) -> CGColor? {
    matches(shell) ? hex(0x4A4A4C) : nil
  }

  static func wallColor(for wall: Surface, in shell: RoomShell) -> CGColor? {
    guard matches(shell), wall.transform.count == 16 else { return nil }
    return abs(wall.transform[12] + 3.80) < 0.1 && abs(wall.transform[14]) < 1.0 ? hex(0xF26A1B) : nil
  }

  static func nodes(for shell: RoomShell) -> [SCNNode] {
    guard matches(shell) else { return [] }
    var out: [SCNNode] = []
    out.append(rug())
    out.append(column())
    out.append(whiteboard())
    out.append(acUnit())
    out.append(plant(at: SCNVector3(-1.5, 0, 2.5), name: "decor-plant-1"))
    out.append(plant(at: SCNVector3(3.4, 0, 2.5), name: "decor-plant-2"))
    out.append(trashCan())
    out.append(wallClock())
    for (i, w) in shell.windows.enumerated() where w.transform.count == 16 { out.append(blinds(w, index: i)) }
    for (i, d) in shell.doors.enumerated() where d.transform.count == 16 { out.append(door(d, index: i)) }
    out.append(chairStack(at: SCNVector3(-3.45, 0, -1.3), name: "decor-chairs-1"))
    out.append(chairStack(at: SCNVector3(-3.45, 0, -2.0), name: "decor-chairs-2"))
    return out
  }

  // MARK: helpers

  private static func hex(_ v: Int) -> CGColor {
    CGColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: 1)
  }

  private static func material(_ c: CGColor) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = c
    return m
  }

  @discardableResult
  private static func box(_ parent: SCNNode, _ w: Float, _ h: Float, _ l: Float, at p: SCNVector3, _ c: CGColor) -> SCNNode {
    let g = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(l), chamferRadius: 0)
    g.materials = [material(c)]
    let n = SCNNode(geometry: g)
    n.position = p
    parent.addChildNode(n)
    return n
  }

  @discardableResult
  private static func cylinder(_ parent: SCNNode, radius: Float, height: Float, at p: SCNVector3, _ c: CGColor) -> SCNNode {
    let g = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
    g.radialSegmentCount = 24
    g.materials = [material(c)]
    let n = SCNNode(geometry: g)
    n.position = p
    parent.addChildNode(n)
    return n
  }

  private static func container(_ name: String, at p: SCNVector3 = SCNVector3Zero) -> SCNNode {
    let n = SCNNode()
    n.name = name
    n.position = p
    return n
  }

  // MARK: items

  private static func rug() -> SCNNode {
    let n = container("decor-rug", at: SCNVector3(0.6, 0.006, 0.2))
    box(n, 5.0, 0.01, 3.6, at: SCNVector3Zero, hex(0xE4D9C6))
    return n
  }

  private static func column() -> SCNNode {
    let n = container("decor-column", at: SCNVector3(-2.0, 0, -0.1))
    cylinder(n, radius: 0.10, height: 2.42, at: SCNVector3(0, 1.21, 0), hex(0xFAFAFA))
    cylinder(n, radius: 0.14, height: 0.12, at: SCNVector3(0, 2.36, 0), hex(0xF0F0F0))
    return n
  }

  private static func whiteboard() -> SCNNode {
    let n = container("decor-whiteboard", at: SCNVector3(-3.78, 1.40, 0.7))
    let frame = hex(0xC8CBCF)
    box(n, 0.02, 1.2, 2.4, at: SCNVector3Zero, hex(0xF7F8FA))
    box(n, 0.03, 0.03, 2.46, at: SCNVector3(0.005, 0.615, 0), frame)
    box(n, 0.03, 0.03, 2.46, at: SCNVector3(0.005, -0.615, 0), frame)
    box(n, 0.03, 1.2, 0.03, at: SCNVector3(0.005, 0, 1.215), frame)
    box(n, 0.03, 1.2, 0.03, at: SCNVector3(0.005, 0, -1.215), frame)
    box(n, 0.08, 0.025, 0.6, at: SCNVector3(0.03, -0.64, 0.2), hex(0xB0B3B8))     // marker tray
    box(n, 0.025, 0.02, 0.12, at: SCNVector3(0.07, -0.62, 0.1), hex(0x2255AA))    // markers
    box(n, 0.025, 0.02, 0.12, at: SCNVector3(0.07, -0.62, 0.3), hex(0xCC2222))
    return n
  }

  private static func acUnit() -> SCNNode {
    let n = container("decor-ac", at: SCNVector3(-3.70, 2.18, 0.4))
    box(n, 0.2, 0.28, 0.9, at: SCNVector3Zero, hex(0xEDEBE6))
    box(n, 0.02, 0.05, 0.8, at: SCNVector3(0.1, -0.08, 0), hex(0xCFCDC8))          // vent slot
    return n
  }

  private static func plant(at p: SCNVector3, name: String) -> SCNNode {
    let n = container(name, at: p)
    cylinder(n, radius: 0.18, height: 0.3, at: SCNVector3(0, 0.15, 0), hex(0x2B2B2D))
    cylinder(n, radius: 0.02, height: 1.1, at: SCNVector3(0, 0.75, 0), hex(0x5A3E2B))
    let green = hex(0x2F5D3A)
    let clusters: [(Float, Float, Float, Float, Float)] = [   // x, y, z, radius, y-squash
      (0, 1.55, 0, 0.18, 0.8), (0.12, 1.25, 0.08, 0.15, 0.7), (-0.12, 1.15, -0.06, 0.15, 0.7),
      (0.04, 0.95, -0.12, 0.13, 0.7), (-0.1, 1.40, 0.1, 0.13, 0.8), (0.1, 0.80, 0.1, 0.12, 0.7)]
    for c in clusters {
      let g = SCNSphere(radius: CGFloat(c.3))
      g.segmentCount = 12
      g.materials = [material(green)]
      let s = SCNNode(geometry: g)
      s.position = SCNVector3(c.0, c.1, c.2)
      s.scale = SCNVector3(1, c.4, 1)
      n.addChildNode(s)
    }
    return n
  }

  private static func trashCan() -> SCNNode {
    let n = container("decor-trash", at: SCNVector3(-1.75, 0, -2.6))
    cylinder(n, radius: 0.19, height: 0.75, at: SCNVector3(0, 0.375, 0), hex(0xB8BCC0))
    cylinder(n, radius: 0.195, height: 0.06, at: SCNVector3(0, 0.66, 0), hex(0x1A1A1A))
    return n
  }

  private static func wallClock() -> SCNNode {
    let n = container("decor-clock", at: SCNVector3(-1.35, 1.75, 2.83))
    box(n, 0.35, 0.35, 0.04, at: SCNVector3Zero, hex(0x2A2A2C))
    box(n, 0.30, 0.30, 0.01, at: SCNVector3(0, 0, -0.016), hex(0xFAFAFA))
    let hands = hex(0x1A1A1A)
    box(n, 0.012, 0.11, 0.006, at: SCNVector3(0, 0.055, -0.024), hands)
    let minute = box(n, 0.012, 0.08, 0.006, at: SCNVector3(0.03, 0.01, -0.027), hands)
    minute.eulerAngles.z = -1.0
    return n
  }

  /// +1 or -1: which local-Z direction of the surface points toward the room centre.
  private static func roomSideSign(_ s: Surface) -> Float {
    let t = s.transform
    let dot = t[8] * (-t[12]) + t[10] * (-t[14])
    return dot >= 0 ? 1 : -1
  }

  private static func blinds(_ w: Surface, index: Int) -> SCNNode {
    let n = SCNNode()
    n.name = "decor-blinds-\(index)"
    n.transform = w.transform.scnMatrix
    let z = roomSideSign(w) * 0.02
    box(n, w.width * 0.94, w.height * 0.92, 0.01, at: SCNVector3(0, -w.height * 0.02, z), hex(0xC9D3DC))
    box(n, w.width * 1.0, 0.07, 0.05, at: SCNVector3(0, w.height * 0.5 - 0.035, z + roomSideSign(w) * 0.015), hex(0xF1EFE9))
    return n
  }

  private static func door(_ d: Surface, index: Int) -> SCNNode {
    let n = SCNNode()
    n.name = "decor-door-\(index)"
    n.transform = d.transform.scnMatrix
    let s = roomSideSign(d)
    box(n, d.width, d.height - 0.01, 0.02, at: SCNVector3(0, 0, s * 0.02), hex(0xFAFAFA))
    box(n, d.width * 0.5, d.height * 0.4, 0.012, at: SCNVector3(0, d.height * 0.18, s * 0.03), hex(0xB7C4CF))
    box(n, 0.02, 0.12, 0.05, at: SCNVector3(d.width * 0.38, -d.height * 0.03, s * 0.045), hex(0x2A2A2C))
    return n
  }

  private static func chairStack(at p: SCNVector3, name: String) -> SCNNode {
    let n = container(name, at: p)
    n.eulerAngles.y = .pi / 2   // face +X
    let white = hex(0xF4F4F2)
    let leg = hex(0xD8D8D4)
    let w: Float = 0.45, d: Float = 0.5
    box(n, w, 0.04, d, at: SCNVector3(0, 0.43, 0), white)                           // seat
    box(n, w, 0.40, 0.04, at: SCNVector3(0, 0.65, -d / 2 + 0.02), white)            // back
    for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {
      box(n, 0.04, 0.41, 0.04, at: SCNVector3(sx * (w / 2 - 0.02), 0.205, sz * (d / 2 - 0.02)), leg)
    } }
    for i in 1...4 {
      box(n, w, 0.04, d, at: SCNVector3(0, 0.43 + 0.07 * Float(i), -0.02 * Float(i)), white)
    }
    return n
  }
}
