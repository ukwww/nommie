import SwiftUI

struct HomePlaceholderView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingRecipeCreation = false
    
    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("Your cookbook is empty")
                    .font(NommieFont.titleSmall.font())
                    .foregroundColor(.nommieBrown)
                
                Text("Tap + to add your first recipe")
                    .font(NommieFont.bodyRegular.font())
                    .foregroundColor(.nommieBrown.opacity(0.5))
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingRecipeCreation = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.nommieBackground)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.nommieGreen))
                            .shadow(
                                color: NommieTheme.Shadow.cardColor,
                                radius: NommieTheme.Shadow.cardRadius
                            )
                    }
                    .padding(.trailing, NommieTheme.Padding.large)
                    .padding(.bottom, 48)
                }
            }
        }
        .fullScreenCover(isPresented: $showingRecipeCreation) {
            RecipeCreationView(isPresented: $showingRecipeCreation)
                .environmentObject(authViewModel)
        }
    }
}

#Preview {
    HomePlaceholderView()
        .environmentObject(AuthViewModel())
}
