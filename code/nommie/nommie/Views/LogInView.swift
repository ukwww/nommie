import SwiftUI

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
                                placeholder: "Email address",
                                text: $email,
                                keyboardType: .emailAddress
                            )
                            .focused($focusedField, equals: .email)
                            
                            NommieTextField(
                                placeholder: "Password",
                                text: $password,
                                isSecure: true
                            )
                            .focused($focusedField, equals: .password)
                            
                            HStack {
                                Spacer()
                                Button("Forgot password?") {}
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
