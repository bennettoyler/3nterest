import SwiftUI
import SceneKit
import PhotosUI
import UIKit
#if !targetEnvironment(simulator)
import RealityKit
#endif

/// Scan a real object (3D via Object Capture on LiDAR phones) or a flat photo (sign, poster) into a USDZ,
/// name it, upload it, and hand back the resulting Product.
struct ObjectScanView: View {
  let upload: (ScannedObject) async throws -> Product
  let onFinish: (Product, ScannedObject) -> Void
  let onCancel: () -> Void

  init(upload: @escaping (ScannedObject) async throws -> Product,
       onFinish: @escaping (Product, ScannedObject) -> Void,
       onCancel: @escaping () -> Void) {
    self.upload = upload
    self.onFinish = onFinish
    self.onCancel = onCancel
  }

  private enum Stage { case choose, capture, building, flatSize, naming, saving }

  @State private var stage: Stage = .choose
  @State private var errorText: String?
  @State private var retryAction: (() -> Void)?
  @State private var progress: Double = 0
  @State private var scanned: ScannedObject?
  @State private var name = ""
  @State private var saveError: String?

  // Flat photo
  @State private var flatImage: UIImage?
  @State private var flatWidth: Double = 0.6
  @State private var pickerItem: PhotosPickerItem?
  @State private var showCamera = false

  // 3D capture (device only)
  @State private var captureSession: AnyObject?
  @State private var imagesDir: URL?
  @State private var buildTask: Task<Void, Never>?
  @State private var watchdogTask: Task<Void, Never>?

  private let orange = Color(red: 1.0, green: 0.4, blue: 0.0)

