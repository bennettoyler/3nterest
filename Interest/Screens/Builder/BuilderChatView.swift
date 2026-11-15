import SwiftUI

struct BuilderChatView: View {
  let backend: any Backend
  let currentUser: User
  let onPlace: (Design) -> Void

  @State private var messages: [BuilderMessage] = []
  @State private var draft = ""
  @State private var isDesigning = false
  @State private var cutListDesign: Design?

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        if messages.isEmpty {
          ContentUnavailableView(
            "Design a piece",
            systemImage: "hammer.fill",
            description: Text("Describe the furniture you want, like \"a 120 cm walnut desk with two drawers\"."))
            .padding(.top, 60)
        }
        ForEach(messages) { message in
          row(for: message)
        }
      }
      .padding()
    }
    .defaultScrollAnchor(.bottom)
    .scrollDismissesKeyboard(.interactively)
    .safeAreaInset(edge: .bottom) { inputBar }
    .navigationTitle("Builder")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $cutListDesign) { design in
      NavigationStack {
        CutListView(design: design)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") { cutListDesign = nil }
            }
          }
      }
    }
  }

  @ViewBuilder private func row(for message: BuilderMessage) -> some View {
    switch message.kind {
    case .prompt(let text):
      Text(text)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(Theme.white)
        .background(Theme.orange, in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 48)
    case .designing:
      HStack(spacing: 8) {
        ProgressView()
        Text("Designing…")
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 18))
      .frame(maxWidth: .infinity, alignment: .leading)
    case .failure(let text):
      Label(text, systemImage: "exclamationmark.triangle.fill")
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(.red)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
    case .design(let design):
      BuilderDesignCard(
        design: design,
        backend: backend,
        onShowCutList: { cutListDesign = design },
        onPlace: { onPlace(design) })
    }
  }

  private var inputBar: some View {
    HStack(alignment: .bottom, spacing: 8) {
      TextField("Describe a piece of furniture", text: $draft, axis: .vertical)
        .lineLimit(1...4)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
        .onSubmit { send() }
      Button {
        send()
      } label: {
        Image(systemName: "arrow.up.circle.fill")
          .font(.system(size: 34))
      }
      .tint(Theme.orange)
      .disabled(isDesigning || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      .accessibilityLabel("Send")
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(.bar)
  }

  private func send() {
    let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !prompt.isEmpty, !isDesigning else { return }
    draft = ""
    isDesigning = true
    let pending = BuilderMessage(kind: .designing)
    messages.append(BuilderMessage(kind: .prompt(prompt)))
    messages.append(pending)
    Task {
      let result: BuilderMessage.Kind
      do {
        result = .design(try await backend.generateDesign(prompt: prompt, userId: currentUser.id))
      } catch {
        result = .failure("Couldn't design that. Please try again.")
      }
      if let index = messages.firstIndex(where: { $0.id == pending.id }) {
        messages[index].kind = result
      }
      isDesigning = false
    }
  }
}

private struct BuilderMessage: Identifiable {
  enum Kind {
    case prompt(String)
    case designing
    case failure(String)
    case design(Design)
  }

  let id = UUID()
  var kind: Kind
}

private struct BuilderDesignCard: View {
  @Environment(Session.self) private var session: Session?
  let design: Design
  let backend: any Backend
  let onShowCutList: () -> Void
  let onPlace: () -> Void

  private enum Listing {
    case idle
    case pricing
    case submitting
    case listed(Product)
  }

  @State private var listing = Listing.idle
  @State private var priceText = ""
  @State private var listingFailed = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      DesignPreviewView(design: design)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      Text(design.title)
        .font(.headline)
      Button(action: onShowCutList) {
        Label("Cut list & steps", systemImage: "list.bullet.rectangle")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      Button(action: onPlace) {
        Label("Place in my room", systemImage: "cube.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      listingControls
    }
    .tint(Theme.orange)
    .padding()
    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray4)))
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder private var listingControls: some View {
    switch listing {
    case .idle:
      Button {
        listing = .pricing
      } label: {
        Label("List for sale", systemImage: "tag.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
    case .pricing, .submitting:
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          TextField("Price in USD", text: $priceText)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
          if case .submitting = listing {
            ProgressView()
          } else {
            Button("List") { submit() }
              .buttonStyle(.borderedProminent)
              .disabled(builderPriceCents(priceText) == nil)
          }
        }
        if listingFailed {
          Text("Couldn't list it. Please try again.")
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
    case .listed(let product):
      Label("Listed for \(builderDollars(product.priceCents))", systemImage: "checkmark.seal.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.green)
        .frame(maxWidth: .infinity)
    }
  }

  private func submit() {
    guard let priceCents = builderPriceCents(priceText) else { return }
    listing = .submitting
    listingFailed = false
    Task {
      do {
        listing = .listed(try await backend.listForSale(designId: design.id, priceCents: priceCents))
        await session?.reloadProducts()
      } catch {
        listing = .pricing
        listingFailed = true
      }
    }
  }
}

private func builderPriceCents(_ text: String) -> Int? {
  let cleaned = text
    .replacingOccurrences(of: "$", with: "")
    .replacingOccurrences(of: ",", with: "")
    .trimmingCharacters(in: .whitespaces)
  guard let dollars = Double(cleaned), dollars.isFinite, dollars > 0, dollars < 1_000_000 else { return nil }
  let cents = Int((dollars * 100).rounded())
  return cents > 0 ? cents : nil
}

private func builderDollars(_ cents: Int) -> String {
  String(format: "$%d.%02d", cents / 100, cents % 100)
}

#Preview {
  NavigationStack {
    BuilderChatView(
      backend: StubBackend(),
      currentUser: User(id: "stub-user-1", name: "Maya Chen", avatarUrl: nil),
      onPlace: { _ in })
  }
}
