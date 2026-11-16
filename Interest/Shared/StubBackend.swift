import Foundation

final class StubBackend: Backend, @unchecked Sendable {
  struct NotFound: Error {}

  private let lock = NSLock()
  private var allUsers: [User]
  private var allSellers: [Seller]
  private var sellerIdByUserId: [String: String]
  private var allProducts: [Product]
  private var allRooms: [Room]
  private var allDesigns: [Design]
  private var allOrders: [Order] = []
  private var saved: [String: SavedCollection] = [:]
  private var feedContinuations: [UUID: AsyncStream<[Room]>.Continuation] = [:]
  private var counter = 0

  init() {
    let users = [
      User(id: "stub-user-1", name: "Maya Chen", avatarUrl: nil),
      User(id: "stub-user-2", name: "Jonas Weber", avatarUrl: nil),
      User(id: "stub-user-3", name: "Priya Nair", avatarUrl: nil),
    ]
    allUsers = users
    allSellers = [
      Seller(id: "stub-seller-nordhem", name: "Nordhem", kind: "brand", logoUrl: nil),
      Seller(id: "stub-seller-parcel", name: "Parcel Home", kind: "brand", logoUrl: nil),
      Seller(id: "stub-seller-maya", name: "Maya Chen Woodworks", kind: "creator", logoUrl: nil),
    ]
    sellerIdByUserId = ["stub-user-1": "stub-seller-maya"]

    func product(_ id: String, _ seller: Seller, _ name: String, _ category: FurnitureCategory, _ priceCents: Int, _ w: Float, _ d: Float, _ h: Float) -> Product {
      Product(
        id: id, sellerId: seller.id, sellerName: seller.name, name: name, category: category, priceCents: priceCents,
        dimensions: Dimensions(width: w, depth: d, height: h),
        modelUrl: nil, thumbnailUrl: nil, instructionsUrl: nil,
        vendorUrl: URL(string: "https://example.com/p/\(id)"), designId: nil)
    }
    let nordhem = allSellers[0], parcel = allSellers[1], maya = allSellers[2]
    allProducts = [
      product("stub-sofa", nordhem, "Linnea 3-Seat Sofa", .sofa, 64900, 2.0, 0.9, 0.8),
      product("stub-table", nordhem, "Birk Coffee Table", .table, 12900, 1.1, 0.6, 0.45),
      product("stub-chair", parcel, "Harbor Lounge Chair", .chair, 18900, 0.7, 0.7, 0.85),
      product("stub-tv", parcel, "Vista 55-inch TV with Stand", .television, 49900, 1.4, 0.4, 1.1),
      product("stub-bed", nordhem, "Fjell Queen Bed", .bed, 39900, 1.6, 2.1, 0.9),
      product("stub-storage", parcel, "Stack Bookcase", .storage, 9900, 0.8, 0.3, 1.8),
      product("stub-stool", maya, "Oak Step Stool", .other, 5900, 0.4, 0.35, 0.45),
      product("stub-dining-chair", maya, "Walnut Dining Chair", .chair, 14900, 0.45, 0.5, 0.9),
      product("stub-stacking-chair", nordhem, "Vik White Stacking Chair", .chair, 4900, 0.48, 0.52, 0.85),
      product("stub-task-chair", parcel, "Aero Mesh Task Chair", .chair, 32900, 0.62, 0.66, 1.1),
      product("stub-flip-table", nordhem, "Flip-Top Rolling Table", .table, 27900, 1.6, 0.8, 0.75),
      product("stub-cane-sideboard", maya, "Rattan Cane Sideboard", .storage, 54900, 1.6, 0.45, 0.85),
      product("stub-wall-tv", parcel, "Lumen 75-inch Wall TV", .television, 109900, 1.85, 0.08, 1.0),
      product("stub-writing-desk", maya, "Oak Writing Desk", .table, 24900, 1.4, 0.7, 0.75),
      product("stub-filing-cabinet", nordhem, "Slim Filing Cabinet", .storage, 12900, 0.45, 0.6, 1.1),
      product("stub-bookshelf", maya, "Open Oak Bookshelf", .storage, 17900, 0.9, 0.32, 1.9),
      product("stub-whiteboard", nordhem, "Mobile Whiteboard", .other, 21900, 1.5, 0.5, 1.9),
      product("stub-round-meeting-table", nordhem, "Round Meeting Table", .table, 31900, 1.2, 1.2, 0.75),
      product("stub-conference-table", maya, "Walnut Conference Table", .table, 129900, 2.4, 1.1, 0.75),
      product("stub-refrigerator", parcel, "Frost Refrigerator", .other, 119900, 0.75, 0.72, 1.8),
      product("stub-stove", parcel, "Gas Range Stove", .other, 84900, 0.76, 0.66, 0.92),
      product("stub-sink", nordhem, "Kitchen Sink Cabinet", .other, 45900, 0.8, 0.6, 0.9),
      product("stub-dishwasher", parcel, "Quiet Dishwasher", .other, 64900, 0.6, 0.6, 0.85),
      product("stub-washer", parcel, "Front-Load Washer", .other, 79900, 0.6, 0.62, 0.85),
      product("stub-toilet", nordhem, "Classic Toilet", .other, 28900, 0.4, 0.7, 0.78),
      product("stub-bathtub", nordhem, "Soaking Bathtub", .other, 99900, 1.7, 0.76, 0.56),
      product("stub-twin-bed", maya, "Oak Twin Bed", .bed, 34900, 1.0, 2.0, 0.9),
      product("stub-king-bed", nordhem, "Haven King Bed", .bed, 109900, 1.95, 2.05, 1.0),
      product("stub-nightstand", maya, "Oak Nightstand", .storage, 11900, 0.5, 0.4, 0.55),
      product("stub-dresser", nordhem, "Six-Drawer Dresser", .storage, 39900, 1.4, 0.5, 0.85),
      product("stub-wardrobe", maya, "Two-Door Wardrobe", .storage, 54900, 1.0, 0.6, 2.0),
    ]

    let sample = StubBackend.sampleRoom()
    let titles = ["Sunlit Living Room", "Cozy Reading Corner", "Minimal Studio", "Scandi Lounge", "Movie Night Den", "Warm Walnut Living"]
    allRooms = titles.enumerated().map { index, title in
      var room = sample
      let owner = users[index % users.count]
      room.id = "stub-room-\(index + 1)"
      room.ownerId = owner.id
      room.ownerName = owner.name
      room.title = title
      room.published = true
      room.thumbnailUrl = nil
      room.remixedFromId = nil
      return room
    }

    allDesigns = [StubBackend.cannedDesk]
  }

