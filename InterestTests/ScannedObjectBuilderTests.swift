import XCTest
import SceneKit
import UIKit
@testable import Interest

final class ScannedObjectBuilderTests: XCTestCase {
  private func redImage() -> UIImage {
    let fmt = UIGraphicsImageRendererFormat.default()
    fmt.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200), format: fmt).image { ctx in
      UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
    }
  }

  func testFlatPanelDimensionsAndFile() throws {
    let obj = try ScannedObjectBuilder.flatPanel(image: redImage(), widthMeters: 0.8, name: "Sign")
    XCTAssertEqual(obj.dimensions.width, 0.8, accuracy: 0.01)
    XCTAssertEqual(obj.dimensions.depth, 0.02, accuracy: 0.01)
    XCTAssertEqual(obj.dimensions.height, 0.4, accuracy: 0.01)
    XCTAssertEqual(obj.modelUSDZ.pathExtension, "usdz")
    let size = (try FileManager.default.attributesOfItem(atPath: obj.modelUSDZ.path)[.size] as? NSNumber)?.intValue ?? 0
    XCTAssertGreaterThan(size, 1000)
    XCTAssertTrue(obj.wallMounted)
    XCTAssertNotNil(obj.thumbnailJPEG)

    let scene = try SCNScene(url: obj.modelUSDZ, options: nil)
    let b = shapeBounds(scene.rootNode)
    XCTAssertEqual(b.max.x - b.min.x, 0.8, accuracy: 0.01)
    XCTAssertEqual(b.max.z - b.min.z, 0.02, accuracy: 0.01)
    XCTAssertEqual(b.max.y - b.min.y, 0.4, accuracy: 0.01)
  }

  func testObjectFromUSDZMatchesDimensions() throws {
    let panel = try ScannedObjectBuilder.flatPanel(image: redImage(), widthMeters: 0.8, name: "Sign")
    let obj = try ScannedObjectBuilder.object(fromUSDZ: panel.modelUSDZ, name: "Thing")
    XCTAssertEqual(obj.name, "Thing")
    XCTAssertEqual(obj.dimensions.width, 0.8, accuracy: 0.01)
    XCTAssertEqual(obj.dimensions.depth, 0.02, accuracy: 0.01)
    XCTAssertEqual(obj.dimensions.height, 0.4, accuracy: 0.01)
    XCTAssertFalse(obj.wallMounted)
  }
}
