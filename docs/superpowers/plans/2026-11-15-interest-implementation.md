# Interest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native iOS demo app where a LiDAR room scan becomes a room of movable, vendor-linked 3D products that can be bought through Whop, extended with AI-designed pieces, and shared to a Pinterest-style feed.

**Architecture:** One SwiftUI app with three folders owned by three developers: `Room3D/` (SceneKit room rendering, editing, RoomPlan scan), `Screens/` + `App/` (every non-3D screen, navigation, checkout), and `convex/` (schema, seed, functions, OpenAI and Whop actions). They meet only at `Interest/Shared/`: the model types and a `Backend` protocol, frozen in Task 0. A `StubBackend` with in-memory data lets the app run before Convex is ready and doubles as the offline demo fallback.

**Tech Stack:** Swift 5.10, SwiftUI, iOS 17+, RoomPlan, SceneKit, XcodeGen, XCTest, Convex (TypeScript functions, file storage, `convex-swift` client), OpenAI API (structured output), Whop, Capy, Revyl.

**Spec:** `docs/superpowers/specs/2026-11-15-interest-prd.md`

## Global Constraints

- All code is written after 10:00 AM on 2026-11-15. Submission is 6:00 PM. Feature freeze is 4:30 PM.
- Must use Capy, Revyl and Convex; must run on a real iPhone (LiDAR, Pro model) for the demo.
- Native Swift only. Colors: YC orange `#FF6600` and white. App name "Interest", pin logo.
- Platform cut is 5% of every sale: `platformFeeCents = round(amountCents * 0.05)`, `sellerCents = amountCents - platformFeeCents`.
- AI builder cutoff: 8 seconds, then the canned design.
- Every network-dependent demo step has a canned fallback. No real auth: a hardcoded user switcher.
- Units: metres, Y up, floor at `y = 0`. Transforms are 16 floats, column-major. Money is integer cents. Design parts are centimetres and degrees.
- Folder ownership: Dev 1 `Interest/Room3D/`, Dev 2 `Interest/App/` and `Interest/Screens/`, Dev 3 `convex/`, `seed/` and `Interest/Shared/`. Nobody edits another owner's folder. After Task 0, `Interest/Shared/` changes only with all three agreeing.
- The Xcode project is generated from `project.yml` (XcodeGen). `*.xcodeproj` is git-ignored so agents never conflict on it.
- Branches: `dev1-3d`, `dev2-app`, `dev3-backend`, one worktree each, merged to `main` at each milestone (1:00, 3:30, 4:30).
- Decisions in this plan not in the spec: SceneKit over RealityKit (free orbit camera, simple hit-testing and snapshots); XcodeGen; deep-link return from checkout.
- Tests are written only for pure logic. UI and 3D are verified by hand on device, as stated per task.

## Review Focus

Each line is pinned by a test or check in the named task.

1. A scanned object whose category has no catalog product → a plain box at the scanned size appears, the app does not crash (A4).
2. Convex unreachable on venue Wi-Fi → the app shows the bundled feed and sample room from `StubBackend` (B1).
3. OpenAI slow, failing, or returning malformed JSON → the canned design is returned within 8 seconds (C4).
4. The buyer closes checkout without paying → the order stays `pending` and no receipt is shown (B4, C5).
5. An object dragged past a wall → it stops inside the room bounds (A3).
6. A product whose 3D model fails to download → a coloured box at the product's dimensions (A2).

## File Map

```
project.yml                              XcodeGen spec (Dev 2)
Interest/Shared/Models.swift             all shared types (Dev 3)
Interest/Shared/Backend.swift            Backend protocol (Dev 3)
Interest/Shared/StubBackend.swift        in-memory backend + sample data (Dev 2 in Task 0, then frozen)
Interest/Shared/ConvexBackend.swift      Convex implementation (Dev 3)
Interest/Shared/SampleRoom.json          hand-written, later replaced by a real scan (Dev 1)
Interest/App/InterestApp.swift           entry, deep-link handling
Interest/App/RootTabView.swift           tabs: Home, Create, Builder, Profile
Interest/App/Theme.swift                 colors, pin logo
Interest/App/Session.swift               current user, backend selection
Interest/Screens/Feed/…                  FeedView, RoomCard, RoomDetailView
Interest/Screens/Product/…               ProductSheet, InstructionsView, CatalogView
Interest/Screens/Create/…                CreateFlowView, PublishSheet
Interest/Screens/Builder/…               BuilderChatView, CutListView
Interest/Screens/Pay/…                   CheckoutView, ReceiptView, EarningsView
Interest/Screens/Profile/…               ProfileView, CollectionView, UserSwitcher
Interest/Room3D/Transforms.swift         [Float] ↔ SCNMatrix4, yaw helpers
Interest/Room3D/RoomSceneBuilder.swift   Room → SCNScene
Interest/Room3D/ModelCache.swift         product → SCNNode, with box fallback
Interest/Room3D/RoomBounds.swift         clamp logic
Interest/Room3D/RoomEditorView.swift     editable room
Interest/Room3D/RoomViewerView.swift     read-only room
Interest/Room3D/ProductMatcher.swift     category + size matching
Interest/Room3D/CapturedRoomConverter.swift  RoomPlan → Room
Interest/Room3D/RoomScanView.swift       scan screen
Interest/Room3D/DesignNodeBuilder.swift  Design → SCNNode
Interest/Room3D/DesignPreviewView.swift  spinning preview
InterestTests/…                          XCTest for pure logic
convex/schema.ts, seed.ts, rooms.ts, products.ts, collections.ts,
       orders.ts, designs.ts, payments.ts, files.ts
convex/lib/split.ts, cannedDesigns.ts, designSchema.ts  (+ *.test.ts)
seed/models/*.usdz, seed/thumbs/*.jpg, seed/instructions/*.pdf
```

