import SwiftUI

struct CutListView: View {
  let design: Design

  var body: some View {
    List {
      Section("Cut list") {
        if design.cutList.isEmpty {
          Text("No cut items").foregroundStyle(.secondary)
        } else {
          Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
              Text("Part")
              Text("Material")
              Text("L × W × T (cm)")
              Text("Qty").gridColumnAlignment(.trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            ForEach(Array(design.cutList.enumerated()), id: \.offset) { _, item in
              Divider().gridCellUnsizedAxes(.horizontal)
              GridRow {
                Text(item.part).fontWeight(.medium)
                Text(item.material)
                Text("\(cutListCm(item.lengthCm)) × \(cutListCm(item.widthCm)) × \(cutListCm(item.thicknessCm))")
                  .monospacedDigit()
                Text("\(item.quantity)").monospacedDigit()
              }
              .font(.subheadline)
            }
          }
          .padding(.vertical, 4)
        }
      }
      Section("Hardware") {
        if design.hardware.isEmpty {
          Text("No hardware needed").foregroundStyle(.secondary)
        }
        ForEach(Array(design.hardware.enumerated()), id: \.offset) { _, item in
          Label(item, systemImage: "wrench.and.screwdriver")
        }
      }
      Section("Steps") {
        if design.steps.isEmpty {
          Text("No steps yet").foregroundStyle(.secondary)
        }
        ForEach(Array(design.steps.enumerated()), id: \.offset) { index, step in
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(index + 1)")
              .font(.subheadline.bold())
              .foregroundStyle(Theme.white)
              .frame(width: 26, height: 26)
              .background(Theme.orange, in: Circle())
            Text(step)
          }
        }
      }
    }
    .navigationTitle(design.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}

private func cutListCm(_ value: Float) -> String {
  value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
}

#Preview {
  NavigationStack {
    CutListView(design: StubBackend.cannedDesk)
  }
}
