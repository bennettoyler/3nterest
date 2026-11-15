import SwiftUI
import SceneKit

/// A slowly rotating 3D preview of a design on a white background.
struct DesignPreviewView: View {
  let design: Design
  @State private var scene: SCNScene

  init(design: Design) {
    self.design = design
    _scene = State(initialValue: Self.makeScene(for: design))
  }

  var body: some View {
    SceneView(scene: scene, options: [.allowsCameraControl])
      .background(Color.white)
  }

  private static func makeScene(for design: Design) -> SCNScene {
    let scene = SCNScene()
    scene.background.contents = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

    let model = DesignNodeBuilder.node(for: design)
    let (lo, hi) = model.boundingBox
    let size = SIMD3<Float>(Float(hi.x - lo.x), Float(hi.y - lo.y), Float(hi.z - lo.z))
    let extent = max(max(size.x, size.y), max(size.z, 0.3))
    let centre = SCNVector3(0, Float(hi.y + lo.y) / 2, 0)

    let spinner = SCNNode()
    spinner.addChildNode(model)
    spinner.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 24)))
    scene.rootNode.addChildNode(spinner)

    let camera = SCNCamera()
    camera.fieldOfView = 40
    camera.zNear = 0.01
    camera.zFar = 100
    let cameraNode = SCNNode()
    cameraNode.camera = camera
    let d = extent * 1.9
    cameraNode.position = SCNVector3(d * 0.6, Float(centre.y) + d * 0.45, d)
    cameraNode.look(at: centre)
    scene.rootNode.addChildNode(cameraNode)

    let ambient = SCNLight()
    ambient.type = .ambient
    ambient.intensity = 700
    let ambientNode = SCNNode()
    ambientNode.light = ambient
    scene.rootNode.addChildNode(ambientNode)

    let key = SCNLight()
    key.type = .directional
    key.intensity = 800
    let keyNode = SCNNode()
    keyNode.light = key
    keyNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
    scene.rootNode.addChildNode(keyNode)
    return scene
  }
}
