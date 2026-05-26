import SwiftUI

enum NommieButtonStyle {
    case primary
    case secondary
}

struct NommieButton: View {
    let title: String
    let style: NommieButtonStyle
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isLoading {
                action()
            }
        }) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(
                            tint: style == .primary ? .nommieBackground : .nommieGreen
                        ))
                } else {
                    Text(title)
                        .font(NommieFont.bodySemiBold.font())
                        .foregroundColor(
                            style == .primary ? .nommieBackground : .nommieGreen
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                    .fill(style == .primary ? Color.nommieGreen : Color.nommieBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                    .stroke(Color.nommieGreen, lineWidth: style == .secondary ? 2 : 0)
            )
        }
        .opacity(isLoading ? 0.7 : 1.0)
        .padding(.horizontal, NommieTheme.Padding.large)
    }
}

#Preview {
    VStack(spacing: 20) {
        NommieButton(title: "Save Recipe", style: .primary) {}
        NommieButton(title: "Cancel", style: .secondary) {}
        NommieButton(title: "Loading...", style: .primary, isLoading: true) {}
    }
    .padding(.horizontal, NommieTheme.Padding.large)
    .background(Color.nommieBackground)
}
