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
}
