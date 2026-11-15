import PDFKit
import SwiftUI

struct InstructionsView: View {
  let url: URL?

  @State private var document: PDFDocument?
  @State private var failed = false

  var body: some View {
    Group {
      if let document {
        PDFDocumentView(document: document)
      } else if url == nil || failed {
        ContentUnavailableView("No instructions yet", systemImage: "doc.text")
      } else {
        ProgressView()
      }
    }
    .task(id: url) {
      guard let url else { return }
      let data: Data?
      if url.isFileURL {
        data = try? Data(contentsOf: url)
      } else {
        data = try? await URLSession.shared.data(from: url).0
      }
      if let data, let loaded = PDFDocument(data: data) {
        document = loaded
      } else {
        failed = true
      }
    }
  }
}

private struct PDFDocumentView: UIViewRepresentable {
  let document: PDFDocument

  func makeUIView(context: Context) -> PDFView {
    let view = PDFView()
    view.autoScales = true
    view.document = document
    return view
  }

  func updateUIView(_ view: PDFView, context: Context) {
    if view.document !== document { view.document = document }
  }
}

private struct InstructionsPreview: View {
  @State private var product: Product?

  var body: some View {
    InstructionsView(url: product?.instructionsUrl)
      .task { product = try? await StubBackend().products().first }
  }
}

#Preview {
  InstructionsPreview()
}
