import Foundation
import Observation

@Observable final class CheckoutFlow {
  enum State: Equatable { case idle, inCheckout(orderId: String), paid(Order), cancelled }

  private(set) var state: State = .idle
  @ObservationIgnored private let backend: any Backend

  init(backend: Backend) {
    self.backend = backend
  }

  func begin(product: Product, buyer: User) async throws -> URL {
    let checkout = try await backend.createCheckout(productId: product.id, buyerId: buyer.id)
    await MainActor.run { state = .inCheckout(orderId: checkout.orderId) }
    return checkout.checkoutUrl
  }

  func handleReturn(url: URL) async {
    guard case .inCheckout(let orderId) = state,
      url.scheme == "interest", url.host == "paid",
      URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "order" })?.value == orderId,
      let order = try? await backend.confirmOrder(id: orderId),
      state == .inCheckout(orderId: orderId)
    else { return }
    await MainActor.run { state = .paid(order) }
  }

  func dismissedWithoutReturn() {
    guard case .inCheckout = state else { return }
    state = .cancelled
  }
}
