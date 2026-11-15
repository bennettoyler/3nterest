import Foundation
import Observation

@Observable final class Session {
  var backend: any Backend
  var currentUser: User
  var products: [Product] = []
  private(set) var isStarted = false

  private let primary: any Backend
  private let fallback: any Backend
  private let timeout: Duration = .seconds(4)

  init(primary: any Backend, fallback: any Backend) {
    self.primary = primary
    self.fallback = fallback
    backend = primary
    currentUser = User(id: "stub-user-1", name: "Maya Chen", avatarUrl: nil)
  }

  @MainActor func start() async {
    var loaded = await Session.load(from: primary, timeout: timeout)
    if loaded == nil {
      backend = fallback
      loaded = await Session.load(from: fallback, timeout: timeout)
    }
    if let loaded {
      products = loaded.products
      if let user = loaded.users.first { currentUser = user }
    }
    isStarted = true
  }

  private struct Loaded {
    var users: [User]
    var products: [Product]
  }

  private static func load(from backend: any Backend, timeout: Duration) async -> Loaded? {
    let (stream, continuation) = AsyncStream.makeStream(of: Loaded?.self)
    let work = Task {
      do {
        let users = try await backend.users()
        let products = try await backend.products()
        continuation.yield(Loaded(users: users, products: products))
      } catch {
        continuation.yield(nil)
      }
    }
    let timer = Task {
      try? await Task.sleep(for: timeout)
      continuation.yield(nil)
    }
    defer {
      work.cancel()
      timer.cancel()
    }
    for await result in stream { return result }
    return nil
  }
}
