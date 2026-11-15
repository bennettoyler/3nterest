import Foundation
import SceneKit

enum RoomSceneBuilder {
  static func scene(for room: Room, products: [Product], designs: [Design]) -> SCNScene {
    let scene = SCNScene()
    let root = scene.rootNode

    // Floor, sized to the walls' extent
    let xs = room.shell.walls.map { $0.transform.count == 16 ? $0.transform[12] : 0 }
    let zs = room.shell.walls.map { $0.transform.count == 16 ? $0.transform[14] : 0 }
    let minX = xs.min() ?? -2, maxX = xs.max() ?? 2, minZ = zs.min() ?? -2, maxZ = zs.max() ?? 2
    let fw = max(maxX - minX, 1), fd = max(maxZ - minZ, 1)
    let cx = (minX + maxX) / 2, cz = (minZ + maxZ) / 2

    // Surfaces: single-sided planes facing the room centre (dollhouse view)
    for w in room.shell.walls {
      root.addChildNode(surfaceNode(w, centre: (cx, cz), offset: 0, color: CGColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1)))
    }
    for d in room.shell.doors {
      root.addChildNode(surfaceNode(d, centre: (cx, cz), offset: 0.015, color: CGColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1)))
    }
    for w in room.shell.windows {
      root.addChildNode(surfaceNode(w, centre: (cx, cz), offset: 0.015, color: CGColor(red: 0.45, green: 0.58, blue: 0.70, alpha: 1)))
    }
    let plane = SCNPlane(width: CGFloat(fw), height: CGFloat(fd))
    let fm = SCNMaterial()
    fm.diffuse.contents = CGColor(red: 0.78, green: 0.72, blue: 0.64, alpha: 1)
    fm.isDoubleSided = true
    plane.materials = [fm]
    let floor = SCNNode(geometry: plane)
    floor.name = "floor"
    floor.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
    floor.position = SCNVector3(cx, 0, cz)
    root.addChildNode(floor)

    // Placements
    for p in room.placements {
      root.addChildNode(placementNode(for: p, products: products, designs: designs))
    }

    // Lights
    let amb = SCNNode()
    amb.light = SCNLight()
    amb.light?.type = .ambient
    amb.light?.intensity = 600
    root.addChildNode(amb)
    let dir = SCNNode()
    dir.light = SCNLight()
    dir.light?.type = .directional
    dir.light?.intensity = 900
    dir.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
    root.addChildNode(dir)

    // Camera above and behind one corner, looking at the room centre
    let extent = max(fw, fd)
    let cam = SCNNode()
    cam.camera = SCNCamera()
    cam.camera?.zFar = 200
    cam.position = SCNVector3(cx + fw / 2 + extent * 0.35, 2.2 + extent * 0.6, cz + fd / 2 + extent * 0.35)
    cam.look(at: SCNVector3(cx, 0.6, cz))
    cam.name = "defaultCamera"
    root.addChildNode(cam)
    return scene
  }

  /// Moves "defaultCamera" back along its current look direction so the whole room (all geometry)
  /// fits in a viewport of the given size, using the smaller of the horizontal/vertical FOVs.
  /// Call once at setup / first layout; it does not touch the user's orbit afterwards.
  static func frameCamera(in scene: SCNScene, viewportSize: CGSize) {
    guard viewportSize.width > 1, viewportSize.height > 1,
          let cam = scene.rootNode.childNode(withName: "defaultCamera", recursively: false),
          let camera = cam.camera else { return }
    var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    scene.rootNode.enumerateHierarchy { node, _ in
      guard node.geometry != nil else { return }
      let (a, b) = node.boundingBox
      for x in [a.x, b.x] { for y in [a.y, b.y] { for z in [a.z, b.z] {
        let w = node.convertPosition(SCNVector3(x, y, z), to: nil)
        lo = simd_min(lo, SIMD3<Float>(Float(w.x), Float(w.y), Float(w.z)))
        hi = simd_max(hi, SIMD3<Float>(Float(w.x), Float(w.y), Float(w.z)))
      } } }
    }
    guard lo.x <= hi.x else { return }
    let centre = (lo + hi) / 2
    let radius = simd_length(hi - lo) / 2
    let aspect = Float(viewportSize.width / viewportSize.height)
    camera.projectionDirection = .vertical
    let vHalf = Float(camera.fieldOfView) * .pi / 360
    let hHalf = atan(tan(vHalf) * aspect)
    let distance = radius / sin(min(vHalf, hHalf)) * 1.04
    let f = cam.simdWorldFront   // camera looks along its -Z; worldFront is that direction
    let pos = centre - simd_normalize(f) * distance
    cam.simdPosition = pos
    cam.simdLook(at: centre)
    camera.zFar = Double(max(200, distance + radius * 2))
  }

  /// Container node: name = placement.id, transform = placement.transform, base at y = 0.
  static func placementNode(for placement: Placement, products: [Product], designs: [Design]) -> SCNNode {
    let container = SCNNode()
    container.name = placement.id
    if placement.transform.count == 16 { container.transform = placement.transform.scnMatrix }

    if let pid = placement.productId, let product = products.first(where: { $0.id == pid }) {
      container.addChildNode(ModelCache.fallbackBox(for: product))
      let placeholder = container.childNodes.first
      Task {
        let loaded = await ModelCache.shared.node(for: product)
        await MainActor.run {
          placeholder?.removeFromParentNode()
          container.addChildNode(loaded)
        }
      }
    } else if let did = placement.designId, let design = designs.first(where: { $0.id == did }) {
      container.addChildNode(DesignNodeBuilder.node(for: design))
    } else {
      let size = placement.scannedSize ?? Dimensions(width: 0.5, depth: 0.5, height: 0.5)
      container.addChildNode(ModelCache.boxNode(size: size, color: CGColor(red: 0.62, green: 0.62, blue: 0.64, alpha: 1)))
    }
    return container
  }

  /// Single-sided plane whose visible face points toward `centre`; invisible from outside the room.
  private static func surfaceNode(_ s: Surface, centre: (Float, Float), offset: Float, color: CGColor) -> SCNNode {
    let plane = SCNPlane(width: CGFloat(s.width), height: CGFloat(s.height))
    let m = SCNMaterial()
    m.diffuse.contents = color
    m.lightingModel = .constant
    m.isDoubleSided = false
    plane.materials = [m]
    let child = SCNNode(geometry: plane)
    let holder = SCNNode()
    holder.addChildNode(child)
    if s.transform.count == 16 {
      holder.transform = s.transform.scnMatrix
      let t = s.transform
      // World-space wall normal (local +Z) and vector from wall to centre, in the xz plane.
      let dot = t[8] * (centre.0 - t[12]) + t[10] * (centre.1 - t[14])
      if dot < 0 { child.eulerAngles = SCNVector3(0, Float.pi, 0) }
      child.position = SCNVector3(0, 0, dot < 0 ? -offset : offset)
    }
    return holder
  }
}

/// SCNView that frames the default camera once, on first layout with a real size.
final class FramedSCNView: SCNView {
  private var framed = false
  override func layoutSubviews() {
    super.layoutSubviews()
    guard !framed, bounds.width > 1, bounds.height > 1, let scene else { return }
    framed = true
    RoomSceneBuilder.frameCamera(in: scene, viewportSize: bounds.size)
  }
}
