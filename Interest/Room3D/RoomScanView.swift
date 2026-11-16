import SwiftUI
import RoomPlan

struct RoomScanView: View {
  let products: [Product]
  let owner: User
  let onFinish: (Room) -> Void

  @State private var matching = false
  @State private var processing = false
  @State private var failureReason: String?
  @State private var scanner = ScanController()

  init(products: [Product], owner: User, onFinish: @escaping (Room) -> Void) {
    self.products = products
    self.owner = owner
    self.onFinish = onFinish
  }

  private let orange = Color(red: 1.0, green: 0.4, blue: 0.0)

  private var exportURL: URL? { ScanExport.lastScanURL }

  @ViewBuilder private var exportButton: some View {
    if let url = exportURL {
      ShareLink(item: url) {
        Text("Export last scan").font(.footnote).foregroundStyle(.secondary)
      }
    }
  }

  var body: some View {
    ZStack {
      if RoomCaptureSession.isSupported {
        ScanCaptureView(controller: scanner)
          .ignoresSafeArea()
        VStack {
          Spacer()
          HStack(spacing: 12) {
            Button("Use sample room") { finishWithSample() }
              .buttonStyle(.bordered).tint(orange)
            Button("Done") { processing = true; failureReason = nil; scanner.stop() }
              .buttonStyle(.borderedProminent).tint(orange)
          }
          .padding(.bottom, exportURL == nil ? 24 : 8)
          exportButton.padding(.bottom, 16)
        }
      } else {
        VStack(spacing: 16) {
          Text("Room scanning needs a LiDAR iPhone or iPad.")
            .multilineTextAlignment(.center)
          Button("Use sample room") { finishWithSample() }
            .buttonStyle(.borderedProminent).tint(orange)
          exportButton
        }
        .padding()
      }
      if processing && failureReason == nil && !matching {
        ZStack {
          Color.white.ignoresSafeArea()
          VStack(spacing: 16) {
            ProgressView().tint(orange).scaleEffect(1.5)
            Text("Processing your scan…").foregroundStyle(orange).font(.headline)
          }
        }
        .transition(.opacity)
      }
      if let reason = failureReason, !matching {
        ZStack {
          Color.white.ignoresSafeArea()
          VStack(spacing: 14) {
            Text("We couldn't build a room from that scan.")
              .font(.headline).multilineTextAlignment(.center)
            Text(reason).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack(spacing: 12) {
              Button("Use sample room") { finishWithSample() }
                .buttonStyle(.bordered).tint(orange)
              Button("Scan again") {
                failureReason = nil
                processing = false
                scanner.restart()
              }
              .buttonStyle(.borderedProminent).tint(orange)
            }
            .padding(.top, 6)
          }
          .padding(24)
        }
        .transition(.opacity)
      }
      if matching {
        ZStack {
          Color.white.ignoresSafeArea()
          VStack(spacing: 16) {
            ProgressView().tint(orange).scaleEffect(1.5)
            Text("Matching your furniture…").foregroundStyle(orange).font(.headline)
          }
        }
        .transition(.opacity)
      }
    }
    .onAppear {
      scanner.onResult = { result in
        switch result {
        case .success(let captured):
          let room = CapturedRoomConverter.room(from: captured, ownerId: owner.id, ownerName: owner.name, products: products)
          _ = ScanExport.save(room)
          finish(with: room)
        case .failure(let failure):
          ScanExport.saveError(failure.reason)
          if !matching { withAnimation { failureReason = failure.reason } }
        }
      }
    }
  }

  private func finishWithSample() {
    finish(with: sampleRoom())
  }

  private func sampleRoom() -> Room {
    var room = Room(id: "", ownerId: owner.id, ownerName: owner.name, title: "My room", thumbnailUrl: nil,
                    published: false, shell: RoomShell(walls: [], doors: [], windows: []), placements: [], remixedFromId: nil)
    if let url = Bundle.main.url(forResource: "SampleRoom", withExtension: "json"),
       let data = try? Data(contentsOf: url),
       let decoded = try? JSONDecoder().decode(Room.self, from: data) {
      room = decoded
    }
    room.id = ""
    room.ownerId = owner.id
    room.ownerName = owner.name
    return room
  }

