import Foundation
import SceneKit

actor ModelCache {
  static let shared = ModelCache()

  private var inFlight: [String: Task<SCNNode, Never>] = [:]
  private let session: URLSession = {
    let c = URLSessionConfiguration.default
    c.timeoutIntervalForRequest = 8
    c.timeoutIntervalForResource = 20
    return URLSession(configuration: c)
  }()

  /// Downloads modelUrl once into the caches directory, loads the USDZ, scales it uniformly to fit
  /// product.dimensions, base on y = 0, centred in x/z. Any failure returns the fallback box.
  func node(for product: Product) async -> SCNNode {
    guard let url = product.modelUrl else { return Self.fallbackBox(for: product) }
    let key = product.id + "|" + url.absoluteString
    if let t = inFlight[key] { return await t.value.clone() }
    let session = self.session
    let t = Task<SCNNode, Never> {
      do {
        let local = try await Self.localFile(for: url, productId: product.id, session: session)
        return try Self.loadFitted(url: local, dimensions: product.dimensions)
      } catch {
        return Self.fallbackBox(for: product)
      }
    }
    inFlight[key] = t
    return await t.value.clone()
  }

  /// Coloured box at product.dimensions, base at y = 0, centred in x/z.
  nonisolated static func fallbackBox(for product: Product) -> SCNNode {
    boxNode(size: product.dimensions, color: CGColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1))
  }

  /// Container whose bounding box is exactly `size`, base at local y = 0.
  nonisolated static func boxNode(size: Dimensions, color: CGColor) -> SCNNode {
    let box = SCNBox(width: CGFloat(size.width), height: CGFloat(size.height), length: CGFloat(size.depth), chamferRadius: 0)
    let m = SCNMaterial()
    m.diffuse.contents = color
    box.materials = [m]
    let child = SCNNode(geometry: box)
    child.position = SCNVector3(0, size.height / 2, 0)
    let container = SCNNode()
    container.addChildNode(child)
    return container
  }

  private nonisolated static func localFile(for url: URL, productId: String, session: URLSession) async throws -> URL {
    let dir = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      .appendingPathComponent("ModelCache", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let safe = productId.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    let file = dir.appendingPathComponent("\(safe)-\(abs(url.absoluteString.hashValue)).usdz")
    if FileManager.default.fileExists(atPath: file.path) { return file }
    let (data, response) = try await session.data(from: url)
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw URLError(.badServerResponse) }
    try data.write(to: file, options: .atomic)
    return file
  }

  private nonisolated static func loadFitted(url: URL, dimensions d: Dimensions) throws -> SCNNode {
    let scene = try SCNScene(url: url, options: nil)
    let content = SCNNode()
    for child in scene.rootNode.childNodes { content.addChildNode(child) }
    let (lo, hi) = content.boundingBox
    let bw = Float(hi.x - lo.x), bh = Float(hi.y - lo.y), bd = Float(hi.z - lo.z)
    guard bw > 1e-6, bh > 1e-6, bd > 1e-6 else { throw URLError(.cannotParseResponse) }
    let s = min(d.width / bw, d.height / bh, d.depth / bd)
    // Centre x/z and put the base on y = 0 in the scaled container's space.
    let cx = Float(lo.x + hi.x) / 2, cz = Float(lo.z + hi.z) / 2, by = Float(lo.y)
    content.position = SCNVector3(-cx * s, -by * s, -cz * s)
    content.scale = SCNVector3(s, s, s)
    let container = SCNNode()
    container.addChildNode(content)
    return container
  }
}
