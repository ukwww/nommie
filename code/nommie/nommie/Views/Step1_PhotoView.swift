import SwiftUI
import PhotosUI

struct Step1_PhotoView: View {
    @ObservedObject var viewModel: RecipeCreationViewModel
    @State private var selectedItem: PhotosPickerItem? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            if let image = viewModel.selectedImage {
                ZStack(alignment: .bottomTrailing) {
                    GeometryReader { geo in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: 380)
                            .clipped()
                    }
                    .frame(height: 380)
                    .cornerRadius(NommieTheme.CornerRadius.card)
                    .padding(.horizontal, NommieTheme.Padding.large)
                    
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Change")
                                .font(NommieFont.caption.font())
                        }
                        .foregroundColor(.nommieBackground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.nommieBrown.opacity(0.6))
                        )
                    }
                    .padding(.bottom, NommieTheme.Padding.large)
                    .padding(.trailing, NommieTheme.Padding.large + NommieTheme.Padding.small)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 380)
                
            } else {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.nommieGreen)
                        
                        Text("Add a photo of your dish")
                            .font(NommieFont.bodySemiBold.font())
                            .foregroundColor(.nommieBrown)
                        
                        Text("Tap to choose from your library")
                            .font(NommieFont.caption.font())
                            .foregroundColor(.nommieBrown.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 380)
                    .background(
                        RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.card)
                            .fill(Color.white.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.card)
                                    .stroke(
                                        Color.nommieBrown.opacity(0.2),
                                        style: StrokeStyle(lineWidth: 2, dash: [8])
                                    )
                            )
                    )
                    .padding(.horizontal, NommieTheme.Padding.large)
                }
            }
        }
        .onChange(of: selectedItem) {
            Task {
                if let data = try? await selectedItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        viewModel.selectedImage = image
                    }
                }
            }
        }
    }
}
