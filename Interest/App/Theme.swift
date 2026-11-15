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
    Text("3nterest")
      .font(.system(size: size, weight: .bold))
      .foregroundStyle(Theme.orange)
      .fixedSize()
      .accessibilityLabel("3nterest")
  }
}
