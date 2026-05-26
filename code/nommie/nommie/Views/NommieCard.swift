import SwiftUI

struct NommieCard<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.card)
                .fill(Color.nommieBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.card)
                .stroke(Color.nommieBrown.opacity(0.08), lineWidth: 1)
        )
        .shadow(
            color: NommieTheme.Shadow.cardColor,
            radius: NommieTheme.Shadow.cardRadius,
            x: NommieTheme.Shadow.cardX,
            y: NommieTheme.Shadow.cardY
        )
        .padding(.horizontal, NommieTheme.Padding.medium)
    }
}

#Preview {
    ZStack {
        Color.nommieBackground.ignoresSafeArea()
        NommieCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Plated by: @you")
                    .font(Font.custom("Caveat-Regular", size: 18))
                    .foregroundColor(.nommieGreen)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding([.top, .horizontal], NommieTheme.Padding.medium)
                
                Rectangle()
                    .fill(Color.nommieBrown.opacity(0.1))
                    .frame(maxWidth: .infinity)
                    .frame(height: 375)
                
                Text("Spaghetti Carbonara")
                    .font(NommieFont.titleMedium.font())
                    .foregroundColor(.nommieBrown)
                    .padding(.horizontal, NommieTheme.Padding.medium)
                    .padding(.bottom, NommieTheme.Padding.medium)
            }
        }
    }
}
