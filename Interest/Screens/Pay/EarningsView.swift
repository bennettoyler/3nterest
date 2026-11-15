import SwiftUI

struct EarningsView: View {
  let backend: any Backend
  let products: [Product]

  @State private var sellerId = ""
  @State private var orders: [Order] = []
  @State private var failed = false

  private var sellers: [(id: String, name: String)] {
    var seen = Set<String>()
    return products.filter { seen.insert($0.sellerId).inserted }.map { (id: $0.sellerId, name: $0.sellerName) }
  }

  var body: some View {
    List {
      Section {
        Picker("Seller", selection: $sellerId) {
          ForEach(sellers, id: \.id) { seller in
            Text(seller.name).tag(seller.id)
          }
        }
      }
      Section("Orders") {
        if failed {
          Text("Couldn't load earnings.").foregroundStyle(.secondary)
        } else if orders.isEmpty {
          Text("No sales yet.").foregroundStyle(.secondary)
        }
        ForEach(orders) { order in
          VStack(alignment: .leading, spacing: 4) {
            LabeledContent(order.productName, value: payDollars(order.amountCents))
              .font(.headline)
            Text("\(order.sellerName) receives \(payDollars(order.sellerCents)) (95%)")
            Text("Interest fee \(payDollars(order.platformFeeCents)) (5%)")
          }
          .font(.subheadline)
        }
      }
      Section("Totals") {
        LabeledContent("Sales", value: payDollars(orders.reduce(0) { $0 + $1.amountCents }))
        LabeledContent("Seller receives (95%)", value: payDollars(orders.reduce(0) { $0 + $1.sellerCents }))
        LabeledContent("Interest fee (5%)", value: payDollars(orders.reduce(0) { $0 + $1.platformFeeCents }))
      }
    }
    .navigationTitle("Seller earnings")
    .task(id: sellerId) {
      guard !sellerId.isEmpty else {
        sellerId = sellers.first?.id ?? ""
        return
      }
      do {
        orders = try await backend.earnings(sellerId: sellerId)
        failed = false
      } catch {
        orders = []
        failed = true
      }
    }
  }
}
