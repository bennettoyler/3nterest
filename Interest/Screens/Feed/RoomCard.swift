import SwiftUI

struct RoomCard: View {
  let room: Room
  var thumbnailHeight: CGFloat = 180

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Color.accentColor.opacity(0.15)
        .frame(height: thumbnailHeight)
        .overlay {
          if let url = room.thumbnailUrl {
            AsyncImage(url: url) { phase in
              if let image = phase.image {
                image.resizable().scaledToFill()
              } else {
                placeholder
              }
            }
          } else {
            placeholder
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))

      Text(room.title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
      Text(room.ownerName)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var placeholder: some View {
    Image(systemName: "sofa.fill")
      .font(.largeTitle)
      .foregroundStyle(Color.accentColor)
  }
}
