import Foundation
import SceneKit

enum RoomSceneBuilder {
  static func scene(for room: Room, products: [Product], designs: [Design]) -> SCNScene {
    let scene = SCNScene()
    let root = scene.rootNode

    // Floor follows the walls: convex hull of all wall END points
    let ends = wallEndPoints(room)
    var hull = convexHull(ends)
    let fw: Float, fd: Float, cx: Float, cz: Float
    if hull.count >= 3 {
      let minX = ends.map(\.x).min()!, maxX = ends.map(\.x).max()!
      let minZ = ends.map(\.y).min()!, maxZ = ends.map(\.y).max()!
      fw = max(maxX - minX, 1); fd = max(maxZ - minZ, 1)
      cx = (minX + maxX) / 2; cz = (minZ + maxZ) / 2
    } else {
      // No usable walls: floor from the placements' bounding box padded by 1 m (4 x 4 m if none).
      let pts = room.placements.filter { $0.transform.count == 16 }.map { SIMD2<Float>($0.transform[12], $0.transform[14]) }
      var minX: Float = -2, maxX: Float = 2, minZ: Float = -2, maxZ: Float = 2
      if !pts.isEmpty {
        minX = pts.map(\.x).min()! - 1; maxX = pts.map(\.x).max()! + 1
        minZ = pts.map(\.y).min()! - 1; maxZ = pts.map(\.y).max()! + 1
      }
      fw = maxX - minX; fd = maxZ - minZ; cx = (minX + maxX) / 2; cz = (minZ + maxZ) / 2
      hull = [SIMD2(minX, minZ), SIMD2(maxX, minZ), SIMD2(maxX, maxZ), SIMD2(minX, maxZ)]
    }

    // Surfaces: single-sided planes facing the room centre (dollhouse view)
    let decorated = RoomDecor.applies(to: room)
    for w in room.shell.walls {
      let color = (decorated ? RoomDecor.wallColor(for: w, in: room.shell) : nil) ?? CGColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1)
      root.addChildNode(surfaceNode(w, centre: (cx, cz), offset: 0, color: color))
    }
    // Sample room keeps its decor door/blinds; every other room gets generic doors and windows.
    if decorated {
      for w in room.shell.windows {
        root.addChildNode(surfaceNode(w, centre: (cx, cz), offset: 0.015, color: CGColor(red: 0.45, green: 0.58, blue: 0.70, alpha: 1)))
      }
    } else {
      for (i, d) in room.shell.doors.enumerated() { root.addChildNode(RoomDecor.doorNode(for: d, centre: (cx, cz), index: i)) }
      for (i, w) in room.shell.windows.enumerated() { root.addChildNode(RoomDecor.windowNode(for: w, centre: (cx, cz), index: i)) }
    }
    let floor = SCNNode(geometry: floorGeometry(hull))
    floor.name = "floor"
    if decorated, let fc = RoomDecor.floorColor(for: room.shell) { floor.geometry?.firstMaterial?.diffuse.contents = fc }
    root.addChildNode(floor)
    if decorated { for n in RoomDecor.nodes(for: room.shell) { root.addChildNode(n) } }

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

  /// Both end points of every wall in x/z: centre +/- width/2 along the wall's local X axis.
  static func wallEndPoints(_ room: Room) -> [SIMD2<Float>] {
    var out: [SIMD2<Float>] = []
    for w in room.shell.walls where w.transform.count == 16 {
      let t = w.transform
      let c = SIMD2<Float>(t[12], t[14])
      let a = SIMD2<Float>(t[0], t[2]) * (w.width / 2)
      out.append(c - a); out.append(c + a)
    }
    return out
  }

  /// Andrew's monotone chain; no repeated first point.
  static func convexHull(_ pts: [SIMD2<Float>]) -> [SIMD2<Float>] {
    let p = pts.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
    guard p.count >= 3 else { return p }
    func cross(_ o: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
      (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    }
    var lower: [SIMD2<Float>] = []
    for q in p {
      while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], q) <= 1e-6 { lower.removeLast() }
      lower.append(q)
    }
    var upper: [SIMD2<Float>] = []
    for q in p.reversed() {
      while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], q) <= 1e-6 { upper.removeLast() }
      upper.append(q)
    }
    lower.removeLast(); upper.removeLast()
    return lower + upper
  }

  /// Flat triangle fan at y = 0, normals up, double-sided.
  private static func floorGeometry(_ hull: [SIMD2<Float>]) -> SCNGeometry {
    let centre = hull.reduce(SIMD2<Float>.zero, +) / Float(hull.count)
    var verts = [SCNVector3(centre.x, 0, centre.y)]
    verts += hull.map { SCNVector3($0.x, 0, $0.y) }
    var idx: [UInt32] = []
    for i in 0..<hull.count {
      idx += [0, UInt32(1 + (i + 1) % hull.count), UInt32(1 + i)]
    }
    let src = SCNGeometrySource(vertices: verts)
    let normals = SCNGeometrySource(normals: verts.map { _ in SCNVector3(0, 1, 0) })
    let geo = SCNGeometry(sources: [src, normals], elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
    let fm = SCNMaterial()
    fm.diffuse.contents = CGColor(red: 0.78, green: 0.72, blue: 0.64, alpha: 1)
    fm.isDoubleSided = true
    geo.materials = [fm]
    return geo
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

    let wallTV = placement.category == .television && placement.transform.count == 16 && placement.transform[13] > 0.3
    if wallTV {
      let product = placement.productId.flatMap { pid in products.first(where: { $0.id == pid }) }
      let size = product?.dimensions ?? placement.scannedSize ?? Dimensions(width: 1.2, depth: 0.06, height: 0.7)
      container.addChildNode(FurnitureShapes.wallTelevision(size: size))
    } else if let pid = placement.productId, let product = products.first(where: { $0.id == pid }) {
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
      if let pid = placement.productId, let shape = FurnitureShapes.node(forUnmatchedProductId: pid, size: size) {
        container.addChildNode(shape)
        return container
      }
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