  private var supports3D: Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    if #available(iOS 17.0, *) { return ObjectCaptureSession.isSupported }
    return false
    #endif
  }

  var body: some View {
    ZStack {
      Color.white.ignoresSafeArea()
      switch stage {
      case .choose: chooseView
      case .capture: captureView
      case .building: buildingView
      case .flatSize: flatSizeView
      case .naming, .saving: namingView
      }
      if let errorText, stage != .naming, stage != .saving { errorOverlay(errorText) }
    }
    .sheet(isPresented: $showCamera) {
      CameraPicker { image in
        showCamera = false
        if let image { flatImage = image; stage = .flatSize }
      }
      .ignoresSafeArea()
    }
    .onChange(of: pickerItem) { _, item in
      guard let item else { return }
      Task {
        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
          flatImage = img; stage = .flatSize
        } else {
          errorText = "Could not load that photo."
          retryAction = nil
        }
        pickerItem = nil
      }
    }
  }

  // MARK: - Choose

  private var chooseView: some View {
    VStack(spacing: 16) {
      Text("Scan an object").font(.title2.bold())
      Text("Turn something real into a 3D piece for your room.").foregroundStyle(.secondary).multilineTextAlignment(.center)
      Button { start3DCapture() } label: {
        Label("3D object (stuffed animal, lamp…)", systemImage: "cube.transparent").frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent).tint(orange).disabled(!supports3D)
      if !supports3D {
        Text("3D object scanning needs a LiDAR iPhone").font(.footnote).foregroundStyle(.secondary)
      }
      Text("Flat photo (sign, poster, painting)").font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
      if UIImagePickerController.isSourceTypeAvailable(.camera) {
        Button { showCamera = true } label: { Label("Take a photo", systemImage: "camera").frame(maxWidth: .infinity) }
          .buttonStyle(.borderedProminent).tint(orange)
      }
      PhotosPicker(selection: $pickerItem, matching: .images) {
        Label("Choose a photo", systemImage: "photo").frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered).tint(orange)
      Button("Cancel") { onCancel() }.padding(.top, 8)
    }
    .padding(24)
  }

  // MARK: - 3D capture

  @ViewBuilder private var captureView: some View {
    #if !targetEnvironment(simulator)
    if #available(iOS 17.0, *), let session = captureSession as? ObjectCaptureSession {
      CaptureStage(session: session, orange: orange,
                   onFinished: { startReconstruction() },
                   onFailed: { reason in fail(reason, retry: { start3DCapture() }) },
                   onCancel: { cancelCapture() })
    }
    #else
    EmptyView()
    #endif
  }

  private func start3DCapture() {
    #if !targetEnvironment(simulator)
    guard #available(iOS 17.0, *) else { return }
    errorText = nil
    do {
      let dir = FileManager.default.temporaryDirectory.appendingPathComponent("capture-\(UUID().uuidString)", isDirectory: true)
      let images = dir.appendingPathComponent("Images", isDirectory: true)
      try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
      let session = ObjectCaptureSession()
      session.start(imagesDirectory: images, configuration: ObjectCaptureSession.Configuration())
      imagesDir = images
      captureSession = session
      stage = .capture
    } catch {
      fail("Could not start the camera: \(error.localizedDescription)", retry: { start3DCapture() })
    }
    #endif
  }

  private func cancelCapture() {
    #if !targetEnvironment(simulator)
    if #available(iOS 17.0, *) { (captureSession as? ObjectCaptureSession)?.cancel() }
    #endif
    captureSession = nil
    stage = .choose
  }

  private func startReconstruction() {
    #if !targetEnvironment(simulator)
    guard #available(iOS 17.0, *), let images = imagesDir else { return }
    captureSession = nil
    progress = 0
    errorText = nil
    stage = .building
    let output = images.deletingLastPathComponent().appendingPathComponent("model.usdz")
    watchdogTask?.cancel(); watchdogTask = nil
    buildTask?.cancel()
    buildTask = Task {
      do {
        try? FileManager.default.removeItem(at: output)
        let ps = try PhotogrammetrySession(input: images, configuration: PhotogrammetrySession.Configuration())
        try ps.process(requests: [.modelFile(url: output, detail: .reduced)])
        var done = false
        outputLoop: for try await o in ps.outputs {
          switch o {
          case .requestProgress(_, let fraction):
            await MainActor.run { updateProgress(fraction) }
          case .requestComplete:
            done = true
            break outputLoop
          case .processingComplete:
            break outputLoop
          case .processingCancelled:
            await MainActor.run { watchdogTask?.cancel(); watchdogTask = nil }
            return
          case .requestError(_, let error):
            throw error
          default:
            break
          }
        }
        await MainActor.run { watchdogTask?.cancel(); watchdogTask = nil }
        if Task.isCancelled { return }
        guard done || FileManager.default.fileExists(atPath: output.path) else {
          throw ScannedObjectBuilder.BuildError.emptyModel
        }
        let obj = try ScannedObjectBuilder.object(fromUSDZ: output, name: "Scanned object")
        await MainActor.run { scanned = obj; name = obj.name; stage = .naming }
      } catch {
        await MainActor.run { watchdogTask?.cancel(); watchdogTask = nil }
        if Task.isCancelled { return }
        await MainActor.run { fail("Could not build the 3D model: \(error.localizedDescription)", retry: { startReconstruction() }) }
      }
    }
    #endif
  }

  /// Updates progress and arms a 180 s watchdog the first time progress reaches 99%.
  private func updateProgress(_ fraction: Double) {
    progress = fraction
    guard fraction >= 0.99, watchdogTask == nil, stage == .building else { return }
    watchdogTask = Task {
      try? await Task.sleep(nanoseconds: 180_000_000_000)
      if Task.isCancelled { return }
      await MainActor.run {
        guard stage == .building else { return }
        buildTask?.cancel(); buildTask = nil
        watchdogTask = nil
        fail("Building the 3D model took too long.", retry: { startReconstruction() })
      }
    }
  }

  private var buildingView: some View {
    VStack(spacing: 16) {
      ProgressView()
      Text(progress >= 0.99 ? "Finishing 3D model…" : "Building 3D model… \(Int((progress * 100).rounded()))%").font(.headline)
      Text("This can take a minute. Keep the app open.").font(.footnote).foregroundStyle(.secondary)
      Button("Cancel") { buildTask?.cancel(); buildTask = nil; watchdogTask?.cancel(); watchdogTask = nil; stage = .choose }
    }
    .padding()
  }

  // MARK: - Flat photo

  private var flatSizeView: some View {
    VStack(spacing: 16) {
      if let img = flatImage {
        Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 300).clipShape(RoundedRectangle(cornerRadius: 8))
        let h = flatWidth * Double(img.size.height / max(img.size.width, 1))
        Text(String(format: "Width %.2f m  ×  height %.2f m", flatWidth, h)).font(.headline)
      }
      Slider(value: $flatWidth, in: 0.2...2.0, step: 0.05).tint(orange)
      Text("Set the real-world width. Height follows the photo.").font(.footnote).foregroundStyle(.secondary)
      HStack(spacing: 12) {
        Button("Back") { stage = .choose }.buttonStyle(.bordered).tint(orange)
        Button("Continue") { buildFlat() }.buttonStyle(.borderedProminent).tint(orange)
      }
    }
    .padding(24)
  }

  private func buildFlat() {
    guard let img = flatImage else { return }
    do {
      let obj = try ScannedObjectBuilder.flatPanel(image: img, widthMeters: Float(flatWidth), name: "Scanned sign")
      scanned = obj; name = obj.name; stage = .naming
    } catch {
      fail("Could not build the panel: \(error.localizedDescription)", retry: { buildFlat() })
    }
  }

  // MARK: - Name + save

  private var namingView: some View {
    VStack(spacing: 16) {
      if let scanned {
        ModelPreview(url: scanned.modelUSDZ).frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 12))
        Text(String(format: "%.0f × %.0f × %.0f cm", scanned.dimensions.width * 100, scanned.dimensions.depth * 100, scanned.dimensions.height * 100))
          .font(.footnote).foregroundStyle(.secondary)
      }
      TextField("Name it", text: $name).textFieldStyle(.roundedBorder).disabled(stage == .saving)
      if stage == .saving {
        HStack { ProgressView(); Text("Saving…").font(.headline) }
      } else {
        if let saveError {
          Text(saveError).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
        }
        HStack(spacing: 12) {
          Button("Cancel") { onCancel() }.buttonStyle(.bordered).tint(orange)
          Button(saveError == nil ? "Add to room" : "Retry") { save() }.buttonStyle(.borderedProminent).tint(orange)
        }
      }
    }
    .padding(24)
  }

  private func save() {
    guard var obj = scanned else { return }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { obj.name = trimmed }
    saveError = nil
    stage = .saving
    Task {
      do {
        let product = try await upload(obj)
        await ModelCache.shared.prime(localUSDZ: obj.modelUSDZ, for: product)
        await MainActor.run { onFinish(product, obj) }
      } catch {
        await MainActor.run { saveError = "Could not save: \(error.localizedDescription)"; stage = .naming }
      }
    }
  }

  // MARK: - Errors

  private func fail(_ message: String, retry: (() -> Void)?) {
    errorText = message
    retryAction = retry
  }

  private func errorOverlay(_ message: String) -> some View {
    ZStack {
      Color.white.ignoresSafeArea()
      VStack(spacing: 16) {
        Text("Scan failed").font(.headline)
        Text(message).font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
        HStack(spacing: 12) {
          Button("Cancel") { errorText = nil; onCancel() }.buttonStyle(.bordered).tint(orange)
          if let retryAction {
            Button("Try again") { errorText = nil; retryAction() }.buttonStyle(.borderedProminent).tint(orange)
          } else {
            Button("Back") { errorText = nil; stage = .choose }.buttonStyle(.borderedProminent).tint(orange)
          }
        }
      }
      .padding(24)
    }
  }
}