  static func sampleRoom() -> Room {
    if let url = Bundle(for: StubBackend.self).url(forResource: "SampleRoom", withExtension: "json"),
       let data = try? Data(contentsOf: url),
       let room = try? JSONDecoder().decode(Room.self, from: data) {
      return room
    }
    return Room(
      id: "sample-room", ownerId: "stub-user-1", ownerName: "Maya Chen", title: "Sample Room",
      thumbnailUrl: nil, published: true,
      shell: RoomShell(walls: [], doors: [], windows: []), placements: [], remixedFromId: nil)
  }

  static let cannedDesk = Design(
    id: "stub-design-desk", ownerId: "stub-user-1",
    prompt: "a 120 cm walnut desk with two drawers", title: "Walnut Desk",
    parts: [
      DesignPart(name: "Top", shape: .box, sizeCm: [120, 3, 60], positionCm: [0, 73.5, 0], rotationDeg: [0, 0, 0], material: "walnut", colorHex: "#6B4226"),
      DesignPart(name: "Leg front left", shape: .box, sizeCm: [5, 72, 5], positionCm: [-55, 36, 25], rotationDeg: [0, 0, 0], material: "walnut", colorHex: "#5A3620"),
      DesignPart(name: "Leg front right", shape: .box, sizeCm: [5, 72, 5], positionCm: [55, 36, 25], rotationDeg: [0, 0, 0], material: "walnut", colorHex: "#5A3620"),
      DesignPart(name: "Leg back left", shape: .box, sizeCm: [5, 72, 5], positionCm: [-55, 36, -25], rotationDeg: [0, 0, 0], material: "walnut", colorHex: "#5A3620"),
      DesignPart(name: "Leg back right", shape: .box, sizeCm: [5, 72, 5], positionCm: [55, 36, -25], rotationDeg: [0, 0, 0], material: "walnut", colorHex: "#5A3620"),
      DesignPart(name: "Drawer left", shape: .box, sizeCm: [40, 12, 45], positionCm: [-30, 66, 0], rotationDeg: [0, 0, 0], material: "walnut", colorHex: "#7A4E2D"),
      DesignPart(name: "Drawer right", shape: .box, sizeCm: [40, 12, 45], positionCm: [30, 66, 0], rotationDeg: [0, 0, 0], material: "walnut", colorHex: "#7A4E2D"),
    ],
    cutList: [
      CutItem(part: "Top", material: "walnut", lengthCm: 120, widthCm: 60, thicknessCm: 3, quantity: 1),
      CutItem(part: "Leg", material: "walnut", lengthCm: 72, widthCm: 5, thicknessCm: 5, quantity: 4),
      CutItem(part: "Drawer box", material: "walnut", lengthCm: 45, widthCm: 40, thicknessCm: 12, quantity: 2),
    ],
    hardware: ["8 × 60 mm wood screws", "2 × drawer slide pairs, 40 cm", "2 × brass drawer pulls", "Wood glue"],
    steps: [
      "Cut the top, four legs and two drawer boxes to the cut list.",
      "Glue and screw the legs to the underside of the top, 2.5 cm in from each corner.",
      "Mount the drawer slides under the top and hang both drawers.",
      "Fit the pulls, sand to 220 grit and finish with hardwax oil.",
    ])

