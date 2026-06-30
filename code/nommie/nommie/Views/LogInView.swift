import SwiftUI
import AuthenticationServices

struct LogInView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var email: String = ""
    @State private var password: String = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var formIsValid: Bool {
        !email.isEmpty && !password.isEmpty
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
                            Text("Welcome back")
                                .font(NommieFont.titleMedium.font())
                                .foregroundColor(.nommieBrown)
                            
                            Text("Your cookbook is waiting.")
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
                                placeholder: "Your password",
                                text: $password,
                                label: "Password",
                                isSecure: true
                            )
                            .focused($focusedField, equals: .password)
                            
                            HStack {
                                Spacer()
                                Button("Forgot password?") {
                                    Task {
                                        await authViewModel.sendPasswordReset(email: email)
                                    }
                                }
                                    .font(NommieFont.caption.font())
                                    .foregroundColor(.nommieGreen)
                                    .padding(.trailing, NommieTheme.Padding.large)
                            }

                            if !authViewModel.errorMessage.isEmpty {
                                Text(authViewModel.errorMessage)
                                    .font(NommieFont.caption.font())
                                    .foregroundColor(.nommieBlush)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, NommieTheme.Padding.large)
                            }

                            if !authViewModel.infoMessage.isEmpty {
                                Text(authViewModel.infoMessage)
                                    .font(NommieFont.caption.font())
                                    .foregroundColor(.nommieGreen)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, NommieTheme.Padding.large)
                            }
                        }
                        
                        NommieButton(
                            title: "Log In",
                            style: .primary,
                            isLoading: authViewModel.isLoading
                        ) {
                            guard formIsValid else { return }
                            Task {
                                await authViewModel.signIn(
                                    email: email,
                                    password: password
                                )
                            }
                        }
                        .opacity(formIsValid ? 1.0 : 0.5)

                        HStack(spacing: 12) {
                            Rectangle().fill(Color.nommieBrown.opacity(0.1)).frame(height: 1)
                            Text("OR")
                                .font(Font.custom("Nunito-Regular", size: 12))
                                .foregroundColor(.nommieBrown.opacity(0.4))
                            Rectangle().fill(Color.nommieBrown.opacity(0.1)).frame(height: 1)
                        }
                        .padding(.horizontal, NommieTheme.Padding.large)

                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = authViewModel.prepareAppleSignIn()
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                Task { await authViewModel.signInWithApple(authorization: authorization) }
                            case .failure:
                                authViewModel.errorMessage = "Apple sign in was cancelled."
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .padding(.bottom, 48)
                    }
                }
            }
        }
    }
}

#Preview {
    LogInView()
        .environmentObject(AuthViewModel())
}
