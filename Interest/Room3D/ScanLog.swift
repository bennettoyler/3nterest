import Foundation

/// Persistent diagnostic log for object scanning: Documents/ObjectScanLog.txt (also printed).
enum ScanLog {
  private static let queue = DispatchQueue(label: "interest.scanlog")
  private static let formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  static func add(_ line: String) {
    let stamped = "\(formatter.string(from: Date())) \(line)\n"
    print("[ScanLog] \(line)")
    queue.async {
      guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            let data = stamped.data(using: .utf8) else { return }
      let url = docs.appendingPathComponent("ObjectScanLog.txt")
      if let h = try? FileHandle(forWritingTo: url) {
        defer { try? h.close() }
        _ = try? h.seekToEnd()
        try? h.write(contentsOf: data)
      } else {
        try? data.write(to: url)
      }
    }
  }
}
