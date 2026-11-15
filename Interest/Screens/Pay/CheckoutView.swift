import SafariServices
import SwiftUI

struct CheckoutView: View {
  let flow: CheckoutFlow
  let product: Product
  let buyer: User

  @Environment(\.dismiss) private var dismiss
  @State private var checkoutURL: URL?
  @State private var showingCheckout = false
  @State private var began = false
  @State private var failed = false

  var body: some View {
    NavigationStack {
      Group {
        if failed {
          message("Couldn't start checkout", detail: "Check your connection and try again.")
        } else if !began {
          ProgressView("Opening checkout…")
        } else if case .paid(let order) = flow.state {
          ReceiptView(order: order)
        } else if flow.state == .cancelled {
          message("Checkout cancelled", detail: "No payment was taken.")
        } else {
          ProgressView()
        }
      }
      .navigationTitle(product.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
      }
    }
    .task {
      if !began { await begin() }
    }
    .onChange(of: flow.state) { _, state in
      if case .paid = state { showingCheckout = false }
    }
    .fullScreenCover(isPresented: $showingCheckout, onDismiss: { flow.dismissedWithoutReturn() }) {
      VStack(spacing: 0) {
        if let checkoutURL {
          CheckoutSafariView(url: checkoutURL) { showingCheckout = false }
            .ignoresSafeArea(edges: .top)
        }
        Button {
          guard case .inCheckout(let orderId) = flow.state, let url = URL(string: "interest://paid?order=\(orderId)") else { return }
          Task { await flow.handleReturn(url: url) }
        } label: {
          Text("Done").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
      }
    }
  }

  private func message(_ title: String, detail: String) -> some View {
    VStack(spacing: 12) {
      Text(title).font(.title3.bold())
      Text(detail).foregroundStyle(.secondary)
      Button("Try again") { Task { await begin() } }
        .buttonStyle(.borderedProminent)
    }
    .padding()
  }

  private func begin() async {
    failed = false
    began = false
    do {
      checkoutURL = try await flow.begin(product: product, buyer: buyer)
      began = true
      showingCheckout = true
    } catch {
      failed = true
    }
  }
}

private struct CheckoutSafariView: UIViewControllerRepresentable {
  let url: URL
  let onFinish: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

  func makeUIViewController(context: Context) -> SFSafariViewController {
    let controller = SFSafariViewController(url: url)
    controller.dismissButtonStyle = .cancel
    controller.delegate = context.coordinator
    return controller
  }

  func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}

  final class Coordinator: NSObject, SFSafariViewControllerDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) { onFinish() }
  }
}
