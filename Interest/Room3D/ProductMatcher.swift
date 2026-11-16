import Foundation

enum ProductMatcher {
  /// Closest catalog product of the same category (ignoring AI designs). Orientation-independent in width/depth. Nil if none.
  static func match(category: FurnitureCategory, size: Dimensions, hint: String? = nil, in products: [Product]) -> Product? {
    func distance(_ d: Dimensions) -> Float {
      min(abs(size.width - d.width) + abs(size.depth - d.depth),
          abs(size.width - d.depth) + abs(size.depth - d.width)) + abs(size.height - d.height)
    }
    // A type hint (e.g. "refrigerator") prefers products whose name contains it, skipping the .other size cut-off.
    if let hint = hint?.lowercased(), !hint.isEmpty {
      let named = products
        .filter { $0.category == category && $0.designId == nil && $0.priceCents > 0 }
        .filter { p in
          let name = p.name.lowercased()
          return name.contains(hint) && !(hint == "washer" && name.contains("dishwasher"))
        }
        .min { distance($0.dimensions) < distance($1.dimensions) }
      if let named { return named }
    }
    let best = products
      .filter { $0.category == category && $0.designId == nil && $0.priceCents > 0 }
      .min { distance($0.dimensions) < distance($1.dimensions) }
    // Unrecognised objects only match a product of nearly the same size; otherwise draw a neutral box.
    if category == .other, let best, distance(best.dimensions) > 0.5 { return nil }
    return best
  }

  /// Matches similar items of the same category to the SAME product (greedy size clustering, 0.2 m per axis).
  static func matchAll(_ items: [(category: FurnitureCategory, size: Dimensions)], in products: [Product]) -> [Product?] {
    matchAll(items.map { (category: $0.category, size: $0.size, hint: String?.none) }, in: products)
  }

  /// Same, with an optional type hint per item. Items with different hints never share a cluster.
  static func matchAll(_ items: [(category: FurnitureCategory, size: Dimensions, hint: String?)], in products: [Product]) -> [Product?] {
    struct Cluster { var category: FurnitureCategory; var hint: String?; var sum: SIMD3<Float>; var count: Int; var members: [Int] }
    var clusters: [Cluster] = []
    for (i, item) in items.enumerated() {
      let key = SIMD3<Float>(min(item.size.width, item.size.depth), max(item.size.width, item.size.depth), item.size.height)
      if let ci = clusters.firstIndex(where: { c in
        let mean = c.sum / Float(c.count)
        return c.category == item.category && c.hint == item.hint && abs(key.x - mean.x) <= 0.2 && abs(key.y - mean.y) <= 0.2 && abs(key.z - mean.z) <= 0.2
      }) {
        clusters[ci].sum += key; clusters[ci].count += 1; clusters[ci].members.append(i)
      } else {
        clusters.append(Cluster(category: item.category, hint: item.hint, sum: key, count: 1, members: [i]))
      }
    }
    var out = [Product?](repeating: nil, count: items.count)
    for c in clusters {
      let mean = c.sum / Float(c.count)
      let p = match(category: c.category, size: Dimensions(width: mean.x, depth: mean.y, height: mean.z), hint: c.hint, in: products)
      for i in c.members { out[i] = p }
    }
    return out
  }
}
