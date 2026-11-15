import SwiftUI

struct CatalogView: View {
  let products: [Product]
  let onPick: (Product) -> Void

  @State private var category: FurnitureCategory?

  init(products: [Product], onPick: @escaping (Product) -> Void) {
    self.products = products
    self.onPick = onPick
  }

  private var filtered: [Product] {
    guard let category else { return products }
    return products.filter { $0.category == category }
  }

  var body: some View {
    ScrollView {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          chip("All", value: nil)
          ForEach(FurnitureCategory.allCases, id: \.self) { value in
            chip(value.rawValue.capitalized, value: value)
          }
        }
        .padding(.horizontal)
      }

      LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
        ForEach(filtered) { product in
          Button {
            onPick(product)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { ProductThumbnail(product: product) }
                .clipShape(RoundedRectangle(cornerRadius: 12))
              Text(product.name).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
              Text(product.sellerName).font(.caption).foregroundStyle(.secondary)
              Text(product.priceText).font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
        }
      }
      .padding()

      if filtered.isEmpty {
        Text("No products in this category").foregroundStyle(.secondary).padding()
      }
    }
  }

  private func chip(_ title: String, value: FurnitureCategory?) -> some View {
    Button {
      category = value
    } label: {
      Text(title)
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(category == value ? Color.accentColor : Color(.systemGray6), in: Capsule())
        .foregroundStyle(category == value ? Color.white : Color.primary)
    }
    .buttonStyle(.plain)
  }
}

private struct CatalogPreview: View {
  @State private var products: [Product] = []

  var body: some View {
    CatalogView(products: products, onPick: { _ in })
      .task { products = (try? await StubBackend().products()) ?? [] }
  }
}

#Preview {
  CatalogPreview()
}
