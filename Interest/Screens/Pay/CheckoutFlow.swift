import Foundation
import Observation

@Observable final class CheckoutFlow {
  enum State: Equatable { case idle, inCheckout(orderId: String), paid(Order), cancelled }

  private(set) var state: State = .idle
  private(set) var isConfirming = false
  private(set) var confirmError: String?
  @ObservationIgnored private let backend: any Backend

  init(backend: Backend) {
    self.backend = backend
  }

  func begin(product: Product, buyer: User) async throws -> URL {
    let checkout = try await backend.createCheckout(productId: product.id, buyerId: buyer.id)
    await MainActor.run {
      confirmError = nil
      state = .inCheckout(orderId: checkout.orderId)
    }
    return checkout.checkoutUrl
  }

  func handleReturn(url: URL) async {
    guard case .inCheckout(let orderId) = state,
      url.scheme == "interest", url.host == "paid",
      URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "order" })?.value == orderId,
      !isConfirming
    else { return }
    await MainActor.run {
      isConfirming = true
      confirmError = nil
    }
    do {
      let order = try await backend.confirmOrder(id: orderId)
      await MainActor.run {
        isConfirming = false
        if state == .inCheckout(orderId: orderId) { state = .paid(order) }
      }
    } catch {
      let notFound = "\(error) \(error.localizedDescription)".contains("PAYMENT_NOT_FOUND")
      await MainActor.run {
        isConfirming = false
        confirmError = notFound
          ? "We couldn't find your payment yet. Finish paying, then tap again."
          : "Couldn't confirm the payment. Try again."
      }
    }
  }

  func dismissedWithoutReturn() {
    guard case .inCheckout = state else { return }
    state = .cancelled
  }
}