---

## Task 0 (all three, 10:00–10:30): Bootstrap and freeze contracts

**Files:** `project.yml`, `.gitignore`, `Interest/Shared/Models.swift`, `Interest/Shared/Backend.swift`, `Interest/Shared/StubBackend.swift`, `Interest/Shared/SampleRoom.json`, `Interest/App/InterestApp.swift`, `convex/schema.ts`

**Produces (everything later depends on these exact names):**

```swift
// Models.swift — all Codable, Identifiable where they have id, Hashable
enum FurnitureCategory: String, Codable, CaseIterable { case chair, table, sofa, bed, storage, television, other }
struct Dimensions: Codable, Hashable { var width: Float; var depth: Float; var height: Float }   // metres
struct Surface: Codable, Hashable { var transform: [Float]; var width: Float; var height: Float }
struct RoomShell: Codable, Hashable { var walls: [Surface]; var doors: [Surface]; var windows: [Surface] }
struct Placement: Codable, Identifiable, Hashable {
  var id: String; var transform: [Float]
  var productId: String?; var designId: String?
  var category: FurnitureCategory; var scannedSize: Dimensions?
}
struct Room: Codable, Identifiable, Hashable {
  var id: String; var ownerId: String; var ownerName: String; var title: String
  var thumbnailUrl: URL?; var published: Bool
  var shell: RoomShell; var placements: [Placement]; var remixedFromId: String?
}
struct Product: Codable, Identifiable, Hashable {
  var id: String; var sellerId: String; var sellerName: String; var name: String
  var category: FurnitureCategory; var priceCents: Int; var dimensions: Dimensions
  var modelUrl: URL?; var thumbnailUrl: URL?; var instructionsUrl: URL?; var vendorUrl: URL?
  var designId: String?
}
enum PartShape: String, Codable { case box, cylinder }
struct DesignPart: Codable, Hashable {
  var name: String; var shape: PartShape
  var sizeCm: [Float]; var positionCm: [Float]; var rotationDeg: [Float]   // 3 each; cylinder size = [diameter, height, diameter]
  var material: String; var colorHex: String
}
struct CutItem: Codable, Hashable { var part: String; var material: String; var lengthCm: Float; var widthCm: Float; var thicknessCm: Float; var quantity: Int }
struct Design: Codable, Identifiable, Hashable {
  var id: String; var ownerId: String; var prompt: String; var title: String
  var parts: [DesignPart]; var cutList: [CutItem]; var hardware: [String]; var steps: [String]
}
struct User: Codable, Identifiable, Hashable { var id: String; var name: String; var avatarUrl: URL? }
struct Seller: Codable, Identifiable, Hashable { var id: String; var name: String; var kind: String; var logoUrl: URL? }
enum OrderStatus: String, Codable { case pending, paid }
struct Order: Codable, Identifiable, Hashable {
  var id: String; var productId: String; var productName: String; var sellerId: String; var sellerName: String
  var amountCents: Int; var platformFeeCents: Int; var sellerCents: Int; var status: OrderStatus
}
struct Checkout: Codable { var orderId: String; var checkoutUrl: URL }
struct SavedCollection: Codable, Identifiable, Hashable { var id: String; var name: String; var roomIds: [String]; var productIds: [String] }

// Backend.swift
protocol Backend {
  func users() async throws -> [User]
  func feed() -> AsyncStream<[Room]>                       // live; newest first
  func room(id: String) async throws -> Room
  func rooms(ownerId: String) async throws -> [Room]       // published and drafts, newest first
  func saveRoom(_ room: Room) async throws -> String       // returns id; creates if id is empty
  func publish(roomId: String, title: String, thumbnailJPEG: Data) async throws
  func remix(roomId: String, as userId: String) async throws -> Room
  func products() async throws -> [Product]
  func collections(userId: String) async throws -> [SavedCollection]
  func save(roomId: String?, productId: String?, userId: String) async throws   // into the user's default "Saved" collection
  func generateDesign(prompt: String, userId: String) async throws -> Design
  func designs(ids: [String]) async throws -> [Design]
  func listForSale(designId: String, priceCents: Int) async throws -> Product
  func createCheckout(productId: String, buyerId: String) async throws -> Checkout
  func confirmOrder(id: String) async throws -> Order
  func earnings(sellerId: String) async throws -> [Order]
  func seller(forUserId: String) async throws -> Seller?
}
```

