import SwiftUI

struct SplashView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            Color.nommieBackground
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                Text("nommie")
                    .font(NommieFont.titleLarge.font())
                    .foregroundColor(.nommieGreen)
                
                Text("Plated by: @you")
                    .font(NommieFont.signature.font())
                    .foregroundColor(.nommieBrown.opacity(0.6))
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(AuthViewModel())
}