// MARK: - Preview

private struct ModelPreview: UIViewRepresentable {
  let url: URL
  func makeUIView(context: Context) -> SCNView {
    let v = SCNView()
    v.backgroundColor = UIColor(white: 0.95, alpha: 1)
    v.allowsCameraControl = true
    v.autoenablesDefaultLighting = true
    v.antialiasingMode = .multisampling4X
    if let scene = try? SCNScene(url: url, options: nil) {
      v.scene = scene
      if let (lo, hi) = ScannedObjectBuilder.hierarchyBounds(scene.rootNode) {
        let center = (lo + hi) / 2
        let radius = max(simd_length(hi - lo) / 2, 0.01)
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.zNear = Double(radius) * 0.05
        cam.camera?.zFar = Double(radius) * 20
        cam.position = SCNVector3(center.x + radius * 1.3, center.y + radius * 1.0, center.z + radius * 2.1)
        scene.rootNode.addChildNode(cam)
        cam.look(at: SCNVector3(center.x, center.y, center.z))
        v.pointOfView = cam
      }
    }
    return v
  }
  func updateUIView(_ uiView: SCNView, context: Context) {}
}

// MARK: - Camera

private struct CameraPicker: UIViewControllerRepresentable {
  let onPick: (UIImage?) -> Void
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let p = UIImagePickerController()
    p.sourceType = .camera
    p.delegate = context.coordinator
    return p
  }
  func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
  func makeCoordinator() -> Coordinator { Coordinator(onPick) }
  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let onPick: (UIImage?) -> Void
    init(_ onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
      onPick(info[.originalImage] as? UIImage)
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onPick(nil) }
  }
}

