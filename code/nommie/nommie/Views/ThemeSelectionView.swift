import SwiftUI

struct ThemeOption {
    let id: String
    let name: String
    let description: String
    let background: Color
    let accent: Color
    let secondary: Color
}

struct ThemeSelectionView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTheme: String = "classic"
    private let profileViewModel = ProfileViewModel()
    
    let themes: [ThemeOption] = [
        ThemeOption(
            id: "classic",
            name: "Classic",
            description: "Warm cream & forest green",
            background: Color(hex: "F5F0E8"),
            accent: Color(hex: "3A5C44"),
            secondary: Color(hex: "E8D98A")
        ),
        ThemeOption(
            id: "sage",
            name: "Sage",
            description: "Muted greens & earthy tones",
            background: Color(hex: "EDF0EB"),
            accent: Color(hex: "4A6741"),
            secondary: Color(hex: "B5C4B1")
        ),
        ThemeOption(
            id: "blush",
            name: "Blush",
            description: "Soft pink & rose tones",
            background: Color(hex: "FAF0F0"),
            accent: Color(hex: "C87E8A"),
            secondary: Color(hex: "E8C4C4")
        )
    ]
    
    var isOnboarding: Bool {
        authViewModel.currentFlow == .themeSelection
    }
    
    var body: some View {
        ZStack {
            Color.nommieBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                if !isOnboarding {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.nommieGreen)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, NommieTheme.Padding.medium)
                    .padding(.top, NommieTheme.Padding.medium)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Choose your style")
                                .font(NommieFont.titleMedium.font())
                                .foregroundColor(.nommieBrown)
                            
                            Text("This sets the look of your recipe cards.")
                                .font(NommieFont.bodyRegular.font())
                                .foregroundColor(.nommieBrown.opacity(0.6))
                        }
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .padding(.top, isOnboarding ? 60 : NommieTheme.Padding.large)
                        
                        VStack(spacing: 16) {
                            ForEach(themes, id: \.id) { theme in
                                ThemeCard(
                                    theme: theme,
                                    isSelected: selectedTheme == theme.id
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedTheme = theme.id
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, NommieTheme.Padding.large)
                        
                        NommieButton(
                            title: isOnboarding ? "Let's Cook" : "Save Theme",
                            style: .primary,
                            isLoading: authViewModel.isLoading
                        ) {
                            if isOnboarding {
                                Task {
                                    await authViewModel.saveThemeAndFinish(
                                        username: authViewModel.newUsername,
                                        theme: selectedTheme
                                    )
                                }
                            } else {
                                Task {
                                    if let userID = authViewModel.currentNommieUser?.id {
                                        await profileViewModel.updateTheme(
                                            theme: selectedTheme,
                                            for: userID
                                        )
                                        await MainActor.run {
                                            authViewModel.currentNommieUser?.selectedTheme = selectedTheme
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 48)
                    }
                }
            }
        }
        .onAppear {
            selectedTheme = authViewModel.currentNommieUser?.selectedTheme ?? "classic"
        }
    }
}

struct ThemeCard: View {
    let theme: ThemeOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.background)
                        .frame(width: 72, height: 72)
                    
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.accent)
                            .frame(width: 40, height: 8)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.secondary)
                            .frame(width: 40, height: 8)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.accent.opacity(0.4))
                            .frame(width: 40, height: 8)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? theme.accent : Color.nommieBrown.opacity(0.1),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.name)
                        .font(NommieFont.bodySemiBold.font())
                        .foregroundColor(.nommieBrown)
                    
                    Text(theme.description)
                        .font(NommieFont.caption.font())
                        .foregroundColor(.nommieBrown.opacity(0.6))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.accent)
                        .font(.system(size: 22))
                }
            }
            .padding(NommieTheme.Padding.medium)
            .background(
                RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                    .fill(isSelected ? theme.background : Color.white.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                    .stroke(
                        isSelected ? theme.accent : Color.nommieBrown.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}

#Preview {
    ThemeSelectionView()
        .environmentObject(AuthViewModel())
}
