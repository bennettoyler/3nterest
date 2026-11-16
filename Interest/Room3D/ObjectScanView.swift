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
      ScanLog.add("capture start: \(dir.lastPathComponent)")
      captureSession = session
      stage = .capture
    } catch {
      fail("Could not start the camera: \(describe(error))", retry: { start3DCapture() })
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

  private var outputURL: URL? {
    imagesDir?.deletingLastPathComponent().appendingPathComponent("model.usdz")
  }

  private func usableModel(_ url: URL) -> Bool {
    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? nil
    return (size ?? 0) > 100_000
  }

  private func describe(_ error: Error) -> String {
    String("\(error.localizedDescription) (\(String(describing: error)))".prefix(200))
  }

  /// Loads the finished model and moves to the naming step.
  private func finishModel(_ output: URL) async {
    do {
      let obj = try ScannedObjectBuilder.object(fromUSDZ: output, name: "Scanned object")
      let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? nil
      ScanLog.add("success: \(size ?? 0) bytes, \(String(format: "%.3f x %.3f x %.3f m (w x d x h)", obj.dimensions.width, obj.dimensions.depth, obj.dimensions.height))")
      await MainActor.run { scanned = obj; name = obj.name; stage = .naming }
    } catch {
      ScanLog.add("load error: \(String(describing: error)) / \(error.localizedDescription)")
      await MainActor.run { fail("Could not build the 3D model: \(describe(error))", retry: { startReconstruction() }) }
    }
  }

  private func startReconstruction() {
    #if !targetEnvironment(simulator)
    guard #available(iOS 17.0, *), let images = imagesDir, let output = outputURL else { return }
    progress = 0
    errorText = nil
    stage = .building
    let fileCount = (try? FileManager.default.contentsOfDirectory(atPath: images.path).count) ?? 0
    ScanLog.add("reconstruction start: \(fileCount) files in \(images.deletingLastPathComponent().lastPathComponent)/Images")
    watchdogTask?.cancel(); watchdogTask = nil
    buildTask?.cancel()
    buildTask = Task {
      // Apple requires the capture session to be released before a PhotogrammetrySession exists.
      await MainActor.run { captureSession = nil }
      try? await Task.sleep(nanoseconds: 700_000_000)
      if Task.isCancelled { return }
      try? FileManager.default.removeItem(at: output)
      var failure: Error?
      var cancelled = false
      do {
        let ps = try await makePhotogrammetrySession(images: images, output: output)
        var lastStep = -1
        outputLoop: for try await o in ps.outputs {
          switch o {
          case .requestProgress(_, let fraction):
            let step = Int(fraction * 10)
            if step != lastStep { lastStep = step; ScanLog.add("output: requestProgress \(Int(fraction * 100))%") }
            await MainActor.run { updateProgress(fraction) }
          case .requestComplete:
            ScanLog.add("output: requestComplete")
            break outputLoop
          case .processingComplete:
            ScanLog.add("output: processingComplete")
            break outputLoop
          case .processingCancelled:
            ScanLog.add("output: processingCancelled")
            cancelled = true
            break outputLoop
          case .requestError(_, let error):
            ScanLog.add("output: requestError \(String(describing: error))")
            throw error
          case .inputComplete:
            ScanLog.add("output: inputComplete")
          case .invalidSample(let id, let reason):
            ScanLog.add("output: invalidSample id=\(id) reason=\(reason)")
          case .skippedSample(let id):
            ScanLog.add("output: skippedSample id=\(id)")
          case .automaticDownsampling:
            ScanLog.add("output: automaticDownsampling")
          default:
            ScanLog.add("output: other \(String(describing: o).prefix(100))")
          }
        }
      } catch {
        failure = error
        ScanLog.add("reconstruction error: \(String(describing: error)) / \(error.localizedDescription)")
      }
      await MainActor.run { watchdogTask?.cancel(); watchdogTask = nil }
      if Task.isCancelled { return }
      if cancelled && failure == nil { return }
      if usableModel(output) {
        if let failure { ScanLog.add("using existing model despite error: \(String(describing: failure))") }
        await finishModel(output)
      } else {
        let text = failure.map { "Could not build the 3D model: \(describe($0))" } ?? "Could not build the 3D model: no model was produced."
        await MainActor.run { fail(text, retry: { startReconstruction() }) }
      }
    }
    #endif
  }

  #if !targetEnvironment(simulator)
  /// Creates the session and starts the request; retries once after 1.5 s if either throws.
  @available(iOS 17.0, *)
  private func makePhotogrammetrySession(images: URL, output: URL) async throws -> PhotogrammetrySession {
    func attempt() throws -> PhotogrammetrySession {
      let ps = try PhotogrammetrySession(input: images, configuration: PhotogrammetrySession.Configuration())
      try ps.process(requests: [.modelFile(url: output, detail: .reduced)])
      return ps
    }
    do { return try attempt() } catch {
      ScanLog.add("session create/process failed, retrying: \(String(describing: error)) / \(error.localizedDescription)")
      try? await Task.sleep(nanoseconds: 1_500_000_000)
      return try attempt()
    }
  }
  #endif

  /// Updates progress and arms a 180 s watchdog the first time progress reaches 99%.
  private func updateProgress(_ fraction: Double) {
    progress = fraction
    guard fraction >= 0.99, watchdogTask == nil, stage == .building else { return }
    watchdogTask = Task {
      try? await Task.sleep(nanoseconds: 180_000_000_000)
      if Task.isCancelled { return }
      await MainActor.run {
        guard stage == .building else { return }
        ScanLog.add("watchdog fired")
        buildTask?.cancel(); buildTask = nil
        watchdogTask = nil
        if let output = outputURL, usableModel(output) {
          ScanLog.add("watchdog: model exists, continuing with it")
          Task { await finishModel(output) }
        } else {
          fail("Building the 3D model took too long.", retry: { startReconstruction() })
        }
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
    ScanLog.add("fail: \(message)")
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
            VStack(alignment: .trailing, spacing: 4) {
              Text("\(session.numberOfShotsTaken) photos").font(.footnote.bold())
              Text("Move slowly all the way around. Aim for 30+ photos.").font(.caption2)
            }
            .padding(8)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
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
      ScanLog.add("capture state: \(String(describing: state))")
      switch state {
      case .finishing: ScanLog.add("photos at finish: \(session.numberOfShotsTaken)")
      case .completed:
        ScanLog.add("photos at completed: \(session.numberOfShotsTaken)")
        onFinished()
      case .failed(let error):
        ScanLog.add("capture failed: \(String(describing: error))")
        onFailed("Capture failed: \(String(("\(error.localizedDescription) (\(String(describing: error)))").prefix(200)))")
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
