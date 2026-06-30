import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, confirmPassword
    }
    
    var passwordsMatch: Bool {
        password == confirmPassword && !confirmPassword.isEmpty
    }
    
    var formIsValid: Bool {
        !email.isEmpty && password.count >= 6 && passwordsMatch
    }
    
    var body: some View {
        ZStack {
            Color.nommieBackground
                .ignoresSafeArea()
                .onTapGesture {
                    focusedField = nil
                }
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        authViewModel.currentFlow = .welcome
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.nommieGreen)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Spacer()
                }
                .padding(.horizontal, NommieTheme.Padding.large)
                .padding(.top, NommieTheme.Padding.large)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Create your account")
                                .font(NommieFont.titleMedium.font())
                                .foregroundColor(.nommieBrown)
                            
                            Text("Your cookbook starts here.")
                                .font(NommieFont.bodyRegular.font())
                                .foregroundColor(.nommieBrown.opacity(0.6))
                        }
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .padding(.top, NommieTheme.Padding.large)
                        
                        VStack(spacing: 16) {
                            NommieTextField(
                                placeholder: "you@example.com",
                                text: $email,
                                label: "Email address",
                                keyboardType: .emailAddress
                            )
                            .focused($focusedField, equals: .email)

                            NommieTextField(
                                placeholder: "6+ characters",
                                text: $password,
                                label: "Password",
                                isSecure: true
                            )
                            .focused($focusedField, equals: .password)

                            NommieTextField(
                                placeholder: "Must match password",
                                text: $confirmPassword,
                                label: "Confirm password",
                                isSecure: true
                            )
                            .focused($focusedField, equals: .confirmPassword)
                            
                            if !confirmPassword.isEmpty && !passwordsMatch {
                                Text("Passwords don't match")
                                    .font(NommieFont.caption.font())
                                    .foregroundColor(.nommieBlush)
                                    .padding(.horizontal, NommieTheme.Padding.large)
                            }
                            
                            if !authViewModel.errorMessage.isEmpty {
                                Text(authViewModel.errorMessage)
                                    .font(NommieFont.caption.font())
                                    .foregroundColor(.nommieBlush)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, NommieTheme.Padding.large)
                            }
                        }
                        
                        NommieButton(
                            title: "Continue",
                            style: .primary,
                            isLoading: authViewModel.isLoading
                        ) {
                            guard formIsValid else { return }
                            Task {
                                await authViewModel.signUp(
                                    email: email,
                                    password: password
                                )
                            }
                        }
                        .padding(.bottom, 48)
                        .opacity(formIsValid ? 1.0 : 0.5)
                    }
                }
            }
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}
