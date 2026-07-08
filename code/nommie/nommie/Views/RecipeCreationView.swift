import SwiftUI

struct RecipeCreationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = RecipeCreationViewModel()
    @Binding var isPresented: Bool
    var replateSource: Recipe? = nil
    var editingRecipe: Recipe? = nil
    // The 48pt bottom padding exists for the home-indicator area; when the
    // keyboard is up it just wastes screen, so collapse it.
    @State private var keyboardVisible = false

    private var bottomBarPadding: CGFloat { keyboardVisible ? 10 : 48 }

    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()

            // Full-screen saving overlay with spinning logo
            if viewModel.isSaving {
                ZStack {
                    Color.nommieBackground.opacity(0.97).ignoresSafeArea()
                    VStack(spacing: 20) {
                        NommieSpinningLogo(size: 44)
                        Text("Saving your plate...")
                            .font(Font.custom("Nunito-Regular", size: 15))
                            .foregroundColor(.nommieBrown.opacity(0.55))
                    }
                }
                .zIndex(10)
                .transition(.opacity)
            }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        let minStep = viewModel.isEditMode ? 2 : 1
                        if viewModel.currentStep > minStep {
                            viewModel.currentStep -= 1
                        } else {
                            isPresented = false
                        }
                    }) {
                        let minStep = viewModel.isEditMode ? 2 : 1
                        Image(systemName: viewModel.currentStep > minStep ? "chevron.left" : "xmark")
                            .foregroundColor(.nommieGreen)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Text(editingRecipe != nil ? "Edit Recipe" : replateSource != nil ? "Replate" : "New Recipe")
                        .font(NommieFont.titleSmall.font())
                        .foregroundColor(.nommieBrown)

                    Spacer()

                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, NommieTheme.Padding.medium)
                .padding(.top, NommieTheme.Padding.large)
                .padding(.bottom, 8)

                // Replate attribution banner
                if let source = replateSource {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 12))
                            .foregroundColor(.nommieGreen)
                        Text("Replating from @\(source.username) · \"\(source.dishName)\"")
                            .font(Font.custom("Nunito-Regular", size: 12))
                            .foregroundColor(.nommieBrown.opacity(0.65))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)
                    .padding(.vertical, 8)
                    .background(Color.nommieGreen.opacity(0.08))
                }

                // Progress bar
                HStack(spacing: 6) {
                    ForEach(1...4, id: \.self) { step in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(step <= viewModel.currentStep ? Color.nommieGreen : Color.nommieBrown.opacity(0.15))
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, NommieTheme.Padding.large)
                .padding(.top, 8)
                .padding(.bottom, NommieTheme.Padding.medium)

                // Step content: Photo → Write → Ingredients → Macros
                Group {
                    switch viewModel.currentStep {
                    case 1: Step1_PhotoView(viewModel: viewModel)
                    case 2: Step2_DetailsView(viewModel: viewModel)
                    case 3: Step3_IngredientsView(viewModel: viewModel)
                    case 4: Step3_MacrosView(viewModel: viewModel)
                    default: EmptyView()
                    }
                }

                Spacer()

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(NommieFont.caption.font())
                        .foregroundColor(.nommieBlush)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .padding(.bottom, 8)
                }

                // Bottom navigation
                if viewModel.currentStep < 4 {
                    HStack {
                        Spacer()
                        Button(action: {
                            if viewModel.currentStep == 1 { NommieAnalytics.stepPhotoCompleted() }
                            if viewModel.currentStep == 3 {
                                NommieAnalytics.stepDetailsCompleted(
                                    ingredientCount: viewModel.ingredients.filter { !$0.name.isEmpty }.count
                                )
                            }
                            let movingToIngredients = viewModel.currentStep == 2
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.currentStep += 1
                            }
                            if movingToIngredients {
                                Task { await viewModel.extractIngredientsIfNeeded() }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text("Next")
                                    .font(NommieFont.bodySemiBold.font())
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.nommieBackground)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(canProceed ? Color.nommieGreen : Color.nommieBrown.opacity(0.25))
                            )
                        }
                        .disabled(!canProceed)
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)
                    .padding(.bottom, bottomBarPadding)
                } else {
                    Button(action: {
                        if let user = authViewModel.currentNommieUser {
                            Task { await viewModel.saveRecipe(currentUser: user) }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                            Text(viewModel.isEditMode ? "Update Recipe" : "Save Recipe")
                                .font(Font.custom("Nunito-SemiBold", size: 16))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).fill(Color.nommieGreen))
                    }
                    .disabled(viewModel.isSaving)
                    .padding(.horizontal, NommieTheme.Padding.large)
                    .padding(.bottom, bottomBarPadding)
                }
            }
        }
        .onAppear {
            if let recipe = editingRecipe {
                viewModel.configureForEdit(recipe: recipe)
            } else if let source = replateSource {
                viewModel.configureForReplate(source: source)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardVisible = false }
        }
        .onChange(of: viewModel.isComplete) {
            if viewModel.isComplete { isPresented = false }
        }
    }

    var canProceed: Bool {
        switch viewModel.currentStep {
        case 1: return viewModel.canProceedFromStep1
        case 2: return viewModel.canProceedFromStep2
        case 3: return viewModel.canProceedFromStep3
        default: return true
        }
    }
}
