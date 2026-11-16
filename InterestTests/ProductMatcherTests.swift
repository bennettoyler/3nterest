import XCTest
@testable import Interest

final class ProductMatcherTests: XCTestCase {
  func testPicksClosestSizeInCategory() {
    let small = Product.fixture(id: "a", category: .table, dimensions: .init(width: 0.6, depth: 0.6, height: 0.45))
    let big   = Product.fixture(id: "b", category: .table, dimensions: .init(width: 1.6, depth: 0.8, height: 0.75))
    let chair = Product.fixture(id: "c", category: .chair, dimensions: .init(width: 1.5, depth: 0.8, height: 0.75))
    let m = ProductMatcher.match(category: .table, size: .init(width: 1.5, depth: 0.8, height: 0.74), in: [small, big, chair])
    XCTAssertEqual(m?.id, "b")
  }

  func testNoProductInCategoryReturnsNil() {
    XCTAssertNil(ProductMatcher.match(category: .bed, size: .init(width: 2, depth: 1.6, height: 0.5), in: [.fixture(category: .chair)]))
  }

  func testIgnoresAIDesignProducts() {
    let design = Product.fixture(id: "d", category: .table, dimensions: .init(width: 1.5, depth: 0.8, height: 0.74), designId: "design1")
    let stock = Product.fixture(id: "s", category: .table, dimensions: .init(width: 0.6, depth: 0.6, height: 0.45))
    let m = ProductMatcher.match(category: .table, size: .init(width: 1.5, depth: 0.8, height: 0.74), in: [design, stock])
    XCTAssertEqual(m?.id, "s")
  }

  func testOtherCategoryOnlyMatchesNearSizes() {
    let lamp = Product.fixture(id: "l", category: .other, dimensions: .init(width: 0.4, depth: 0.4, height: 1.6))
    XCTAssertNil(ProductMatcher.match(category: .other, size: .init(width: 0.9, depth: 0.7, height: 1.8), in: [lamp]))
    XCTAssertEqual(ProductMatcher.match(category: .other, size: .init(width: 0.5, depth: 0.4, height: 1.5), in: [lamp])?.id, "l")
  }

  func testMatchAllGivesSimilarChairsTheSameProduct() {
    let products = [
      Product.fixture(id: "c1", category: .chair, dimensions: .init(width: 0.50, depth: 0.55, height: 0.85)),
      Product.fixture(id: "c2", category: .chair, dimensions: .init(width: 0.54, depth: 0.58, height: 0.83)),
      Product.fixture(id: "c3", category: .chair, dimensions: .init(width: 0.52, depth: 0.60, height: 0.88)),
      Product.fixture(id: "c4", category: .chair, dimensions: .init(width: 0.62, depth: 0.68, height: 1.10)),
    ]
    let jitter: [Float] = [-0.05, 0.05, 0.02, -0.03, 0.04, -0.01, 0.0, 0.03, -0.04, 0.05]
    var items: [(category: FurnitureCategory, size: Dimensions)] = jitter.enumerated().map { i, j in
      (.chair, Dimensions(width: i % 2 == 0 ? 0.52 + j : 0.57 - j, depth: i % 2 == 0 ? 0.57 - j : 0.52 + j, height: 0.85 + j))
    }
    items.append((.chair, Dimensions(width: 0.62, depth: 0.68, height: 1.10)))
    let out = ProductMatcher.matchAll(items, in: products)
    XCTAssertEqual(Set(out.prefix(10).map { $0?.id }).count, 1)
    XCTAssertNotNil(out[10])
  }
}
