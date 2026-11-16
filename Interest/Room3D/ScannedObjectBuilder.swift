import SceneKit
import UIKit

/// A finished scan, ready to upload. Dimensions are metres (width X, depth Z, height Y) of the model's bounding box.
struct ScannedObject {
  var name: String
  var dimensions: Dimensions
  var modelUSDZ: URL          // local file
  var thumbnailJPEG: Data?    // ~512 px render of the model (or the photo for flat items)
  var wallMounted: Bool       // true for flat photos
}

enum ScannedObjectBuilder {
  /// Writes a thin textured panel USDZ (image on the +Z face, base at y = 0, centred in x/z) into a temp dir and returns it.
  static func flatPanel(image: UIImage, widthMeters: Float, name: String) throws -> ScannedObject {
    let width = max(widthMeters, 0.05)
    let src = image.size
    guard src.width > 0, src.height > 0 else { throw BuildError.badImage }
    let height = width * Float(src.height / src.width)
    let depth: Float = 0.02

    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("scan-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let small = downscaled(image, longSide: 1536)
    guard let png = small.pngData() else { throw BuildError.badImage }
    let textureURL = dir.appendingPathComponent("texture.png")
    try png.write(to: textureURL)

    let box = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth), chamferRadius: 0)
    func plain() -> SCNMaterial {
      let m = SCNMaterial(); m.diffuse.contents = UIColor.white; m.lightingModel = .physicallyBased
      return m
    }
    let front = SCNMaterial()
    front.diffuse.contents = textureURL
    front.lightingModel = .physicallyBased
    front.roughness.contents = 0.9
    front.metalness.contents = 0.0
    // SCNBox face order: front (+Z), right, back, left, top, bottom.
    box.materials = [front, plain(), plain(), plain(), plain(), plain()]
    let node = SCNNode(geometry: box)
    node.position = SCNVector3(0, height / 2, 0)
    let scene = SCNScene()
    scene.rootNode.addChildNode(node)

    let usdz = dir.appendingPathComponent("panel.usdz")
    guard scene.write(to: usdz, options: nil, delegate: nil, progressHandler: nil) else { throw BuildError.exportFailed }
    let attrs = try FileManager.default.attributesOfItem(atPath: usdz.path)
    guard ((attrs[.size] as? NSNumber)?.intValue ?? 0) > 0 else { throw BuildError.exportFailed }
    _ = try SCNScene(url: usdz, options: nil)   // verify it reads back

    let thumb = downscaled(image, longSide: 512).jpegData(compressionQuality: 0.8)
    return ScannedObject(name: name, dimensions: Dimensions(width: width, depth: depth, height: height),
                         modelUSDZ: usdz, thumbnailJPEG: thumb, wallMounted: true)
  }

  /// Measures a reconstructed USDZ (bounding box → Dimensions, clamped to at least 0.02 per axis) and renders a thumbnail.
  static func object(fromUSDZ url: URL, name: String) throws -> ScannedObject {
    let scene = try SCNScene(url: url, options: nil)
    guard let (lo, hi) = hierarchyBounds(scene.rootNode) else { throw BuildError.emptyModel }
    let d = Dimensions(width: max(hi.x - lo.x, 0.02), depth: max(hi.z - lo.z, 0.02), height: max(hi.y - lo.y, 0.02))
    return ScannedObject(name: name, dimensions: d, modelUSDZ: url, thumbnailJPEG: renderThumbnail(scene: scene), wallMounted: false)
  }

  enum BuildError: LocalizedError {
    case badImage, exportFailed, emptyModel
    var errorDescription: String? {
      switch self {
      case .badImage: return "That image could not be used."
      case .exportFailed: return "Could not build the 3D file."
      case .emptyModel: return "The 3D model is empty."
      }
    }
  }

  // MARK: - Helpers

  /// Bounds of all geometry in the hierarchy, in the root's coordinates. Nil if there is none.
  static func hierarchyBounds(_ root: SCNNode) -> (SIMD3<Float>, SIMD3<Float>)? {
    var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
    var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
    var found = false
    func visit(_ n: SCNNode) {
      if n.geometry != nil {
        let (a, b) = n.boundingBox
        for i in 0..<8 {
          let q = n.convertPosition(SCNVector3(i & 1 == 0 ? a.x : b.x, i & 2 == 0 ? a.y : b.y, i & 4 == 0 ? a.z : b.z), to: root)
          lo = SIMD3(min(lo.x, q.x), min(lo.y, q.y), min(lo.z, q.z))
          hi = SIMD3(max(hi.x, q.x), max(hi.y, q.y), max(hi.z, q.z))
          found = true
        }
      }
      n.childNodes.forEach(visit)
    }
    visit(root)
    return found ? (lo, hi) : nil
  }

  private static func downscaled(_ image: UIImage, longSide: CGFloat) -> UIImage {
    let s = image.size
    let scale = min(1, longSide / max(s.width, s.height))
    let size = CGSize(width: max(1, (s.width * scale).rounded()), height: max(1, (s.height * scale).rounded()))
    let fmt = UIGraphicsImageRendererFormat.default()
    fmt.scale = 1
    fmt.opaque = true
    return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
      UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }

  /// ~512 px render of a scene from a three-quarter view. Nil if rendering is unavailable.
  static func renderThumbnail(scene: SCNScene) -> Data? {
    guard let device = MTLCreateSystemDefaultDevice(), let (lo, hi) = hierarchyBounds(scene.rootNode) else { return nil }
    let center = (lo + hi) / 2
    let radius = max(simd_length(hi - lo) / 2, 0.01)
    let cameraNode = SCNNode()
    let camera = SCNCamera()
    camera.zNear = Double(radius) * 0.05
    camera.zFar = Double(radius) * 20
    cameraNode.camera = camera
    let dist = radius * 2.6
    cameraNode.position = SCNVector3(center.x + dist * 0.5, center.y + dist * 0.4, center.z + dist * 0.8)
    scene.rootNode.addChildNode(cameraNode)
    cameraNode.look(at: SCNVector3(center.x, center.y, center.z))
    let light = SCNNode()
    light.light = SCNLight()
    light.light?.type = .omni
    light.position = cameraNode.position
    scene.rootNode.addChildNode(light)
    let ambient = SCNNode()
    ambient.light = SCNLight()
    ambient.light?.type = .ambient
    ambient.light?.intensity = 600
    scene.rootNode.addChildNode(ambient)
    defer { cameraNode.removeFromParentNode(); light.removeFromParentNode(); ambient.removeFromParentNode() }

    let renderer = SCNRenderer(device: device, options: nil)
    renderer.scene = scene
    renderer.pointOfView = cameraNode
    let saved = scene.background.contents
    scene.background.contents = UIColor(white: 0.96, alpha: 1)
    defer { scene.background.contents = saved }
    let img = renderer.snapshot(atTime: 0, with: CGSize(width: 512, height: 512), antialiasingMode: .multisampling4X)
    return img.jpegData(compressionQuality: 0.8)
  }
}