Convex function names, one per protocol method, in the same order: `users:list`, `rooms:feed`, `rooms:get`, `rooms:byOwner`, `rooms:save`, `files:generateUploadUrl` + `rooms:publish`, `rooms:remix`, `products:list`, `collections:mine`, `collections:save`, `designs:generate` (action), `designs:byIds`, `designs:listForSale`, `payments:createCheckout` (action), `orders:confirm`, `orders:bySeller`, `sellers:forUser`.

- [ ] **Step 1 (Dev 2):** Create `project.yml` with an iOS 17 app target `Interest` (bundle id of the team's developer account), a unit-test target `InterestTests`, the `convex-swift` Swift package, URL scheme `interest`, and Info.plist keys `NSCameraUsageDescription`. Add `*.xcodeproj` to `.gitignore`. Add a minimal `InterestApp.swift` showing the text "Interest".
- [ ] **Step 2 (Dev 3):** Write `Models.swift` and `Backend.swift` exactly as above. Run `npm create convex` in the repo root and write `convex/schema.ts` with tables `users`, `sellers`, `products`, `rooms`, `designs`, `collections`, `orders` whose fields mirror the Swift types (plus `sellers.whopAccountId`, `sellers.userId`, `products.checkoutUrl`).
- [ ] **Step 3 (Dev 1):** Hand-write `SampleRoom.json` as a `Room`: a 4 m × 5 m rectangle of four walls 2.5 m high, one door, one window, and four placements (sofa, table, chair, television) with `productId` values `"stub-sofa"`, `"stub-table"`, `"stub-chair"`, `"stub-tv"`.
- [ ] **Step 4 (Dev 2):** Write `StubBackend: Backend` holding in memory: 3 users, 3 sellers, 8 products (ids prefixed `stub-`, covering every category, `modelUrl` nil), 6 published rooms derived from `SampleRoom.json` with different titles, one canned desk `Design`. `createCheckout` returns `https://example.com/checkout`; `confirmOrder` returns a paid order with the 5% split. Also write `InterestTests/Fixtures.swift` with the test-only helpers every lane's tests use: `Product.fixture(...)`, `Design.fixture(parts:)`, `User.fixture()` (each with defaults for every field), `RoomShell.rectangle(width:depth:)` (four walls 2.5 m high centred on the origin), and `FailingBackend` (every method throws; `feed()` yields nothing).
- [ ] **Step 5 (all):** `xcodegen generate && xcodebuild -scheme Interest -destination 'generic/platform=iOS' build` succeeds; the app launches on the demo phone. Set up Revyl for device builds and Capy access for all three (Dev 2 leads).
- [ ] **Step 6:** Commit to `main`, push, and each developer creates their branch and worktree.

---

# Dev 1 — Room3D

## Task A1 (10:30–11:15): Render a room

**Files:** `Room3D/Transforms.swift`, `Room3D/RoomSceneBuilder.swift`, `Room3D/RoomViewerView.swift`, `InterestTests/TransformsTests.swift`

**Produces:**
```swift
extension Array where Element == Float { var scnMatrix: SCNMatrix4 { get } }     // 16 floats, column-major
func transformArray(position: SIMD3<Float>, yawRadians: Float) -> [Float]
func yaw(of transform: [Float]) -> Float
enum RoomSceneBuilder { static func scene(for room: Room, products: [Product], designs: [Design]) -> SCNScene }
struct RoomViewerView: View { init(room: Room, products: [Product], designs: [Design]) }
```
Each placement becomes a node named with the placement id. Walls are thin white boxes, the floor a light wood-coloured plane, doors and windows darker inset panels. `SCNView.allowsCameraControl = true`, default camera above and behind one corner looking at the room centre.

- [ ] **Step 1: Failing test**
```swift
func testTransformRoundTrip() {
  let t = transformArray(position: [1, 0, 2], yawRadians: .pi / 2)
  XCTAssertEqual(t.count, 16)
  XCTAssertEqual(t[12], 1, accuracy: 1e-5); XCTAssertEqual(t[14], 2, accuracy: 1e-5)
  XCTAssertEqual(yaw(of: t), .pi / 2, accuracy: 1e-4)
}
```
- [ ] **Step 2:** Run `xcodebuild test -scheme Interest -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:InterestTests/TransformsTests`; expect failure (symbols undefined).
- [ ] **Step 3:** Implement `Transforms.swift`, then `RoomSceneBuilder` (placements as grey boxes of `scannedSize` or 0.5 m cubes for now) and `RoomViewerView`.
- [ ] **Step 4:** Test passes. On device, the sample room shows with four boxes and can be orbited.
- [ ] **Step 5:** Commit `feat(room3d): render room from Room model`.

## Task A2 (11:15–11:45): Product models with box fallback

**Files:** `Room3D/ModelCache.swift`, modify `RoomSceneBuilder.swift`, `InterestTests/ModelCacheTests.swift`

**Produces:** `actor ModelCache { static let shared: ModelCache; func node(for product: Product) async -> SCNNode }` — downloads `modelUrl` to the caches directory once, loads the USDZ, scales it uniformly to fit `product.dimensions`, sets the pivot so the base sits on `y = 0`. On nil URL or any failure, returns `ModelCache.fallbackBox(for:)`. `RoomSceneBuilder` swaps placeholder boxes for these nodes as they load.

- [ ] **Step 1: Failing test (Review Focus 6)**
```swift
func testMissingModelFallsBackToBoxAtProductSize() async {
  let p = Product.fixture(dimensions: .init(width: 0.8, depth: 0.6, height: 0.9), modelUrl: URL(string: "https://invalid.invalid/x.usdz"))
  let node = await ModelCache.shared.node(for: p)
  let (lo, hi) = node.boundingBox
  XCTAssertEqual(hi.x - lo.x, 0.8, accuracy: 0.01); XCTAssertEqual(hi.y - lo.y, 0.9, accuracy: 0.01)
  XCTAssertEqual(lo.y, 0, accuracy: 0.01)
}
```
(`Product.fixture` is a test-only helper with defaults for every field.)
- [ ] **Step 2–4:** Fail, implement, pass. On device with Dev 3's seeded products (after C1), real models appear.
- [ ] **Step 5:** Commit.

## Task A3 (11:45–1:00): Editing

**Files:** `Room3D/RoomBounds.swift`, `Room3D/RoomEditorView.swift`, `InterestTests/RoomBoundsTests.swift`

**Produces:**
```swift
struct RoomBounds { init(shell: RoomShell); func clamp(_ p: SIMD3<Float>, halfExtent: SIMD2<Float>) -> SIMD3<Float> }   // axis-aligned box of all wall positions
struct RoomEditorView: View {
  init(room: Binding<Room>, products: [Product], designs: [Design],
       selection: Binding<String?>,                     // placement id
       onSnapshot: ((@escaping () -> Data?) -> Void)? = nil)   // hands the host a closure returning a JPEG of the current view
}
```
Behaviour: tap selects (orange outline, and a floating tag above the object showing `sellerName · $price`); one-finger drag on the selected object moves it on the floor plane; two-finger rotate turns it about Y; drag on empty space orbits. Every change writes back through the `room` binding. Deleting and swapping are done by the host mutating `room.placements`; the editor re-syncs nodes by placement id.

- [ ] **Step 1: Failing test (Review Focus 5)**
```swift
func testDragPastWallIsClamped() {
  let b = RoomBounds(shell: .rectangle(width: 4, depth: 5))       // test helper: walls at x=±2, z=±2.5
  let p = b.clamp([3.5, 0, 0], halfExtent: [0.5, 0.5])
  XCTAssertEqual(p.x, 1.5, accuracy: 1e-4); XCTAssertEqual(p.y, 0)
}
```
- [ ] **Step 2–4:** Fail, implement, pass. On device: select, drag, rotate, tag visible, object stops at walls.
- [ ] **Step 5:** Commit. **Merge to `main` for the 1:00 milestone.**

## Task A4 (1:00–2:30): Scan to room

**Files:** `Room3D/ProductMatcher.swift`, `Room3D/CapturedRoomConverter.swift`, `Room3D/RoomScanView.swift`, `InterestTests/ProductMatcherTests.swift`

**Produces:**
```swift
enum ProductMatcher { static func match(category: FurnitureCategory, size: Dimensions, in products: [Product]) -> Product? }
enum CapturedRoomConverter { static func room(from captured: CapturedRoom, ownerId: String, ownerName: String, products: [Product]) -> Room }
struct RoomScanView: View { init(products: [Product], owner: User, onFinish: @escaping (Room) -> Void) }
```
Matching: among products of the same category and with `designId == nil`, the one minimising `|Δwidth| + |Δdepth| + |Δheight|`; nil if the category has none. Converter: walls/doors/windows map to `Surface`; every object becomes a `Placement` with `scannedSize` set, `productId` from the matcher (nil if none), RoomPlan categories mapped to `FurnitureCategory` (anything unlisted → `.other`); all transforms shifted so the lowest wall edge is `y = 0` and the room is centred on the origin; object rotation reduced to yaw. `RoomScanView` wraps `RoomCaptureView`, has a Done button and a **"Use sample room"** button that returns the bundled `SampleRoom.json`, and shows a 2-second "Matching your furniture…" overlay before calling `onFinish`.

- [ ] **Step 1: Failing tests (includes Review Focus 1)**
```swift
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
```
And in `RoomSceneBuilder`: a placement with nil `productId` and nil `designId` renders a neutral box at `scannedSize` (new `InterestTests/RoomSceneBuilderTests.swift`: build a scene from a room with one such placement of `scannedSize` 2 × 1.6 × 0.5 and assert a node named with the placement id exists and its bounding box is that size).
- [ ] **Step 2–4:** Fail, implement, pass.
- [ ] **Step 5:** On the LiDAR phone, scan a furnished corner of the venue. Encode the resulting `Room` to JSON (debug button) and replace `Interest/Shared/SampleRoom.json` with it — target 12:30–2:30 window, as early as the scan works. Tell Dev 3 so seeded feed rooms can be derived from it.
- [ ] **Step 6:** Commit.

## Task A5 (2:30–3:30): Design rendering

**Files:** `Room3D/DesignNodeBuilder.swift`, `Room3D/DesignPreviewView.swift`, modify `RoomSceneBuilder.swift`, `InterestTests/DesignNodeBuilderTests.swift`

**Produces:** `enum DesignNodeBuilder { static func node(for design: Design) -> SCNNode }` (one child per part; cm → m; base on `y = 0`; colour from `colorHex`), `struct DesignPreviewView: View { init(design: Design) }` (slowly rotating). `RoomSceneBuilder` uses it for placements with `designId`.

- [ ] **Step 1: Failing test**
```swift
func testDeskBuildsOneChildPerPartInMetres() {
  let d = Design.fixture(parts: [
    .init(name: "top", shape: .box, sizeCm: [120, 3, 60], positionCm: [0, 73.5, 0], rotationDeg: [0,0,0], material: "walnut", colorHex: "#6B4226"),
    .init(name: "leg", shape: .cylinder, sizeCm: [5, 72, 5], positionCm: [-55, 36, -25], rotationDeg: [0,0,0], material: "steel", colorHex: "#222222")])
  let n = DesignNodeBuilder.node(for: d)
  XCTAssertEqual(n.childNodes.count, 2)
  let (lo, hi) = n.boundingBox
  XCTAssertEqual(hi.x - lo.x, 1.2, accuracy: 0.01); XCTAssertEqual(lo.y, 0, accuracy: 0.01)
}
```
- [ ] **Step 2–5:** Fail, implement, pass, commit. **Merge to `main` for the 3:30 milestone.**

---

# Dev 2 — App, screens, payments UI

## Task B1 (10:30–11:30): Shell, theme, session, feed

**Files:** `App/Theme.swift`, `App/Session.swift`, `App/RootTabView.swift`, `Screens/Feed/FeedView.swift`, `Screens/Feed/RoomCard.swift`, `InterestTests/SessionTests.swift`

**Consumes:** `Backend`, `StubBackend`. **Produces:**
```swift
@Observable final class Session {
  var backend: Backend; var currentUser: User; var products: [Product]
  init(primary: Backend, fallback: Backend)
  func start() async          // loads users + products from primary with a 4 s timeout; on failure or timeout switches `backend` to fallback
}
```
Tabs: Home (feed), Create, Builder, Profile. Feed is a two-column masonry of `RoomCard` (thumbnail, title, owner), fed by `backend.feed()`. Until C2 lands, `primary` is also a `StubBackend`.

- [ ] **Step 1: Failing test (Review Focus 2)**
```swift
func testFallsBackWhenPrimaryFails() async {
  let s = Session(primary: FailingBackend(), fallback: StubBackend())   // FailingBackend: every call throws
  await s.start()
  XCTAssertTrue(s.backend is StubBackend); XCTAssertFalse(s.products.isEmpty)
}
```
- [ ] **Step 2–4:** Fail, implement, pass. On device: orange/white themed tabs, feed shows six rooms.
- [ ] **Step 5:** Commit.

## Task B2 (11:30–1:00): Room detail, product sheet, catalog

**Files:** `Screens/Feed/RoomDetailView.swift`, `Screens/Product/ProductSheet.swift`, `Screens/Product/InstructionsView.swift`, `Screens/Product/CatalogView.swift`

**Consumes:** `RoomViewerView` (A1). **Produces:** `ProductSheet(product:onBuy:onSave:)`, `CatalogView(onPick: (Product) -> Void)` (grid filtered by category chips).

Room detail: `RoomViewerView` on top, item list below (thumbnail, name, seller, price); tapping an item opens `ProductSheet`; buttons Save and Remix. Product sheet: name, seller, price, dimensions, and buttons **Buy**, **Save**, **Assembly instructions** (PDF via `QLPreviewController`/`PDFKit` from `instructionsUrl`, or "No instructions yet"), **View at vendor** (`SFSafariViewController` on `vendorUrl`; hidden when nil).

- [ ] **Step 1:** Build the four views against `StubBackend`. Until A1 merges, use a grey placeholder where the viewer goes.
- [ ] **Step 2:** On device: open a room, open a product, open the vendor page, open instructions, Save shows a confirmation.
- [ ] **Step 3:** Commit. **Merge to `main` for the 1:00 milestone** (feed from Convex if C2 is merged, room opens in 3D, objects move).

## Task B3 (1:00–2:00): Create flow and publish

**Files:** `Screens/Create/CreateFlowView.swift`, `Screens/Create/PublishSheet.swift`

**Consumes:** `RoomScanView` (A4; until then start from `SampleRoom.json`), `RoomEditorView` (A3), `CatalogView`. 

Flow: scan → editor. Editor toolbar for the selected placement: Info (opens `ProductSheet`), Swap (catalog filtered to that category; replaces `productId`), Delete. An Add button opens the full catalog and appends a placement at the room centre using `transformArray(position: .zero, yawRadians: 0)`. Publish asks for a title, takes the snapshot via `onSnapshot`, calls `saveRoom` then `publish`, and returns to Home where the new room is first.

- [ ] **Step 1:** Implement. **Step 2:** On device: sample room → move sofa → swap chair → add step stool → publish → appears at top of feed. **Step 3:** Commit.

## Task B4 (2:00–3:00): Checkout, receipt, earnings

**Files:** `Screens/Pay/CheckoutView.swift`, `Screens/Pay/ReceiptView.swift`, `Screens/Pay/EarningsView.swift`, modify `App/InterestApp.swift`, `InterestTests/CheckoutFlowTests.swift`

**Consumes:** `createCheckout`, `confirmOrder`, `earnings`. **Produces:**
```swift
@Observable final class CheckoutFlow {
  enum State: Equatable { case idle, inCheckout(orderId: String), paid(Order), cancelled }
  private(set) var state: State
  init(backend: Backend)
  func begin(product: Product, buyer: User) async throws -> URL
  func handleReturn(url: URL) async          // accepts interest://paid?order=<id> only when it matches the open order
  func dismissedWithoutReturn()              // → .cancelled
}
```
Buy presents `SFSafariViewController` on the checkout URL. The Whop checkout redirects to `interest://paid?order=<id>`; `InterestApp.onOpenURL` forwards to `handleReturn`. Receipt shows amount paid, "`sellerName` receives $X (95%)", "Interest fee $Y (5%)". Earnings (Profile → "Seller earnings", with a seller picker) lists orders with the same split and totals. If Dev 3 reports by 2:00 that the hosted link cannot redirect, add a "Done" button in checkout that calls `handleReturn` — the demo shortcut.

- [ ] **Step 1: Failing tests (Review Focus 4)**
```swift
func testDismissWithoutPayingShowsNoReceipt() async throws {
  let f = CheckoutFlow(backend: StubBackend())
  _ = try await f.begin(product: .fixture(), buyer: .fixture())
  f.dismissedWithoutReturn()
  XCTAssertEqual(f.state, .cancelled)
}
func testReturnForDifferentOrderIsIgnored() async throws {
  let f = CheckoutFlow(backend: StubBackend())
  _ = try await f.begin(product: .fixture(), buyer: .fixture())
  await f.handleReturn(url: URL(string: "interest://paid?order=not-this-one")!)
  if case .paid = f.state { XCTFail("should not be paid") }
}
```
- [ ] **Step 2–4:** Fail, implement, pass. On device with C5: buy a seeded product in Whop test mode, see the receipt, see it in earnings.
- [ ] **Step 5:** Commit.

## Task B5 (3:00–4:15): Builder, sell, collections, profile

**Files:** `Screens/Builder/BuilderChatView.swift`, `Screens/Builder/CutListView.swift`, `Screens/Profile/ProfileView.swift`, `Screens/Profile/CollectionView.swift`, `Screens/Profile/UserSwitcher.swift`

**Consumes:** `generateDesign`, `listForSale`, `DesignPreviewView` (A5), `collections`, `save`, `remix`.

Builder: chat-style input; on send show a "Designing…" bubble, then a card with `DesignPreviewView`, title, and buttons **Cut list & steps** (`CutListView`: table of cut items, hardware, numbered steps), **Place in my room** (opens the user's most recent room in the editor with a new placement carrying `designId`), **List for sale** (price field → `listForSale` → "Listed" confirmation). Profile: user switcher, the user's rooms, the "Saved" collection (rooms and products), link to Seller earnings. Remix on room detail calls `remix` and opens the copy in the editor.

- [ ] **Step 1:** Implement, cutting in the PRD's order if behind (Remix first, then collections down to a single Saved list, then real list-for-sale).
- [ ] **Step 2:** On device: type the scripted prompt, design appears, place it, list it. **Step 3:** Commit. **Merge for the 4:30 freeze.**

## Task B6 (alongside, owner Dev 2): Capy and Revyl

- [ ] **Step 1 (by 10:30):** Ask each sponsor's staff what counts as qualifying use; record the answer at the top of this file.
- [ ] **Step 2:** Each developer gives Capy one task and merges it. Suggested: `CatalogView` (Dev 2), `convex/seed.ts` (Dev 3), `DesignNodeBuilder` (Dev 1).
- [ ] **Step 3 (after 1:00):** In Revyl, record one run of feed → room → product → checkout on the device build; re-run after the 3:30 and 4:30 merges and fix what it catches.

---

# Dev 3 — Convex, seed, OpenAI, Whop

## Task C1 (10:30–11:30): Seed data

**Files:** `convex/seed.ts`, `convex/files.ts`, `seed/models/`, `seed/thumbs/`, `seed/instructions/`, `seed/upload.mjs`

**Produces:** `seed:run` (internal mutation, idempotent: clears and reinserts) and `files:generateUploadUrl`. Data: 4 users; 5 sellers (2 brands styled as IKEA-like and Amazon-like with invented names, 3 solo makers, one maker linked to user 1); 16–20 products with at least 3 chairs, 3 tables, 2 sofas, 2 storage, 2 televisions, 1 bed, and 1 step stool (`category: other`) with an assembly PDF; every product has `vendorUrl` (a real vendor page for a similar item, or `https://example.com/p/<slug>`), `priceCents`, dimensions in metres. `seed/upload.mjs` uploads each file in `seed/` to Convex storage and patches the product's URL fields. Models: permissively licensed USDZ files, each under 5 MB; a product with no model keeps `modelUrl` unset (the app draws a box).

- [ ] **Step 1:** Write seed and upload script; run `npx convex dev` then `npx convex run seed:run` and `node seed/upload.mjs`.
- [ ] **Step 2:** In the Convex dashboard, `products` has ≥16 rows, every category above is present, at least 8 have a model URL that downloads.
- [ ] **Step 3:** Commit; post the deployment URL to the team.

## Task C2 (11:30–12:45): Core functions and ConvexBackend

**Files:** `convex/users.ts`, `rooms.ts`, `products.ts`, `collections.ts`, `sellers.ts`, `Interest/Shared/ConvexBackend.swift`

**Produces:** the non-payment, non-AI functions named in Task 0 and `final class ConvexBackend: Backend { init(deploymentUrl: String) }`. Queries return objects whose field names match the Swift types exactly, with `id` set from `_id` and seller/owner names joined in. `rooms:feed` returns published rooms newest first; `ConvexBackend.feed()` wraps the client subscription in an `AsyncStream`. `rooms:remix` copies shell and placements, sets `remixedFromId`, `published: false`. After Step 3, seed 8–12 published rooms from Dev 1's real scan (vary titles, owners, and which products are swapped in), with thumbnails.

- [ ] **Step 1:** Implement functions; check each in the dashboard function runner (`rooms:feed` returns the seeded rooms; `rooms:remix` creates an unpublished copy).
- [ ] **Step 2:** Implement `ConvexBackend`; methods for payments and designs throw `notImplemented` for now. Verify the `convex-swift` call shapes against Convex's Swift quickstart before writing.
- [ ] **Step 3:** In `Session` wiring (with Dev 2), primary = `ConvexBackend`, fallback = `StubBackend`. On device the feed shows Convex rooms; publishing from a second phone or the dashboard makes a card appear without refresh.
- [ ] **Step 4:** Commit. **Merge for the 1:00 milestone.**

## Task C3 (10:45 and ongoing): Whop discovery

- [ ] **Step 1 (before 11:00):** Ask the Whop team: can one main account create sub-accounts for sellers and take a 5% platform fee per payment; is there a test mode; can checkout redirect to `interest://paid?order=<id>`; how long does setup take. Record the answers at the top of this file.
- [ ] **Step 2:** Create the main account and one sub-account per seeded seller if supported; store ids in `sellers.whopAccountId` and keys in Convex environment variables.

## Task C4 (12:45–2:00): AI builder action

**Files:** `convex/designs.ts`, `convex/lib/designSchema.ts`, `convex/lib/cannedDesigns.ts`, `convex/lib/designSchema.test.ts`

**Produces:**
```ts
// lib/designSchema.ts
export function parseDesign(raw: unknown): DesignBody | null      // null unless every part has shape box|cylinder, three finite numbers in sizeCm/positionCm/rotationDeg, and parts.length is 1..40
// lib/cannedDesigns.ts
export function cannedFor(prompt: string): DesignBody             // "shelf"/"bookcase" → shelf, "stool"/"bench" → stool, otherwise the walnut desk
// designs.ts
export const generate = action({ args: { prompt: v.string(), userId: v.id("users") }, … })   // returns Design
```
`generate` calls the OpenAI API with a JSON-schema structured output matching `Design` minus ids, aborts at 8 000 ms, passes the result through `parseDesign`, and on abort, HTTP error, or null uses `cannedFor(prompt)`; it then stores and returns the design. The system prompt asks for furniture built only from boxes and cylinders, origin at floor centre, Y up, centimetres, realistic lumber sizes, and a cut list consistent with the parts. Model name comes from `OPENAI_MODEL`. Also `designs:byIds` and `designs:listForSale` (creates a `products` row with `designId`, `category: other`, seller = the user's seller, creating one named after the user if none).

- [ ] **Step 1: Failing tests (Review Focus 3)** — `npx vitest run convex/lib`
```ts
test("malformed model output is rejected", () => {
  expect(parseDesign({ title: "x", parts: [{ name: "top", shape: "sphere", sizeCm: [1,2,3], positionCm: [0,0,0], rotationDeg: [0,0,0] }] })).toBeNull();
  expect(parseDesign({ title: "x", parts: [{ name: "top", shape: "box", sizeCm: [1,2], positionCm: [0,0,0], rotationDeg: [0,0,0] }] })).toBeNull();
  expect(parseDesign("not json")).toBeNull();
});
test("canned design always parses and defaults to the desk", () => {
  expect(parseDesign(cannedFor("a 120 cm walnut desk with two drawers"))).not.toBeNull();
  expect(cannedFor("something unexpected").title).toMatch(/desk/i);
});
```
- [ ] **Step 2–4:** Fail, implement, pass. Run the action from the dashboard with a bad `OPENAI_API_KEY`: a design still returns in under 9 seconds.
- [ ] **Step 5:** Wire the three methods in `ConvexBackend`. Commit.

## Task C5 (2:00–3:15): Payments

**Files:** `convex/lib/split.ts`, `convex/lib/split.test.ts`, `convex/payments.ts`, `convex/orders.ts`, modify `ConvexBackend.swift`

**Produces:**
```ts
export function split(amountCents: number): { platformFeeCents: number; sellerCents: number }
export const createCheckout = action({ args: { productId, buyerId }, … })   // → { orderId, checkoutUrl }
export const confirm = mutation({ args: { id }, … })                         // pending → paid; returns Order; idempotent
export const bySeller = query({ args: { sellerId }, … })                     // paid orders only, newest first
```
`createCheckout` inserts a `pending` order with the split, then: **real path** (if C3 confirmed it) creates a Whop test-mode checkout against the seller's sub-account with `platformFeeCents` as the platform fee and the redirect URL `interest://paid?order=<orderId>`; **fallback** (decide at 2:00) returns `WHOP_FALLBACK_CHECKOUT_URL`, one hosted test-mode link on the main account.

- [ ] **Step 1: Failing tests**
```ts
test("5% cut, rounded, and the parts sum to the whole", () => {
  expect(split(4999)).toEqual({ platformFeeCents: 250, sellerCents: 4749 });
  expect(split(1000)).toEqual({ platformFeeCents: 50, sellerCents: 950 });
  expect(split(0)).toEqual({ platformFeeCents: 0, sellerCents: 0 });
});
```
- [ ] **Step 2–4:** Fail, implement, pass. From the dashboard: `createCheckout` then `bySeller` shows nothing (Review Focus 4: pending orders are not earnings); after `confirm`, it shows one order with the split.
- [ ] **Step 5:** Wire `ConvexBackend`. With Dev 2, complete one purchase on device. Commit. **Merge for the 3:30 milestone.**

---

## Task Z (all, 4:30–6:00): Freeze, rehearse, submit

- [ ] **Step 1 (4:30):** Merge all branches to `main`; build to the demo phone through Revyl; run the Revyl flow.
- [ ] **Step 2:** Run the full test suites: `xcodebuild test -scheme Interest -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` and `npx vitest run`. All pass.
- [ ] **Step 3:** Re-run `seed:run` and the upload script so the feed is clean; confirm the scripted builder prompt returns its canned design with `OPENAI_API_KEY` unset.
- [ ] **Step 4 (5:00, twice):** Rehearse the PRD's seven-step demo script on the demo phone, once on venue Wi-Fi and once in airplane mode (the `StubBackend` fallback must carry the feed, room, editor and builder).
- [ ] **Step 5:** Fix only what the rehearsals break. Submit by 6:00.
