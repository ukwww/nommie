import SwiftUI

struct Step1_PhotoView: View {
    @ObservedObject var viewModel: RecipeCreationViewModel
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add a photo")
                    .font(NommieFont.titleSmall.font())
                    .foregroundColor(.nommieBrown)
                Text("Show off your creation")
                    .font(NommieFont.bodyRegular.font())
                    .foregroundColor(.nommieBrown.opacity(0.5))
            }
            .padding(.horizontal, NommieTheme.Padding.large)

            if let image = viewModel.selectedImage {
                ZStack(alignment: .bottomTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.0, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.card))
                        // .clipped() only clips drawing, not hit-testing — a
                        // non-square image's overflow would swallow every tap.
                        .allowsHitTesting(false)
                        .padding(.horizontal, NommieTheme.Padding.large)

                    Button(action: { showingPicker = true }) {
                        Text("Change photo")
                            .font(NommieFont.caption.font())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.black.opacity(0.45)))
                    }
                    .padding(.bottom, 16)
                    .padding(.trailing, NommieTheme.Padding.large + 8)
                }
            } else {
                Button(action: { showingPicker = true }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.card)
                            .fill(Color.white.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.card)
                                    .stroke(Color.nommieBrown.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [8]))
                            )
                        VStack(spacing: 12) {
                            Image(systemName: "camera")
                                .font(.system(size: 36))
                                .foregroundColor(.nommieGreen.opacity(0.5))
                            Text("Tap to add a photo")
                                .font(NommieFont.bodyRegular.font())
                                .foregroundColor(.nommieBrown.opacity(0.4))
                            Text("Pinch and drag to crop")
                                .font(NommieFont.caption.font())
                                .foregroundColor(.nommieBrown.opacity(0.28))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1.0, contentMode: .fit)
                }
                .padding(.horizontal, NommieTheme.Padding.large)
            }
        }
        .fullScreenCover(isPresented: $showingPicker) {
            ImageCropPickerView(selectedImage: $viewModel.selectedImage) {
                showingPicker = false
            }
            .ignoresSafeArea()
        }
    }
}
