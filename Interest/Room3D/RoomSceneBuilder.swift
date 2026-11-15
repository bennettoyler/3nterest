import Foundation
import SceneKit

enum RoomSceneBuilder {
  static func scene(for room: Room, products: [Product], designs: [Design]) -> SCNScene {
    let scene = SCNScene()
    let root = scene.rootNode

    // Surfaces
    for w in room.shell.walls {
      root.addChildNode(surfaceNode(w, thickness: 0.1, color: CGColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1)))
    }
    for d in room.shell.doors {
      root.addChildNode(surfaceNode(d, thickness: 0.14, color: CGColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1)))
    }
    for w in room.shell.windows {
      root.addChildNode(surfaceNode(w, thickness: 0.14, color: CGColor(red: 0.45, green: 0.58, blue: 0.70, alpha: 1)))
    }

    // Floor, sized to the walls' extent
    let xs = room.shell.walls.map { $0.transform.count == 16 ? $0.transform[12] : 0 }
    let zs = room.shell.walls.map { $0.transform.count == 16 ? $0.transform[14] : 0 }
    let minX = xs.min() ?? -2, maxX = xs.max() ?? 2, minZ = zs.min() ?? -2, maxZ = zs.max() ?? 2
    let fw = max(maxX - minX, 1), fd = max(maxZ - minZ, 1)
    let cx = (minX + maxX) / 2, cz = (minZ + maxZ) / 2
    let plane = SCNPlane(width: CGFloat(fw), height: CGFloat(fd))
    let fm = SCNMaterial()
    fm.diffuse.contents = CGColor(red: 0.84, green: 0.70, blue: 0.50, alpha: 1)
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
    cam.position = SCNVector3(cx + fw / 2 + extent * 0.4, 2.5 + extent * 0.7, cz + fd / 2 + extent * 0.4)
    cam.look(at: SCNVector3(cx, 0.6, cz))
    cam.name = "defaultCamera"
    root.addChildNode(cam)
    return scene
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

  private static func surfaceNode(_ s: Surface, thickness: Float, color: CGColor) -> SCNNode {
    let box = SCNBox(width: CGFloat(s.width), height: CGFloat(s.height), length: CGFloat(thickness), chamferRadius: 0)
    let m = SCNMaterial()
    m.diffuse.contents = color
    box.materials = [m]
    let n = SCNNode(geometry: box)
    if s.transform.count == 16 { n.transform = s.transform.scnMatrix }
    return n
  }
}
