import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ExportBottomSheet: View {
    let recipe: Recipe
    @Binding var isPresented: Bool
    @State private var selectedFormat: ExportFormat = .post
    @State private var selectedPalette: CardPalette = CardPalettes.neutral
    @State private var perServing: Bool = false
    @State private var isExporting: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccess: Bool = false
    @State private var previewImage: UIImage? = nil

    private let exportService = ExportService()

    // Scale the card down to fit in a reasonable preview area
    // Max preview area: screen-width minus 80pt, max 360pt tall
    private var previewScale: CGFloat {
        let nat = selectedFormat.naturalSize
        let maxW = UIScreen.main.bounds.width - 80
        let maxH: CGFloat = 360
        return min(maxW / nat.width, maxH / nat.height)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.nommieBackground.ignoresSafeArea()

            if showSuccess {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.nommieGreen)
                    Text("Saved to your camera roll!")
                        .font(Font.custom("Nunito-SemiBold", size: 16))
                        .foregroundColor(.nommieBrown)
                    Text("Check your photos app to share anywhere.")
                        .font(Font.custom("Nunito-Regular", size: 13))
                        .foregroundColor(.nommieBrown.opacity(0.5))
                        .multilineTextAlignment(.center)
                    Button(action: { isPresented = false }) {
                        Text("Done")
                            .font(Font.custom("Nunito-SemiBold", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.nommieGreen))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    Text("Export Recipe Card")
                        .font(Font.custom("Lora-SemiBold", size: 20))
                        .foregroundColor(.nommieBrown)
                        .padding(.top, 22)
                        .padding(.bottom, 18)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            // Macros toggle
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Show macros as:")
                                    .font(Font.custom("Nunito-SemiBold", size: 14))
                                    .foregroundColor(.nommieBrown.opacity(0.7))
                                SegmentedToggle(
                                    leftLabel: "Total recipe",
                                    rightLabel: "Per serving",
                                    isRight: $perServing
                                )
                            }
                            .padding(.horizontal, 16)

                            // Live preview — card rendered at natural size then uniformly scaled
                            // down so the entire card (border included) is visible at once.
                            let nat = selectedFormat.naturalSize
                            ExportCardView(
                                recipe: recipe,
                                format: selectedFormat,
                                perServing: perServing,
                                preloadedImage: previewImage,
                                palette: selectedPalette
                            )
                            .frame(width: nat.width, height: nat.height)
                            .scaleEffect(previewScale)
                            .frame(
                                width:  nat.width  * previewScale,
                                height: nat.height * previewScale
                            )
                            .animation(.easeInOut(duration: 0.2), value: selectedFormat)
                            .animation(.easeInOut(duration: 0.2), value: selectedPalette)

                            // Card color picker
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Card color")
                                    .font(Font.custom("Nunito-SemiBold", size: 14))
                                    .foregroundColor(.nommieBrown.opacity(0.7))
                                    .padding(.horizontal, 16)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(CardPalettes.exportOptions, id: \.id) { palette in
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.18)) { selectedPalette = palette }
                                            }) {
                                                ZStack {
                                                    Circle()
                                                        .fill(palette.background)
                                                        .frame(width: 38, height: 38)
                                                        .overlay(Circle().stroke(palette.accent.opacity(0.3), lineWidth: 1))
                                                    Circle()
                                                        .fill(palette.accent)
                                                        .frame(width: 13, height: 13)
                                                    if selectedPalette == palette {
                                                        Circle()
                                                            .stroke(palette.accent, lineWidth: 2.5)
                                                            .frame(width: 48, height: 48)
                                                    }
                                                }
                                                .frame(width: 52, height: 52)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            // Format rows
                            VStack(spacing: 10) {
                                FormatRow(
                                    icon: "rectangle.portrait",
                                    title: "Post",
                                    subtitle: "Portrait — Instagram feed",
                                    isSelected: selectedFormat == .post,
                                    action: { selectedFormat = .post }
                                )
                                FormatRow(
                                    icon: "rectangle.portrait.fill",
                                    title: "Story (9:16)",
                                    subtitle: "Instagram & TikTok stories",
                                    isSelected: selectedFormat == .story,
                                    action: { selectedFormat = .story }
                                )
                            }
                            .padding(.horizontal, 16)

                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(Font.custom("Nunito-Regular", size: 12))
                                    .foregroundColor(.nommieBlush)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }

                            Color.clear.frame(height: 80)
                        }
                    }

                    // Export button
                    Button(action: { exportCard() }) {
                        ZStack {
                            if isExporting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Export & Share")
                                    .font(Font.custom("Nunito-SemiBold", size: 16))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.nommieGreen))
                    }
                    .disabled(isExporting)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .padding(.top, 8)
                    .background(Color.nommieBackground)
                }
            }

            // X button
            if !showSuccess {
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.nommieBrown.opacity(0.5))
                        .frame(width: 30, height: 30)
                        .background(Circle().strokeBorder(Color.nommieBrown.opacity(0.2), lineWidth: 1.5))
                }
                .padding(.top, 20)
                .padding(.trailing, 20)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            NommieAnalytics.exportSheetOpened()
            loadPreviewImage()
        }
    }

    private func loadPreviewImage() {
        guard previewImage == nil, let url = URL(string: recipe.imageURL) else { return }
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let loaded = UIImage(data: data) {
                await MainActor.run { previewImage = loaded }
            }
        }
    }

    func exportCard() {
        guard !isExporting else { return }
        isExporting = true
        errorMessage = ""
        Task {
            do {
                let image = try await exportService.exportCard(
                    recipe: recipe,
                    format: selectedFormat,
                    perServing: perServing,
                    preloadedImage: previewImage,
                    palette: selectedPalette
                )
                try await exportService.saveToPhotoLibrary(image)
                NommieAnalytics.cardExported(format: selectedFormat == .story ? "story" : "post")
                if let uid = Auth.auth().currentUser?.uid {
                    try? await Firestore.firestore().collection("users").document(uid)
                        .updateData(["exportCount": FieldValue.increment(Int64(1))])
                }
                await MainActor.run {
                    isExporting = false
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
                await MainActor.run { errorMessage = error.localizedDescription; isExporting = false }
            }
        }
    }
}

