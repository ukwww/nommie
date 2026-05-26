import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingQRCode = false
    @State private var showingThemeSelection = false
    @State private var selectedRecipe: Recipe? = nil
    
    let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.nommieBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Profile header
                        VStack(spacing: 12) {
                            // Avatar circle
                            ZStack {
                                Circle()
                                    .fill(Color.nommieGreen.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                
                                Text(String(authViewModel.currentNommieUser?.username.prefix(1).uppercased() ?? "?"))
                                    .font(NommieFont.titleLarge.font())
                                    .foregroundColor(.nommieGreen)
                            }
                            
                            Text("@\(authViewModel.currentNommieUser?.username ?? "")")
                                .font(NommieFont.titleSmall.font())
                                .foregroundColor(.nommieBrown)
                            
                            Text("\(viewModel.recipes.count) plates")
                                .font(NommieFont.bodyRegular.font())
                                .foregroundColor(.nommieBrown.opacity(0.5))
                            
                            // QR code button
                            Button(action: { showingQRCode = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "qrcode")
                                    Text("My Nommie Code")
                                        .font(NommieFont.caption.font())
                                }
                                .foregroundColor(.nommieGreen)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.nommieGreen.opacity(0.1))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.nommieGreen.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.top, NommieTheme.Padding.large)
                        .padding(.bottom, NommieTheme.Padding.large)
                        
                        // Recipe grid
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(
                                    CircularProgressViewStyle(tint: .nommieGreen)
                                )
                                .padding(.top, 48)
                        } else if viewModel.recipes.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 40))
                                    .foregroundColor(.nommieGreen.opacity(0.3))
                                Text("No recipes yet")
                                    .font(NommieFont.bodyRegular.font())
                                    .foregroundColor(.nommieBrown.opacity(0.5))
                            }
                            .padding(.top, 48)
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(viewModel.recipes) { recipe in
                                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                        RecipeCardView(recipe: recipe, thumbnail: true)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, NommieTheme.Padding.medium)
                        }
                        
                        // Settings section
                        VStack(spacing: 12) {
                            Divider()
                                .padding(.vertical, NommieTheme.Padding.medium)
                            
                            Button(action: { showingThemeSelection = true }) {
                                HStack {
                                    Image(systemName: "paintpalette")
                                        .foregroundColor(.nommieGreen)
                                    Text("Change Theme")
                                        .font(NommieFont.bodyRegular.font())
                                        .foregroundColor(.nommieBrown)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.nommieBrown.opacity(0.3))
                                }
                                .padding(.horizontal, NommieTheme.Padding.large)
                            }
                            
                            Button(action: { authViewModel.signOut() }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.nommieBlush)
                                    Text("Sign Out")
                                        .font(NommieFont.bodyRegular.font())
                                        .foregroundColor(.nommieBlush)
                                    Spacer()
                                }
                                .padding(.horizontal, NommieTheme.Padding.large)
                            }
                        }
                        .padding(.top, NommieTheme.Padding.large)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("my cookbook")
                        .font(NommieFont.titleSmall.font())
                        .foregroundColor(.nommieBrown)
                }
            }
        }
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(
                username: authViewModel.currentNommieUser?.username ?? "",
                isPresented: $showingQRCode
            )
        }
        .sheet(isPresented: $showingThemeSelection) {
            ThemeSelectionView()
                .environmentObject(authViewModel)
        }
        .onAppear {
            if let userID = authViewModel.currentNommieUser?.id {
                Task {
                    await viewModel.fetchRecipes(for: userID)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
