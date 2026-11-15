import SafariServices
import SwiftUI

struct ProductSheet: View {
  let product: Product
  let onBuy: () -> Void
  let onSave: () -> Void

  @State private var saved = false
  @State private var showingInstructions = false
  @State private var showingVendor = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        ProductThumbnail(product: product, contentMode: .fit)
          .frame(maxWidth: .infinity)
          .frame(height: 220)
          .clipShape(RoundedRectangle(cornerRadius: 16))

        VStack(alignment: .leading, spacing: 4) {
          Text(product.name).font(.title2.bold())
          Text(product.sellerName).foregroundStyle(.secondary)
          Text(product.priceText).font(.title3.weight(.semibold))
          Text(product.dimensionsText).font(.subheadline).foregroundStyle(.secondary)
        }

        Button(action: onBuy) {
          Text("Buy").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Button {
          onSave()
          saved = true
        } label: {
          Label(saved ? "Saved" : "Save", systemImage: saved ? "checkmark" : "bookmark")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)

        Button {
          showingInstructions = true
        } label: {
          Label("Assembly instructions", systemImage: "doc.text").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)

        if product.vendorUrl != nil {
          Button {
            showingVendor = true
          } label: {
            Label("View at vendor", systemImage: "safari").frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .controlSize(.large)
        }
      }
      .padding()
    }
    .tint(Color.accentColor)
    .sheet(isPresented: $showingInstructions) {
      NavigationStack {
        InstructionsView(url: product.instructionsUrl)
          .navigationTitle("Assembly instructions")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") { showingInstructions = false }
            }
          }
      }
    }
    .fullScreenCover(isPresented: $showingVendor) {
      if let vendorUrl = product.vendorUrl {
        VendorSafariView(url: vendorUrl).ignoresSafeArea()
      }
    }
  }
}

struct ProductThumbnail: View {
  let product: Product
  var contentMode: ContentMode = .fill

  var body: some View {
    AsyncImage(url: product.thumbnailUrl) { phase in
      if let image = phase.image {
        image.resizable().aspectRatio(contentMode: contentMode)
      } else {
        ZStack {
          Color(.systemGray5)
          Image(systemName: "shippingbox").font(.title).foregroundStyle(.secondary)
        }
      }
    }
  }
}

extension Product {
  var priceText: String {
    (Double(priceCents) / 100).formatted(.currency(code: "USD"))
  }

  var dimensionsText: String {
    let cm = [dimensions.width, dimensions.depth, dimensions.height].map { String(Int(($0 * 100).rounded())) }
    return "W \(cm[0]) × D \(cm[1]) × H \(cm[2]) cm"
  }
}

private struct VendorSafariView: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context: Context) -> SFSafariViewController {
    SFSafariViewController(url: url)
  }

  func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

private struct ProductSheetPreview: View {
  @State private var product: Product?

  var body: some View {
    Group {
      if let product {
        ProductSheet(product: product, onBuy: {}, onSave: {})
      } else {
        ProgressView()
      }
    }
    .task { product = try? await StubBackend().products().first }
  }
}

#Preview {
  ProductSheetPreview()
}
