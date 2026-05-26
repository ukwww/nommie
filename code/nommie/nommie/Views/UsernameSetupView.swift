import SwiftUI
import Combine

struct UsernameSetupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var username: String = ""
    @State private var isAvailable: Bool = false
    @State private var isChecking: Bool = false
    @State private var hasChecked: Bool = false
    @State private var cancellable: AnyCancellable? = nil
    @FocusState private var isFocused: Bool
    
    private let userService = UserService()
    
    var usernameIsValid: Bool {
        username.count >= 3 && isAvailable
    }
    
    var body: some View {
        ZStack {
            Color.nommieBackground
                .ignoresSafeArea()
                .onTapGesture {
                    isFocused = false
                }
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pick your username")
                                .font(NommieFont.titleMedium.font())
                                .foregroundColor(.nommieBrown)
                            
                            Text("This is how other cooks will find you.")
                                .font(NommieFont.bodyRegular.font())
                                .foregroundColor(.nommieBrown.opacity(0.6))
                        }
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .padding(.top, 60)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("@")
                                    .font(NommieFont.bodySemiBold.font())
                                    .foregroundColor(.nommieGreen)
                                    .padding(.leading, NommieTheme.Padding.large + NommieTheme.Padding.medium)
                                
                                TextField("username", text: $username)
                                    .font(NommieFont.bodyRegular.font())
                                    .foregroundColor(.nommieBrown)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .focused($isFocused)
                                    .onChange(of: username) {
                                        let cleaned = username
                                            .lowercased()
                                            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                        if cleaned != username {
                                            username = cleaned
                                        }
                                        hasChecked = false
                                        isAvailable = false
                                        debounceCheck(username: cleaned)
                                    }
                                
                                if isChecking {
                                    ProgressView()
                                        .padding(.trailing, NommieTheme.Padding.large)
                                } else if hasChecked {
                                    Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(isAvailable ? .nommieGreen : .nommieBlush)
                                        .padding(.trailing, NommieTheme.Padding.large)
                                }
                            }
                            .padding(NommieTheme.Padding.medium)
                            .background(
                                RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                                    .fill(Color.white.opacity(0.7))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                                    .stroke(
                                        hasChecked ? (isAvailable ? Color.nommieGreen : Color.nommieBlush) : Color.nommieBrown.opacity(0.15),
                                        lineWidth: 1.5
                                    )
                            )
                            .padding(.horizontal, NommieTheme.Padding.large)
                            
                            if hasChecked && !isAvailable && !isChecking {
                                Text("That username is already taken. Try another.")
                                    .font(NommieFont.caption.font())
                                    .foregroundColor(.nommieBlush)
                                    .padding(.horizontal, NommieTheme.Padding.large)
                            }
                            
                            if username.count > 0 && username.count < 3 {
                                Text("Username must be at least 3 characters.")
                                    .font(NommieFont.caption.font())
                                    .foregroundColor(.nommieBrown.opacity(0.5))
                                    .padding(.horizontal, NommieTheme.Padding.large)
                            }
                        }
                        
                        NommieButton(
                            title: "Continue",
                            style: .primary
                        ) {
                            guard usernameIsValid else { return }
                            authViewModel.saveUsername(username: username)
                        }
                        .opacity(usernameIsValid ? 1.0 : 0.5)
                        .padding(.bottom, 48)
                    }
                }
            }
        }
    }
    
    func debounceCheck(username: String) {
        cancellable?.cancel()
        guard username.count >= 3 else { return }
        isChecking = true
        cancellable = Just(username)
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { name in
                Task {
                    do {
                        let available = try await userService.isUsernameAvailable(name)
                        await MainActor.run {
                            self.isAvailable = available
                            self.isChecking = false
                            self.hasChecked = true
                        }
                    } catch {
                        await MainActor.run {
                            self.isChecking = false
                            self.hasChecked = false
                        }
                    }
                }
            }
    }
}

#Preview {
    UsernameSetupView()
        .environmentObject(AuthViewModel())
}
