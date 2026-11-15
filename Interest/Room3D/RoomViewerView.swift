import SwiftUI
import SceneKit

struct RoomViewerView: View {
  let room: Room
  let products: [Product]
  let designs: [Design]

  init(room: Room, products: [Product], designs: [Design]) {
    self.room = room; self.products = products; self.designs = designs
  }

  var body: some View {
    RoomSCNView(scene: RoomSceneBuilder.scene(for: room, products: products, designs: designs))
      .ignoresSafeArea()
  }
}

private struct RoomSCNView: UIViewRepresentable {
  let scene: SCNScene

  func makeUIView(context: Context) -> SCNView {
    let v = FramedSCNView()
    v.scene = scene
    v.allowsCameraControl = true
    v.autoenablesDefaultLighting = false
    v.antialiasingMode = .multisampling4X
    v.backgroundColor = .white
    v.pointOfView = scene.rootNode.childNode(withName: "defaultCamera", recursively: false)
    return v
  }

  func updateUIView(_ uiView: SCNView, context: Context) {}
}
