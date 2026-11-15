import SwiftUI

struct ReceiptView: View {
  let order: Order

  var body: some View {
    List {
      Section {
        VStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 48))
            .foregroundStyle(Color.accentColor)
          Text("Paid").font(.headline)
          Text(payDollars(order.amountCents)).font(.largeTitle.bold())
          Text(order.productName).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
      }
      Section {
        LabeledContent("Amount paid", value: payDollars(order.amountCents))
        Text("\(order.sellerName) receives \(payDollars(order.sellerCents)) (95%)")
        Text("3nterest fee \(payDollars(order.platformFeeCents)) (5%)")
      }
    }
  }
}

func payDollars(_ cents: Int) -> String {
  String(format: "$%d.%02d", cents / 100, cents % 100)
}
