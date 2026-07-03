import SwiftUI
import CoreImage.CIFilterBuiltins

struct RecipeDetailView: View {
    let recipe: Recipe
    var isOwner: Bool = true
    var onDelete: (() -> Void)? = nil
    var onReplate: ((Recipe) -> Void)? = nil

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingExport = false
    @State private var showingDeleteConfirm = false
    @State private var showingEditSheet = false
    @State private var showingReportDialog = false
    @State private var showingReportThanks = false
    @State private var isSaved: Bool = false
    @State private var isSaveLoading: Bool = false
    @State private var perServing: Bool = false
    @State private var originalRecipe: Recipe? = nil

    private let userService = UserService()

    private var palette: CardPalette {
        isOwner ? CardPalettes.neutral : CardPalettes.paletteForUser(recipe.userId)
    }
    private var cardBackground: Color { palette.background }
    private var cardAccent: Color { palette.accent }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.nommieBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.nommieBrown)
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text(recipe.dishName)
                        .font(Font.custom("Lora-SemiBold", size: 17))
                        .foregroundColor(.nommieBrown)
                        .lineLimit(1)
                    Spacer()
                    if isOwner {
                        HStack(spacing: 0) {
                            Button(action: { showingEditSheet = true }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.nommieBrown.opacity(0.35))
                                    .font(.system(size: 17))
                                    .frame(width: 44, height: 44)
                            }
                            Button(action: { showingDeleteConfirm = true }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.nommieBrown.opacity(0.35))
                                    .font(.system(size: 17))
                                    .frame(width: 44, height: 44)
                            }
                        }
                    } else {
                        Button(action: { showingReportDialog = true }) {
                            Image(systemName: "flag")
                                .foregroundColor(.nommieBrown.opacity(0.35))
                                .font(.system(size: 16))
                                .frame(width: 44, height: 44)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, NommieTheme.Padding.large)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // Replate attribution header
                        if let meta = recipe.replateMeta {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Replated by: @\(recipe.username)")
                                    .font(Font.custom("Caveat-Regular", size: 19))
                                    .foregroundColor(cardAccent)
                                Button(action: {
                                    Task {
                                        originalRecipe = try? await userService.fetchRecipe(id: meta.originalRecipeId)
                                    }
                                }) {
                                    Text("↻ from @\(meta.originalUsername) · \"\(meta.originalDishName)\"")
                                        .font(Font.custom("Nunito-Regular", size: 12))
                                        .foregroundColor(.nommieBrown.opacity(0.5))
                                        .underline()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 10)
                        } else {
                            Text("Plated by: @\(recipe.username)")
                                .font(Font.custom("Caveat-Regular", size: 19))
                                .foregroundColor(cardAccent)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 10)
                        }

                        // Image — square crop with rounded corners
                        GeometryReader { geo in
                            CachedAsyncImage(url: URL(string: recipe.imageURL)) { image in
                                image.resizable().scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.width)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .fill(cardAccent.opacity(0.08))
                                    .frame(width: geo.size.width, height: geo.size.width)
                                    .overlay(
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 32))
                                            .foregroundColor(cardAccent.opacity(0.3))
                                    )
                            }
                        }
                        .aspectRatio(1.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)

                        // Dish name
                        Text(recipe.dishName)
                            .font(Font.custom("Lora-Bold", size: 22))
                            .foregroundColor(.nommieBrown)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)

                        // Stars + servings
                        HStack(spacing: 10) {
                            StarsRow(stars: recipe.prepTimeStars, accent: cardAccent, timeLabel: recipe.prepTimeLabel)
                            Text("·")
                                .foregroundColor(.nommieBrown.opacity(0.3))
                            Text(recipe.servings == 1 ? "1 serving" : "\(recipe.servings) servings")
                                .font(Font.custom("Nunito-Regular", size: 12))
                                .foregroundColor(.nommieBrown.opacity(0.5))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        // Per-serving toggle (only shown if recipe has multiple servings)
                        if recipe.servings > 1 {
                            SegmentedToggle(
                                leftLabel: "Total",
                                rightLabel: "Per serving",
                                isRight: $perServing
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                        }

                        // Macros row
                        let dm = recipe.displayMacros(perServing: perServing)
                        let sfx = perServing ? "/S" : ""
                        HStack(spacing: 0) {
                            DetailMacroBox(value: "\(dm.calories)", label: "CAL\(sfx)", accent: cardAccent)
                            DetailMacroBox(value: "\(dm.protein)g", label: "PRO\(sfx)", accent: cardAccent)
                            DetailMacroBox(value: "\(dm.carbs)g", label: "CARB\(sfx)", accent: cardAccent)
                            DetailMacroBox(value: "\(dm.fat)g", label: "FAT\(sfx)", accent: cardAccent)
                            DetailMacroBox(value: "\(dm.fiber)g", label: "FIB\(sfx)", accent: cardAccent)
                            DetailMacroBox(value: "\(dm.sugar)g", label: "SUG\(sfx)", accent: cardAccent)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        // Ingredients
                        if !recipe.ingredients.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Ingredients")
                                    .font(Font.custom("Lora-SemiBold", size: 15))
                                    .foregroundColor(.nommieBrown)
                                    .padding(.bottom, 2)

                                ForEach(recipe.ingredients) { ingredient in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle()
                                            .fill(cardAccent)
                                            .frame(width: 5, height: 5)
                                            .padding(.top, 7)
                                        HStack(spacing: 3) {
                                            if !ingredient.quantity.isEmpty {
                                                Text(ingredient.quantity)
                                                    .font(Font.custom("Nunito-Regular", size: 14))
                                                    .foregroundColor(cardAccent)
                                            }
                                            Text(ingredient.name)
                                                .font(Font.custom("Nunito-Regular", size: 14))
                                                .foregroundColor(.nommieBrown.opacity(0.8))
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                        }

                        // Notes
                        if !recipe.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes")
                                    .font(Font.custom("Lora-SemiBold", size: 15))
                                    .foregroundColor(.nommieBrown)
                                Text(recipe.notes)
                                    .font(Font.custom("Nunito-Regular", size: 14))
                                    .foregroundColor(.nommieBrown.opacity(0.65))
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                        }

                        // Tags
                        if !recipe.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(recipe.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(Font.custom("Nunito-Regular", size: 12))
                                            .foregroundColor(.nommieBrown.opacity(0.7))
                                            .lineLimit(1)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(Color.nommieBrown.opacity(0.08)))
                                            .fixedSize()
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.bottom, 14)
                        }

                        // Watermark
                        Text("nommie")
                            .font(Font.custom("Nunito-Regular", size: 11))
                            .italic()
                            .foregroundColor(.nommieBrown.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(cardAccent.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                    .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }

            // Fixed bottom action bar
            VStack(spacing: 0) {
                if isOwner {
                    VStack(spacing: 10) {
                        Text("Your card is ready to share")
                            .font(Font.custom("Nunito-Regular", size: 13))
                            .foregroundColor(.nommieBrown.opacity(0.45))

                        Button(action: { showingExport = true }) {
                            VStack(spacing: 3) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Export Card")
                                        .font(Font.custom("Nunito-Bold", size: 16))
                                }
                                Text("Post to Instagram, TikTok & more")
                                    .font(Font.custom("Nunito-Regular", size: 12))
                                    .opacity(0.8)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.nommieGreen))
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    HStack(spacing: 12) {
                        // Save / Bookmark
                        Button(action: toggleSave) {
                            HStack(spacing: 6) {
                                if isSaveLoading {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .nommieGreen))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                Text(isSaved ? "Saved" : "Save")
                                    .font(Font.custom("Nunito-SemiBold", size: 16))
                            }
                            .foregroundColor(.nommieGreen)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.nommieGreen, lineWidth: 1.5)
                            )
                        }
                        .disabled(isSaveLoading)

                        // Replate
                        Button(action: {
                            NommieAnalytics.replateTapped()
                            onReplate?(recipe)
                            dismiss()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.2.squarepath")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Replate")
                                    .font(Font.custom("Nunito-SemiBold", size: 16))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.nommieGreen))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 32)
            .padding(.top, 12)
            .background(Color.nommieBackground.opacity(0.97))
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingExport) {
            ExportBottomSheet(recipe: recipe, isPresented: $showingExport)
                .environmentObject(authViewModel)
        }
        .fullScreenCover(isPresented: $showingEditSheet) {
            RecipeCreationView(isPresented: $showingEditSheet, editingRecipe: recipe)
                .environmentObject(authViewModel)
        }
        .sheet(item: $originalRecipe) { original in
            RecipeDetailView(recipe: original, isOwner: original.userId == authViewModel.currentNommieUser?.id)
                .environmentObject(authViewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileNeedsRefresh)) { _ in
            dismiss()
        }
        .confirmationDialog("Report this recipe", isPresented: $showingReportDialog, titleVisibility: .visible) {
            Button("Inappropriate content") { submitReport(reason: "inappropriate") }
            Button("Spam or misleading") { submitReport(reason: "spam") }
            Button("Offensive or harmful") { submitReport(reason: "offensive") }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Thanks for the report", isPresented: $showingReportThanks) {
            Button("OK") {}
        } message: {
            Text("We'll review this content within 24 hours.")
        }
        .alert("Delete Recipe", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    try? await userService.deleteRecipe(recipeId: recipe.id)
                    NommieAnalytics.cardDeleted()
                    await MainActor.run { onDelete?(); dismiss() }
                }
            }
        } message: {
            Text("This will permanently delete \"\(recipe.dishName)\" and its photo.")
        }
        .task {
            if !isOwner, let uid = authViewModel.currentNommieUser?.id {
                isSaved = (try? await userService.isSaved(userId: uid, recipeId: recipe.id)) ?? false
            }
        }
    }

    private func submitReport(reason: String) {
        guard let uid = authViewModel.currentNommieUser?.id else { return }
        Task {
            try? await userService.reportRecipe(
                recipeId: recipe.id,
                recipeOwnerId: recipe.userId,
                reporterId: uid,
                reason: reason
            )
            await MainActor.run { showingReportThanks = true }
        }
    }

    private func toggleSave() {
        guard let uid = authViewModel.currentNommieUser?.id else { return }
        NommieAnalytics.saveTapped()
        isSaveLoading = true
        Task {
            do {
                if isSaved {
                    try await userService.unsaveRecipe(userId: uid, recipeId: recipe.id)
                } else {
                    try await userService.saveRecipe(userId: uid, recipeId: recipe.id)
                }
                await MainActor.run {
                    isSaved.toggle()
                    isSaveLoading = false
                    NotificationCenter.default.post(name: .profileNeedsRefresh, object: nil)
                }
            } catch {
                await MainActor.run { isSaveLoading = false }
            }
        }
    }
}

// MARK: - Detail Macro Box
struct DetailMacroBox: View {
    let value: String
    let label: String
    let accent: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Font.custom("Nunito-Bold", size: 13))
                .foregroundColor(.nommieBrown)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(Font.custom("Nunito-Regular", size: 8))
                .foregroundColor(.nommieBrown.opacity(0.5))
                .kerning(0.2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(accent.opacity(0.1))
        .overlay(Rectangle().stroke(accent.opacity(0.12), lineWidth: 0.5))
    }
}

// MARK: - Small inline QR code for card bottom
struct CardQRCode: View {
    let value: String
    let size: CGFloat
    let accent: Color

    var qrImage: UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return UIImage() }

        let colorFilter = CIFilter(name: "CIFalseColor")!
        colorFilter.setValue(output, forKey: kCIInputImageKey)
        colorFilter.setValue(CIColor(color: UIColor(accent)), forKey: "inputColor0")
        colorFilter.setValue(CIColor.clear, forKey: "inputColor1")
        guard let coloredOutput = colorFilter.outputImage else { return UIImage() }

        let scaled = coloredOutput.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return UIImage() }
        return UIImage(cgImage: cg)
    }

    var body: some View {
        Image(uiImage: qrImage)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
