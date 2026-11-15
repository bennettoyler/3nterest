import SwiftUI
import SceneKit
import UIKit

struct RoomEditorView: View {
    @Binding var room: Room
    let products: [Product]
    let designs: [Design]
    @Binding var selection: String?
    var onSnapshot: ((@escaping () -> Data?) -> Void)?

    init(room: Binding<Room>, products: [Product], designs: [Design],
         selection: Binding<String?>,
         onSnapshot: ((@escaping () -> Data?) -> Void)? = nil) {
        self._room = room
        self.products = products
        self.designs = designs
        self._selection = selection
        self.onSnapshot = onSnapshot
    }

    var body: some View {
        EditorSceneView(room: $room, products: products, designs: designs,
                        selection: $selection, onSnapshot: onSnapshot)
            .ignoresSafeArea()
    }
}

private let brandOrange = UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0)
private let overlayName = "selectionOverlay"

private struct EditorSceneView: UIViewRepresentable {
    @Binding var room: Room
    let products: [Product]
    let designs: [Design]
    @Binding var selection: String?
    var onSnapshot: ((@escaping () -> Data?) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let c = context.coordinator
        view.scene = RoomSceneBuilder.scene(for: room, products: products, designs: designs)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .white
        view.antialiasingMode = .multisampling4X
        c.scnView = view

        let tap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = c
        let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = c
        let rot = UIRotationGestureRecognizer(target: c, action: #selector(Coordinator.handleRotate(_:)))
        rot.delegate = c
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(rot)
        c.panRecognizer = pan
        c.rotationRecognizer = rot

        c.syncNodes()
        c.refreshSelection(force: true)

        if let onSnapshot {
            let snapshot: () -> Data? = { [weak view] in
                view?.snapshot().jpegData(compressionQuality: 0.8)
            }
            DispatchQueue.main.async { onSnapshot(snapshot) }
        }
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let c = context.coordinator
        c.parent = self
        c.syncNodes()
        c.refreshSelection(force: false)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: EditorSceneView
        weak var scnView: SCNView?
        weak var panRecognizer: UIPanGestureRecognizer?
        weak var rotationRecognizer: UIRotationGestureRecognizer?

        /// placement id -> "productId|designId" signature of the node currently in the scene
        private var signatures: [String: String] = [:]
        private var shownSelectionId: String?
        private var overlay: SCNNode?
        private var grabOffset = SIMD2<Float>(0, 0)

        init(_ parent: EditorSceneView) { self.parent = parent }

        // MARK: Node sync

        private func signature(_ p: Placement) -> String { "\(p.productId ?? "")|\(p.designId ?? "")" }

        func syncNodes() {
            guard let root = scnView?.scene?.rootNode else { return }
            let placements = parent.room.placements
            let ids = Set(placements.map { $0.id })

            for id in Array(signatures.keys) where !ids.contains(id) {
                root.childNode(withName: id, recursively: true)?.removeFromParentNode()
                signatures[id] = nil
            }
            for p in placements {
                let sig = signature(p)
                let existing = root.childNode(withName: p.id, recursively: true)
                if let node = existing, signatures[p.id] == sig {
                    node.transform = p.transform.scnMatrix
                } else {
                    let fresh = RoomSceneBuilder.placementNode(for: p, products: parent.products, designs: parent.designs)
                    if let old = existing {
                        old.parent?.replaceChildNode(old, with: fresh)
                    } else {
                        root.addChildNode(fresh)
                    }
                    signatures[p.id] = sig
                }
            }
        }

        private func placementNode(_ id: String) -> SCNNode? {
            scnView?.scene?.rootNode.childNode(withName: id, recursively: true)
        }

        private func placementId(at point: CGPoint) -> String? {
            guard let view = scnView else { return nil }
            let ids = Set(parent.room.placements.map { $0.id })
            let opts: [SCNHitTestOption: Any] = [.searchMode: SCNHitTestSearchMode.all.rawValue]
            for hit in view.hitTest(point, options: opts) {
                var n: SCNNode? = hit.node
                while let cur = n {
                    if let name = cur.name, ids.contains(name) { return name }
                    n = cur.parent
                }
            }
            return nil
        }

        // MARK: Selection visuals

        func refreshSelection(force: Bool) {
            let id = parent.selection
            if !force, id == shownSelectionId, let o = overlay, let id, o.parent === placementNode(id) { return }
            overlay?.removeFromParentNode()
            overlay = nil
            shownSelectionId = nil
            guard let id, let node = placementNode(id) else { return }

            let (lo, hi) = localBounds(of: node)
            let size = SCNVector3(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
            let container = SCNNode()
            container.name = overlayName

            let box = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0)
            let outline = SCNMaterial()
            outline.fillMode = .lines
            outline.lightingModel = .constant
            outline.diffuse.contents = brandOrange
            let tint = SCNMaterial()
            tint.lightingModel = .constant
            tint.diffuse.contents = brandOrange.withAlphaComponent(0.18)
            tint.isDoubleSided = true
            tint.writesToDepthBuffer = false
            let fillBox = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0)
            box.materials = [outline]
            fillBox.materials = [tint]
            let centre = SCNVector3((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2)
            let boxNode = SCNNode(geometry: box)
            boxNode.position = centre
            let fillNode = SCNNode(geometry: fillBox)
            fillNode.position = centre
            container.addChildNode(boxNode)
            container.addChildNode(fillNode)

            if let text = tagText(for: id) {
                let tag = makeTag(text)
                tag.position = SCNVector3((lo.x + hi.x) / 2, hi.y + 0.2, (lo.z + hi.z) / 2)
                container.addChildNode(tag)
            }
            node.addChildNode(container)
            overlay = container
            shownSelectionId = id
        }

        private func tagText(for id: String) -> String? {
            guard let placement = parent.room.placements.first(where: { $0.id == id }),
                  let pid = placement.productId,
                  let product = parent.products.first(where: { $0.id == pid }) else { return nil }
            let cents = product.priceCents
            let price = cents % 100 == 0 ? "$\(cents / 100)" : String(format: "$%.2f", Double(cents) / 100)
            return "\(product.sellerName) · \(price)"
        }

        private func makeTag(_ string: String) -> SCNNode {
            let text = SCNText(string: string, extrusionDepth: 0)
            text.font = UIFont.boldSystemFont(ofSize: 10)
            text.flatness = 0.1
            let white = SCNMaterial()
            white.lightingModel = .constant
            white.diffuse.contents = UIColor.white
            white.readsFromDepthBuffer = false
            text.materials = [white]

            let textNode = SCNNode(geometry: text)
            let (tmin, tmax) = textNode.boundingBox
            textNode.pivot = SCNMatrix4MakeTranslation((tmin.x + tmax.x) / 2, (tmin.y + tmax.y) / 2, 0)
            textNode.scale = SCNVector3(0.012, 0.012, 0.012)
            textNode.position = SCNVector3(0, 0, 0.002)
            textNode.renderingOrder = 101

            let w = CGFloat(tmax.x - tmin.x) * 0.012 + 0.1
            let h = CGFloat(tmax.y - tmin.y) * 0.012 + 0.06
            let plane = SCNPlane(width: w, height: h)
            plane.cornerRadius = h / 2
            let bg = SCNMaterial()
            bg.lightingModel = .constant
            bg.diffuse.contents = brandOrange
            bg.readsFromDepthBuffer = false
            plane.materials = [bg]
            let bgNode = SCNNode(geometry: plane)
            bgNode.renderingOrder = 100

            let tag = SCNNode()
            tag.addChildNode(bgNode)
            tag.addChildNode(textNode)
            tag.constraints = [SCNBillboardConstraint()]
            return tag
        }

        /// Bounds of a placement node, ignoring the selection overlay.
        private func localBounds(of node: SCNNode) -> (SCNVector3, SCNVector3) {
            let saved = node.childNode(withName: overlayName, recursively: false)
            saved?.removeFromParentNode()
            var (lo, hi) = node.boundingBox
            if saved != nil { /* overlay is rebuilt by the caller */ }
            if hi.x - lo.x < 0.01 || hi.y - lo.y < 0.01 || hi.z - lo.z < 0.01 {
                lo = SCNVector3(-0.25, 0, -0.25); hi = SCNVector3(0.25, 0.5, 0.25)
            }
            return (lo, hi)
        }

        private func halfExtent(of node: SCNNode, yaw: Float) -> SIMD2<Float> {
            let (lo, hi) = localBounds(of: node)
            let hx = (hi.x - lo.x) / 2, hz = (hi.z - lo.z) / 2
            let c = abs(cos(yaw)), s = abs(sin(yaw))
            return SIMD2<Float>(c * hx + s * hz, s * hx + c * hz)
        }

        // MARK: Gestures

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            let id = placementId(at: g.location(in: g.view))
            if parent.selection != id { parent.selection = id }
        }

        private func floorPoint(_ p: CGPoint) -> SIMD2<Float>? {
            guard let view = scnView else { return nil }
            let a = view.unprojectPoint(SCNVector3(Float(p.x), Float(p.y), 0))
            let b = view.unprojectPoint(SCNVector3(Float(p.x), Float(p.y), 1))
            let o = SIMD3<Float>(Float(a.x), Float(a.y), Float(a.z))
            let d = SIMD3<Float>(Float(b.x), Float(b.y), Float(b.z)) - o
            guard abs(d.y) > 1e-6 else { return nil }
            let t = -o.y / d.y
            guard t >= 0 else { return nil }
            return SIMD2<Float>(o.x + d.x * t, o.z + d.z * t)
        }

        private func index(of id: String) -> Int? {
            parent.room.placements.firstIndex(where: { $0.id == id })
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            switch g.state {
            case .began:
                guard let id = parent.selection, let i = index(of: id),
                      let hit = floorPoint(g.location(in: g.view)) else { return }
                let t = parent.room.placements[i].transform
                grabOffset = SIMD2<Float>(t[12], t[14]) - hit
            case .changed:
                guard let id = parent.selection, let i = index(of: id), let node = placementNode(id),
                      let hit = floorPoint(g.location(in: g.view)) else { return }
                let current = parent.room.placements[i].transform
                let yawNow = yaw(of: current)
                let target = hit + grabOffset
                let bounds = RoomBounds(shell: parent.room.shell)
                let p = bounds.clamp(SIMD3<Float>(target.x, 0, target.y), halfExtent: halfExtent(of: node, yaw: yawNow))
                let t = transformArray(position: p, yawRadians: yawNow)
                node.transform = t.scnMatrix
                parent.room.placements[i].transform = t
                // halfExtent(of:) detaches the overlay; put it back.
                refreshSelection(force: true)
            case .ended, .cancelled, .failed:
                endCustomGesture()
            default: break
            }
        }

        @objc func handleRotate(_ g: UIRotationGestureRecognizer) {
            switch g.state {
            case .changed:
                guard let id = parent.selection, let i = index(of: id), let node = placementNode(id) else { return }
                let t0 = parent.room.placements[i].transform
                let newYaw = yaw(of: t0) - Float(g.rotation)
                g.rotation = 0
                let bounds = RoomBounds(shell: parent.room.shell)
                let pos = SIMD3<Float>(t0[12], 0, t0[14])
                let p = bounds.clamp(pos, halfExtent: halfExtent(of: node, yaw: newYaw))
                let t = transformArray(position: p, yawRadians: newYaw)
                node.transform = t.scnMatrix
                parent.room.placements[i].transform = t
                refreshSelection(force: true)
            case .ended, .cancelled, .failed:
                endCustomGesture()
            default: break
            }
        }

        private func endCustomGesture() {
            let active = [panRecognizer, rotationRecognizer].contains { r in
                guard let r else { return false }
                return r.state == .began || r.state == .changed
            }
            if !active { scnView?.allowsCameraControl = true }
        }

        // MARK: UIGestureRecognizerDelegate

        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            if g === panRecognizer {
                guard let sel = parent.selection, placementId(at: g.location(in: g.view)) == sel else { return false }
                scnView?.allowsCameraControl = false   // our drag, not camera orbit
                return true
            }
            if g === rotationRecognizer {
                guard let sel = parent.selection, index(of: sel) != nil else { return false }
                scnView?.allowsCameraControl = false
                return true
            }
            return true
        }
    }
}
