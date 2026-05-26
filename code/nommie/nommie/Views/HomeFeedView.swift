import SwiftUI

struct HomeFeedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeFeedViewModel()
    @State private var showingRecipeCreation = false
    @State private var selectedRecipe: Recipe? = nil
    
    var body: some View {
        ZStack {
            Color.nommieBackground
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: .nommieGreen)
                        )
                    Text("Loading your cookbook...")
                        .font(NommieFont.caption.font())
                        .foregroundColor(.nommieBrown.opacity(0.5))
                        .padding(.top, 8)
                }
            } else if viewModel.recipes.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.nommieGreen.opacity(0.4))
                    
                    Text("Your cookbook is empty")
                        .font(NommieFont.titleSmall.font())
                        .foregroundColor(.nommieBrown)
                    
                    Text("Tap + to plate your first recipe")
                        .font(NommieFont.bodyRegular.font())
                        .foregroundColor(.nommieBrown.opacity(0.5))
                }
            } else {
                // Recipe feed
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(viewModel.recipes) { recipe in
                            Button(action: {
                                selectedRecipe = recipe
                            }) {
                                RecipeCardView(recipe: recipe, compact: true)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.top, 90)
                    .padding(.bottom, 120)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            
            // Top header
            VStack {
                HStack {
                    Text("nommie")
                        .font(NommieFont.titleMedium.font())
                        .foregroundColor(.nommieGreen)
                    
                    Spacer()
                }
                .padding(.horizontal, NommieTheme.Padding.large)
                .padding(.top, NommieTheme.Padding.large)
                .padding(.bottom, NommieTheme.Padding.medium)
                .background(Color.nommieBackground)
                
                Spacer()
            }
            
            // Floating + button
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
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .fullScreenCover(isPresented: $showingRecipeCreation) {
            RecipeCreationView(isPresented: $showingRecipeCreation)
                .environmentObject(authViewModel)
        }
        .onAppear {
            if let userID = authViewModel.currentNommieUser?.id {
                Task {
                    await viewModel.fetchRecipes(for: userID)
                }
            }
        }
        .onChange(of: showingRecipeCreation) {
            if !showingRecipeCreation {
                if let userID = authViewModel.currentNommieUser?.id {
                    Task {
                        await viewModel.fetchRecipes(for: userID)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeFeedView()
        .environmentObject(AuthViewModel())
}
