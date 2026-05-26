import SwiftUI

struct ExportBottomSheet: View {
    let recipe: Recipe
    @Binding var isPresented: Bool
    @State private var exportingFormat: ExportFormat? = nil
    @State private var errorMessage: String = ""
    @State private var showSuccess: Bool = false
    
    private let exportService = ExportService()
    
    var body: some View {
        ZStack {
            Color.nommieBackground
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.nommieBrown.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                Text("Export Recipe Card")
                    .font(NommieFont.titleSmall.font())
                    .foregroundColor(.nommieBrown)
                
                if showSuccess {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.nommieGreen)
                        
                        Text("Saved to your camera roll!")
                            .font(NommieFont.bodySemiBold.font())
                            .foregroundColor(.nommieBrown)
                        
                        Text("Check your photos app to share it anywhere.")
                            .font(NommieFont.caption.font())
                            .foregroundColor(.nommieBrown.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 24)
                } else {
                    HStack(spacing: 16) {
                        FormatCard(
                            title: "Story",
                            description: "Perfect for\nInstagram Stories",
                            aspectLabel: "9:16",
                            isLoading: exportingFormat == .story
                        ) {
                            exportCard(format: .story)
                        }
                        
                        FormatCard(
                            title: "Square",
                            description: "Perfect for\nInstagram Posts",
                            aspectLabel: "1:1",
                            isLoading: exportingFormat == .square
                        ) {
                            exportCard(format: .square)
                        }
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(NommieFont.caption.font())
                            .foregroundColor(.nommieBlush)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, NommieTheme.Padding.large)
                    }
                }
                
                NommieButton(
                    title: showSuccess ? "Done" : "Cancel",
                    style: .secondary
                ) {
                    isPresented = false
                }
                .padding(.bottom, 32)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
    
    func exportCard(format: ExportFormat) {
        guard exportingFormat == nil else { return }
        exportingFormat = format
        errorMessage = ""
        
        Task {
            do {
                // Pre-load the recipe image before rendering
                var recipeImage: UIImage? = nil
                if let url = URL(string: recipe.imageURL),
                   let (data, _) = try? await URLSession.shared.data(from: url),
                   let loaded = UIImage(data: data) {
                    recipeImage = loaded
                }
                
                let image = try await exportService.exportCard(
                    recipe: recipe,
                    format: format,
                    preloadedImage: recipeImage
                )
                try await exportService.saveToPhotoLibrary(image)
                
                await MainActor.run {
                    exportingFormat = nil
                    showSuccess = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                
                await MainActor.run {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let viewController = windowScene.windows.first?.rootViewController {
                        exportService.shareImage(image, from: viewController)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    exportingFormat = nil
                }
            }
        }
    }
}

// MARK: - Format Card
struct FormatCard: View {
    let title: String
    let description: String
    let aspectLabel: String
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.nommieGreen.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.nommieGreen.opacity(0.2), lineWidth: 1)
                        )
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(
                                CircularProgressViewStyle(tint: .nommieGreen)
                            )
                    } else {
                        Text(aspectLabel)
                            .font(NommieFont.bodySemiBold.font())
                            .foregroundColor(.nommieGreen)
                    }
                }
                .frame(width: title == "Story" ? 60 : 80, height: 80)
                
                Text(title)
                    .font(NommieFont.bodySemiBold.font())
                    .foregroundColor(.nommieBrown)
                
                Text(description)
                    .font(NommieFont.caption.font())
                    .foregroundColor(.nommieBrown.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(NommieTheme.Padding.medium)
            .background(
                RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                    .fill(Color.white.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                    .stroke(Color.nommieBrown.opacity(0.1), lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

#Preview {
    ExportBottomSheet(recipe: Recipe(), isPresented: .constant(true))
}
