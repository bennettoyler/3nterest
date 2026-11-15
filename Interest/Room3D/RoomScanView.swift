import SwiftUI
import RoomPlan

struct RoomScanView: View {
  let products: [Product]
  let owner: User
  let onFinish: (Room) -> Void

  @State private var matching = false
  @State private var scanner = ScanController()

  init(products: [Product], owner: User, onFinish: @escaping (Room) -> Void) {
    self.products = products
    self.owner = owner
    self.onFinish = onFinish
  }

  private let orange = Color(red: 1.0, green: 0.4, blue: 0.0)

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
            Button("Done") { scanner.stop() }
              .buttonStyle(.borderedProminent).tint(orange)
          }
          .padding(.bottom, 24)
        }
      } else {
        VStack(spacing: 16) {
          Text("Room scanning needs a LiDAR iPhone or iPad.")
            .multilineTextAlignment(.center)
          Button("Use sample room") { finishWithSample() }
            .buttonStyle(.borderedProminent).tint(orange)
        }
        .padding()
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
      scanner.onResult = { captured in
        if let captured {
          finish(with: CapturedRoomConverter.room(from: captured, ownerId: owner.id, ownerName: owner.name, products: products))
        } else {
          finishWithSample()
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

/// Owns the capture view's session and receives the processed result.
final class ScanController {
  weak var captureView: RoomCaptureView?
  var onResult: ((CapturedRoom?) -> Void)?
  private var delivered = false

  func stop() {
    captureView?.captureSession.stop()
    // If RoomPlan never produces a result, fall back to the sample room.
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.deliver(nil) }
  }

  func deliver(_ room: CapturedRoom?) {
    guard !delivered else { return }
    delivered = true
    onResult?(room)
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
      error == nil
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
      DispatchQueue.main.async {
        let usable = error == nil && !processedResult.walls.isEmpty
        self.controller.deliver(usable ? processedResult : nil)
      }
    }
  }
}
