import SwiftUI

struct RecipeCreationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = RecipeCreationViewModel()
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.nommieBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        if viewModel.currentStep > 1 {
                            viewModel.currentStep -= 1
                        } else {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: viewModel.currentStep > 1 ? "chevron.left" : "xmark")
                            .foregroundColor(.nommieGreen)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text(stepTitle)
                        .font(NommieFont.titleSmall.font())
                        .foregroundColor(.nommieBrown)
                    
                    Spacer()
                    
                    // Balance element
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, NommieTheme.Padding.medium)
                .padding(.top, NommieTheme.Padding.large)
                .padding(.bottom, NommieTheme.Padding.medium)
                .zIndex(1)
                
                // Progress bar
                HStack(spacing: 8) {
                    ForEach(1...3, id: \.self) { step in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(step <= viewModel.currentStep ? Color.nommieGreen : Color.nommieBrown.opacity(0.15))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, NommieTheme.Padding.large)
                .padding(.bottom, NommieTheme.Padding.medium)
                .zIndex(1)
                
                // Step content
                Group {
                    switch viewModel.currentStep {
                    case 1:
                        Step1_PhotoView(viewModel: viewModel)
                    case 2:
                        Step2_DetailsView(viewModel: viewModel)
                    case 3:
                        Step3_MacrosView(viewModel: viewModel)
                    default:
                        EmptyView()
                    }
                }
                
                Spacer()
                
                // Error message
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(NommieFont.caption.font())
                        .foregroundColor(.nommieBlush)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .padding(.bottom, NommieTheme.Padding.small)
                }
                
                // Bottom navigation
                if viewModel.currentStep < 3 {
                    NommieButton(
                        title: "Continue",
                        style: .primary
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.currentStep += 1
                        }
                    }
                    .opacity(canProceed ? 1.0 : 0.5)
                    .disabled(!canProceed)
                    .padding(.bottom, 48)
                    .frame(maxWidth: .infinity)
                } else {
                    NommieButton(
                        title: "Save Recipe",
                        style: .primary,
                        isLoading: viewModel.isSaving
                    ) {
                        if let user = authViewModel.currentNommieUser {
                            Task {
                                await viewModel.saveRecipe(currentUser: user)
                            }
                        }
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .onChange(of: viewModel.isComplete) {
            if viewModel.isComplete {
                isPresented = false
            }
        }
    }
    
    var stepTitle: String {
        switch viewModel.currentStep {
        case 1: return "Add a Photo"
        case 2: return "Recipe Details"
        case 3: return "Macros"
        default: return ""
        }
    }
    
    var canProceed: Bool {
        switch viewModel.currentStep {
        case 1: return viewModel.canProceedFromStep1
        case 2: return viewModel.canProceedFromStep2
        default: return true
        }
    }
}
