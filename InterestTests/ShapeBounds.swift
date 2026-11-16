import SceneKit

/// Bounding box of a node's whole hierarchy in the node's own coordinates (flattenedClone is unreliable off-screen).
func shapeBounds(_ node: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
  var lo = SCNVector3(Float.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude)
  var hi = SCNVector3(-Float.greatestFiniteMagnitude, -.greatestFiniteMagnitude, -.greatestFiniteMagnitude)
  func visit(_ n: SCNNode) {
    if n.geometry != nil {
      let (a, b) = n.boundingBox
      for i in 0..<8 {
        let q = n.convertPosition(SCNVector3(i & 1 == 0 ? a.x : b.x, i & 2 == 0 ? a.y : b.y, i & 4 == 0 ? a.z : b.z), to: node)
        lo = SCNVector3(min(lo.x, q.x), min(lo.y, q.y), min(lo.z, q.z))
        hi = SCNVector3(max(hi.x, q.x), max(hi.y, q.y), max(hi.z, q.z))
      }
    }
    n.childNodes.forEach(visit)
  }
  visit(node)
  return (lo, hi)
}
