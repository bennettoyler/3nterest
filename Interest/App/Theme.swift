import SwiftUI

enum Theme {
  static let orange = Color(red: 1.0, green: 0.4, blue: 0.0)
  static let white = Color.white
}

struct PinLogo: View {
  var size: CGFloat = 28

  var body: some View {
    Text("3")
      .font(.system(size: size * 0.72, weight: .regular))
      .foregroundStyle(Theme.white)
      .frame(width: size, height: size)
      .background(Theme.orange, in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
      .accessibilityLabel("3nterest")
  }
}

struct Wordmark: View {
  var size: CGFloat = 22

  var body: some View {
    let font = Font.system(size: size, weight: .bold)
    HStack(alignment: .firstTextBaseline, spacing: size * 0.09) {
      Text("3")
        .font(font)
        .foregroundStyle(Theme.white)
        .padding(.horizontal, size * 0.2)
        .padding(.vertical, size * 0.02)
        .background(Theme.orange, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
      Text("nterest")
        .font(font)
        .foregroundStyle(Theme.orange)
    }
    .fixedSize()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("3nterest")
  }
}
