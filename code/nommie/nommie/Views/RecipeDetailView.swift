import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var showingExport = false
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.nommieBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    RecipeCardView(recipe: recipe, compact: false)
                        .padding(.top, 60)
                    
                    Spacer(minLength: 100)
                }
            }
            
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.nommieGreen)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.nommieBackground)
                                .shadow(
                                    color: NommieTheme.Shadow.cardColor,
                                    radius: 8
                                )
                        )
                }
                
                Spacer()
                
                Button(action: { showingExport = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.nommieGreen)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.nommieBackground)
                                .shadow(
                                    color: NommieTheme.Shadow.cardColor,
                                    radius: 8
                                )
                        )
                }
            }
            .padding(.horizontal, NommieTheme.Padding.large)
            .padding(.top, NommieTheme.Padding.large)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingExport) {
            ExportBottomSheet(recipe: recipe, isPresented: $showingExport)
                .interactiveDismissDisabled(false)
        }
    }
}
