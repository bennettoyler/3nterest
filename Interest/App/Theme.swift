import SwiftUI

enum Theme {
  static let orange = Color(red: 1.0, green: 0.4, blue: 0.0)
  static let white = Color.white
}

struct PinLogo: View {
  var size: CGFloat = 28

  var body: some View {
    Image(systemName: "pin.fill")
      .font(.system(size: size * 0.5, weight: .bold))
      .foregroundStyle(Theme.white)
      .frame(width: size, height: size)
      .background(Theme.orange, in: Circle())
      .accessibilityLabel("Interest")
  }
}
