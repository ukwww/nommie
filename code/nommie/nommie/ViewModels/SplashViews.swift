import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()
            NommieSpinningLogo(size: 44)
        }
    }
}

// MARK: - Reusable spinning logo ("n[plate]mmie")
// Used on the splash screen and any inline loading state.
struct NommieSpinningLogo: View {
    var size: CGFloat = 38
    @State private var rotation: Double = 0

    private var plateDiameter: CGFloat { size * 0.72 }

    var body: some View {
        HStack(spacing: 0) {
            Text("n")
                .font(Font.custom("Caveat-Bold", size: size))
                .foregroundColor(.nommieGreen)

            // Spinning plate standing in for the "o"
            ZStack {
                Circle()
                    .stroke(Color.nommieGreen, lineWidth: max(1.2, plateDiameter * 0.055))
                    .frame(width: plateDiameter, height: plateDiameter)
                Circle()
                    .stroke(Color.nommieGreen.opacity(0.3), lineWidth: max(0.8, plateDiameter * 0.03))
                    .frame(width: plateDiameter * 0.7, height: plateDiameter * 0.7)
                Image(systemName: "fork.knife")
                    .font(.system(size: plateDiameter * 0.34, weight: .semibold))
                    .foregroundColor(.nommieGreen)
            }
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            Text("mmie ")
                .font(Font.custom("Caveat-Bold", size: size))
                .foregroundColor(.nommieGreen)
        }
    }
}

#Preview {
    SplashView()
}
