import Foundation

enum ProductMatcher {
  /// Closest catalog product of the same category (ignoring AI designs), by |Δw| + |Δd| + |Δh|. Nil if none.
  static func match(category: FurnitureCategory, size: Dimensions, in products: [Product]) -> Product? {
    func distance(_ d: Dimensions) -> Float {
      abs(d.width - size.width) + abs(d.depth - size.depth) + abs(d.height - size.height)
    }
    return products
      .filter { $0.category == category && $0.designId == nil }
      .min { distance($0.dimensions) < distance($1.dimensions) }
  }
}