// MARK: - Segmented Toggle
struct SegmentedToggle: View {
    let leftLabel: String
    let rightLabel: String
    @Binding var isRight: Bool

    var body: some View {
        HStack(spacing: 0) {
            segment(leftLabel, selected: !isRight) { isRight = false }
            segment(rightLabel, selected: isRight) { isRight = true }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.nommieBrown.opacity(0.08)))
    }

    private func segment(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { action() } }) {
            Text(label)
                .font(Font.custom("Nunito-SemiBold", size: 15))
                .foregroundColor(selected ? .nommieBrown : .nommieBrown.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(selected ? Color.white : Color.clear)
                        .shadow(color: selected ? Color.black.opacity(0.06) : .clear, radius: 3, x: 0, y: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Format Row
struct FormatRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.nommieGreen.opacity(0.12) : Color.nommieBrown.opacity(0.06))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .nommieGreen : .nommieBrown.opacity(0.4))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Font.custom("Nunito-SemiBold", size: 15))
                        .foregroundColor(.nommieBrown)
                    Text(subtitle)
                        .font(Font.custom("Nunito-Regular", size: 13))
                        .foregroundColor(.nommieBrown.opacity(0.5))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .nommieGreen : .nommieBrown.opacity(0.2))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.7)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                isSelected ? Color.nommieGreen.opacity(0.4) : Color.nommieBrown.opacity(0.08),
                lineWidth: isSelected ? 1.5 : 1
            ))
        }
    }
}

#Preview {
    ExportBottomSheet(recipe: Recipe(), isPresented: .constant(true))
}
