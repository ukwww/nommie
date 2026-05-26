import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            Color.nommieBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 12) {
                    Text("nommie")
                        .font(NommieFont.titleLarge.font())
                        .foregroundColor(.nommieGreen)
                    
                    Text("Plated by: @you")
                        .font(NommieFont.signature.font())
                        .foregroundColor(.nommieBrown.opacity(0.6))
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    NommieButton(title: "Create Account", style: .primary) {
                        authViewModel.currentFlow = .signUp
                    }
                    
                    NommieButton(title: "Log In", style: .secondary) {
                        authViewModel.currentFlow = .logIn
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthViewModel())
}
