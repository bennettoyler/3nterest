import SwiftUI

struct PublishSheet: View {
  let onPublish: (String) async throws -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var publishing = false
  @State private var failed = false

  private var trimmedTitle: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Title") {
          TextField("My living room", text: $title)
            .submitLabel(.done)
        }
        if failed {
          Section {
            Text("Couldn't publish. Check your connection and try again.")
              .foregroundStyle(.red)
          }
        }
        Section {
          Button {
            Task { await publish() }
          } label: {
            if publishing {
              ProgressView().frame(maxWidth: .infinity)
            } else {
              Text("Publish").frame(maxWidth: .infinity)
            }
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
          .disabled(trimmedTitle.isEmpty || publishing)
        }
      }
      .navigationTitle("Publish room")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(publishing)
        }
      }
    }
    .interactiveDismissDisabled(publishing)
  }

  private func publish() async {
    publishing = true
    failed = false
    do {
      try await onPublish(trimmedTitle)
    } catch {
      failed = true
    }
    publishing = false
  }
}

#Preview {
  PublishSheet(onPublish: { _ in })
}