  private func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }

  private func nextId(_ prefix: String) -> String {
    counter += 1
    return "\(prefix)-\(counter)"
  }

  private func broadcastFeed() {
    let published = allRooms.filter(\.published)
    for continuation in feedContinuations.values { continuation.yield(published) }
  }

  func users() async throws -> [User] {
    withLock { allUsers }
  }

  func feed() -> AsyncStream<[Room]> {
    AsyncStream { continuation in
      let key = UUID()
      withLock {
        feedContinuations[key] = continuation
        continuation.yield(allRooms.filter(\.published))
      }
      continuation.onTermination = { [weak self] _ in
        guard let self else { return }
        self.withLock { self.feedContinuations[key] = nil }
      }
    }
  }

  func room(id: String) async throws -> Room {
    try withLock {
      guard let room = allRooms.first(where: { $0.id == id }) else { throw NotFound() }
      return room
    }
  }

  func rooms(ownerId: String) async throws -> [Room] {
    withLock { allRooms.filter { $0.ownerId == ownerId } }
  }

  func saveRoom(_ room: Room) async throws -> String {
    withLock {
      if let index = allRooms.firstIndex(where: { $0.id == room.id }), !room.id.isEmpty {
        allRooms[index] = room
        broadcastFeed()
        return room.id
      }
      var created = room
      created.id = nextId("stub-room-new")
      allRooms.insert(created, at: 0)
      broadcastFeed()
      return created.id
    }
  }

  func publish(roomId: String, title: String, thumbnailJPEG: Data) async throws {
    let thumbnailUrl = FileManager.default.temporaryDirectory.appendingPathComponent("\(roomId)-thumb.jpg")
    let wroteThumbnail = !thumbnailJPEG.isEmpty && (try? thumbnailJPEG.write(to: thumbnailUrl)) != nil
    try withLock {
      guard let index = allRooms.firstIndex(where: { $0.id == roomId }) else { throw NotFound() }
      var room = allRooms.remove(at: index)
      room.title = title
      room.published = true
      if wroteThumbnail { room.thumbnailUrl = thumbnailUrl }
      allRooms.insert(room, at: 0)
      broadcastFeed()
    }
  }

  func remix(roomId: String, as userId: String) async throws -> Room {
    try withLock {
      guard let source = allRooms.first(where: { $0.id == roomId }) else { throw NotFound() }
      var copy = source
      copy.id = nextId("stub-room-new")
      copy.ownerId = userId
      copy.ownerName = allUsers.first(where: { $0.id == userId })?.name ?? "You"
      copy.title = "Remix of \(source.title)"
      copy.published = false
      copy.thumbnailUrl = nil
      copy.remixedFromId = source.id
      allRooms.insert(copy, at: 0)
      return copy
    }
  }

  func products() async throws -> [Product] {
    withLock { allProducts }
  }

  func collections(userId: String) async throws -> [SavedCollection] {
    withLock { [saved[userId] ?? SavedCollection(id: "stub-saved-\(userId)", name: "Saved", roomIds: [], productIds: [])] }
  }

  func save(roomId: String?, productId: String?, userId: String) async throws {
    withLock {
      var collection = saved[userId] ?? SavedCollection(id: "stub-saved-\(userId)", name: "Saved", roomIds: [], productIds: [])
      if let roomId, !collection.roomIds.contains(roomId) { collection.roomIds.append(roomId) }
      if let productId, !collection.productIds.contains(productId) { collection.productIds.append(productId) }
      saved[userId] = collection
    }
  }

  func generateDesign(prompt: String, userId: String) async throws -> Design {
    withLock {
      var design = StubBackend.cannedDesk
      design.id = nextId("stub-design")
      design.ownerId = userId
      design.prompt = prompt
      allDesigns.append(design)
      return design
    }
  }

  func designs(ids: [String]) async throws -> [Design] {
    withLock { allDesigns.filter { ids.contains($0.id) } }
  }

  func listForSale(designId: String, priceCents: Int) async throws -> Product {
    try withLock {
      guard let design = allDesigns.first(where: { $0.id == designId }) else { throw NotFound() }
      let seller: Seller
      if let sellerId = sellerIdByUserId[design.ownerId], let existing = allSellers.first(where: { $0.id == sellerId }) {
        seller = existing
      } else {
        let name = allUsers.first(where: { $0.id == design.ownerId })?.name ?? "Maker"
        seller = Seller(id: nextId("stub-seller"), name: name, kind: "creator", logoUrl: nil)
        allSellers.append(seller)
        sellerIdByUserId[design.ownerId] = seller.id
      }
      let size = StubBackend.boundingSize(of: design)
      let product = Product(
        id: nextId("stub-product"), sellerId: seller.id, sellerName: seller.name, name: design.title,
        category: .other, priceCents: priceCents, dimensions: size,
        modelUrl: nil, thumbnailUrl: nil, instructionsUrl: nil, vendorUrl: nil, designId: design.id)
      allProducts.insert(product, at: 0)
      return product
    }
  }

  private static func boundingSize(of design: Design) -> Dimensions {
    var lo: [Float] = [.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude]
    var hi: [Float] = [-.greatestFiniteMagnitude, -.greatestFiniteMagnitude, -.greatestFiniteMagnitude]
    for part in design.parts where part.sizeCm.count == 3 && part.positionCm.count == 3 {
      for axis in 0..<3 {
        lo[axis] = min(lo[axis], part.positionCm[axis] - part.sizeCm[axis] / 2)
        hi[axis] = max(hi[axis], part.positionCm[axis] + part.sizeCm[axis] / 2)
      }
    }
    guard lo[0] <= hi[0] else { return Dimensions(width: 1, depth: 1, height: 1) }
    return Dimensions(width: (hi[0] - lo[0]) / 100, depth: (hi[2] - lo[2]) / 100, height: (hi[1] - lo[1]) / 100)
  }

  func createCheckout(productId: String, buyerId: String) async throws -> Checkout {
    withLock {
      let product = allProducts.first(where: { $0.id == productId })
      let amountCents = product?.priceCents ?? 0
      let platformFeeCents = Int((Double(amountCents) * 0.05).rounded())
      let order = Order(
        id: nextId("stub-order"), productId: productId, productName: product?.name ?? "Product",
        sellerId: product?.sellerId ?? "", sellerName: product?.sellerName ?? "Seller",
        amountCents: amountCents, platformFeeCents: platformFeeCents, sellerCents: amountCents - platformFeeCents,
        status: .pending)
      allOrders.insert(order, at: 0)
      return Checkout(orderId: order.id, checkoutUrl: URL(string: "https://example.com/checkout")!)
    }
  }

  func confirmOrder(id: String) async throws -> Order {
    try withLock {
      guard let index = allOrders.firstIndex(where: { $0.id == id }) else { throw NotFound() }
      allOrders[index].status = .paid
      return allOrders[index]
    }
  }

  func earnings(sellerId: String) async throws -> [Order] {
    withLock { allOrders.filter { $0.sellerId == sellerId && $0.status == .paid } }
  }

  func seller(forUserId: String) async throws -> Seller? {
    withLock {
      guard let sellerId = sellerIdByUserId[forUserId] else { return nil }
      return allSellers.first(where: { $0.id == sellerId })
    }
  }
}