  private func finish(with room: Room) {
    guard !matching else { return }
    withAnimation { matching = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { onFinish(room) }
  }
}

/// Saves the last real scan as JSON so it can be exported from the phone.
enum ScanExport {
  static var lastScanURL: URL? {
    guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
    let url = dir.appendingPathComponent("LastScan.json")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  static func saveError(_ reason: String) {
    print("INTEREST SCAN FAILURE: \(reason)")
    guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    try? reason.write(to: dir.appendingPathComponent("LastScanError.txt"), atomically: true, encoding: .utf8)
  }

  @discardableResult
  static func save(_ room: Room) -> URL? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(room) else { return nil }
    if let text = String(data: data, encoding: .utf8) {
      print("===== INTEREST SCAN JSON BEGIN =====")
      print(text)
      print("===== INTEREST SCAN JSON END =====")
    }
    guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
    let url = dir.appendingPathComponent("LastScan.json")
    do {
      try data.write(to: url, options: .atomic)
      return url
    } catch {
      return nil
    }
  }
}

struct ScanFailure: Error { let reason: String }

/// Owns the capture view's session and receives the processed result.
final class ScanController {
  weak var captureView: RoomCaptureView?
  var onResult: ((Result<CapturedRoom, ScanFailure>) -> Void)?
  private var succeeded = false
  private var generation = 0

  func stop() {
    captureView?.captureSession.stop()
    let g = generation
    // If RoomPlan never produces a result, show the failure overlay. A late real result is still accepted.
    DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
      guard let self, self.generation == g else { return }
      self.deliver(.failure(ScanFailure(reason: "Processing took too long (no result after 60 seconds).")))
    }
  }

  func restart() {
    generation += 1
    succeeded = false
    captureView?.captureSession.run(configuration: RoomCaptureSession.Configuration())
  }

  func deliver(_ result: Result<CapturedRoom, ScanFailure>) {
    guard !succeeded else { return }
    if case .success = result { succeeded = true }
    onResult?(result)
  }
}

private struct ScanCaptureView: UIViewRepresentable {
  let controller: ScanController

  func makeCoordinator() -> Coordinator { Coordinator(controller) }

  func makeUIView(context: Context) -> RoomCaptureView {
    let view = RoomCaptureView(frame: .zero)
    view.delegate = context.coordinator
    controller.captureView = view
    view.captureSession.run(configuration: RoomCaptureSession.Configuration())
    return view
  }

  func updateUIView(_ uiView: RoomCaptureView, context: Context) {}

  static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
    uiView.captureSession.stop()
  }

  @objc(InterestScanCoordinator)
  final class Coordinator: NSObject, RoomCaptureViewDelegate {
    let controller: ScanController
    init(_ controller: ScanController) { self.controller = controller; super.init() }

    // RoomCaptureViewDelegate inherits NSCoding; the demo never encodes it.
    required init?(coder: NSCoder) { return nil }
    func encode(with coder: NSCoder) {}

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
      if let error {
        let reason = error.localizedDescription
        DispatchQueue.main.async { self.controller.deliver(.failure(ScanFailure(reason: reason))) }
        return false
      }
      return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
      DispatchQueue.main.async {
        if let error {
          self.controller.deliver(.failure(ScanFailure(reason: error.localizedDescription)))
        } else if processedResult.walls.isEmpty && processedResult.objects.isEmpty {
          self.controller.deliver(.failure(ScanFailure(reason: "The scan found no walls or objects. Try moving slowly and scanning the walls.")))
        } else {
          self.controller.deliver(.success(processedResult))
        }
      }
    }
  }
}