// MARK: - Object Capture UI (device only)

#if !targetEnvironment(simulator)
@available(iOS 17.0, *)
private struct CaptureStage: View {
  let session: ObjectCaptureSession   // @Observable on iOS 17
  let orange: Color
  let onFinished: () -> Void
  let onFailed: (String) -> Void
  let onCancel: () -> Void

  var body: some View {
    ZStack {
      ObjectCaptureView(session: session).ignoresSafeArea()
      VStack {
        HStack {
          Button("Cancel", action: onCancel).buttonStyle(.bordered).tint(.white)
          Spacer()
          if case .capturing = session.state {
            Text("\(session.numberOfShotsTaken) photos").font(.footnote.bold()).padding(8)
              .background(.black.opacity(0.5), in: Capsule()).foregroundStyle(.white)
          }
        }
        .padding()
        Spacer()
        if let tip = feedbackText {
          Text(tip).font(.footnote).padding(8).background(.black.opacity(0.55), in: Capsule()).foregroundStyle(.white)
        }
        controls.padding(.bottom, 24).padding(.top, 8)
      }
    }
    .onChange(of: session.state) { _, state in
      switch state {
      case .completed: onFinished()
      case .failed(let error): onFailed("Capture failed: \(error.localizedDescription)")
      default: break
      }
    }
  }

  @ViewBuilder private var controls: some View {
    switch session.state {
    case .ready:
      Button("Continue") { _ = session.startDetecting() }.buttonStyle(.borderedProminent).tint(orange)
    case .detecting:
      Button("Start capturing") { session.startCapturing() }.buttonStyle(.borderedProminent).tint(orange)
    case .capturing:
      Button("Finish") { session.finish() }.buttonStyle(.borderedProminent).tint(orange)
        .disabled(session.numberOfShotsTaken < 10)
    case .finishing:
      HStack { ProgressView(); Text("Finishing…").font(.headline) }.padding(10).background(.white, in: Capsule())
    default:
      EmptyView()
    }
  }

  private var feedbackText: String? {
    switch session.state {
    case .ready: return "Place the object on a flat surface with space around it."
    case .detecting: return "Point at the object and move the box to fit around it."
    case .capturing: break
    default: return nil
    }
    guard let f = session.feedback.first else { return "Slowly walk around the object." }
    switch f {
    case .objectTooClose: return "Move back a little."
    case .objectTooFar: return "Move closer."
    case .movingTooFast: return "Slow down."
    case .environmentLowLight, .environmentTooDark: return "Needs more light."
    case .outOfFieldOfView: return "Keep the object in view."
    default: return "Slowly walk around the object."
    }
  }
}
#endif
