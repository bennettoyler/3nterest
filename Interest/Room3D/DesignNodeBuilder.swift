import SceneKit
import CoreGraphics

/// Builds a SceneKit node from an AI design. One direct child per part; centimetres -> metres;
/// the whole design is centred in x/z and its lowest point sits on y = 0.
enum DesignNodeBuilder {
  static func node(for design: Design) -> SCNNode {
    let root = SCNNode()
    root.name = design.id
    for part in design.parts {
      guard part.sizeCm.count >= 3, part.positionCm.count >= 3 else { continue }
      root.addChildNode(partNode(part))
    }
    guard !root.childNodes.isEmpty else { return root }

    // Shift children so the design is centred in x/z and its base is at y = 0.
    // (SCNNode.boundingBox of a geometry-less parent is the union of its children.)
    let (lo, hi) = root.boundingBox
    let dx = -(Float(lo.x) + Float(hi.x)) / 2
    let dz = -(Float(lo.z) + Float(hi.z)) / 2
    let dy = -Float(lo.y)
    for child in root.childNodes {
      let p = child.position
      child.position = SCNVector3(Float(p.x) + dx, Float(p.y) + dy, Float(p.z) + dz)
    }
    return root
  }

  private static func partNode(_ part: DesignPart) -> SCNNode {
    let s = part.sizeCm.map { $0 / 100 }
    let geometry: SCNGeometry
    switch part.shape {
    case .box:
      geometry = SCNBox(width: CGFloat(s[0]), height: CGFloat(s[1]), length: CGFloat(s[2]), chamferRadius: 0)
    case .cylinder:
      geometry = SCNCylinder(radius: CGFloat(s[0] / 2), height: CGFloat(s[1]))
    }
    let material = SCNMaterial()
    material.diffuse.contents = color(fromHex: part.colorHex)
    material.lightingModel = .blinn
    geometry.materials = [material]

    let node = SCNNode(geometry: geometry)
    node.name = part.name
    let p = part.positionCm
    node.position = SCNVector3(p[0] / 100, p[1] / 100, p[2] / 100)
    let r = part.rotationDeg
    if r.count >= 3 {
      let k = Float.pi / 180
      node.eulerAngles = SCNVector3(r[0] * k, r[1] * k, r[2] * k)
    }
    return node
  }

  private static func color(fromHex hex: String) -> CGColor {
    var h = hex.trimmingCharacters(in: .whitespaces)
    if h.hasPrefix("#") { h.removeFirst() }
    guard h.count == 6, let v = UInt32(h, radix: 16) else {
      return CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
    }
    return CGColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
  }
}
