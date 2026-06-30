import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email: String = ""
    @State private var password: String = ""
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var formIsValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()
                .onTapGesture { focusedField = nil }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: - Branding
                    VStack(spacing: 8) {
                        Text("nommie ")
                            .font(Font.custom("Caveat-Bold", size: 38))
                            .foregroundColor(.nommieGreen)

                        Text("Your cooking, beautifully plated.")
                            .font(NommieFont.titleMedium.font())
                            .foregroundColor(.nommieBrown)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 56)
                    .padding(.bottom, 28)

                    // MARK: - Animated Card Stack
                    WelcomeCardStack()
                        .padding(.bottom, 28)

                    // MARK: - Login Form
                    VStack(spacing: 16) {

                        // Continue with Apple
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

                        // OR divider
                        HStack(spacing: 12) {
                            Rectangle().fill(Color.nommieBrown.opacity(0.1)).frame(height: 1)
                            Text("OR")
                                .font(Font.custom("Nunito-Regular", size: 12))
                                .foregroundColor(.nommieBrown.opacity(0.4))
                            Rectangle().fill(Color.nommieBrown.opacity(0.1)).frame(height: 1)
                        }

                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(Font.custom("Nunito-SemiBold", size: 13))
                                .foregroundColor(.nommieBrown.opacity(0.65))
                            HStack(spacing: 10) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 14))
                                    .foregroundColor(.nommieBrown.opacity(0.35))
                                    .frame(width: 18)
                                TextField("you@example.com", text: $email)
                                    .font(NommieFont.bodyRegular.font())
                                    .foregroundColor(.nommieBrown)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .focused($focusedField, equals: .email)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                                focusedField == .email ? Color.nommieGreen.opacity(0.5) : Color.nommieBrown.opacity(0.12),
                                lineWidth: 1
                            ))
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Password")
                                    .font(Font.custom("Nunito-SemiBold", size: 13))
                                    .foregroundColor(.nommieBrown.opacity(0.65))
                                Spacer()
                                Button("Forgot password?") {
                                    Task { await authViewModel.sendPasswordReset(email: email) }
                                }
                                .font(Font.custom("Nunito-Regular", size: 12))
                                .foregroundColor(.nommieGreen)
                            }
                            HStack(spacing: 10) {
                                Image(systemName: "lock")
                                    .font(.system(size: 14))
                                    .foregroundColor(.nommieBrown.opacity(0.35))
                                    .frame(width: 18)
                                SecureField("••••••••", text: $password)
                                    .font(NommieFont.bodyRegular.font())
                                    .foregroundColor(.nommieBrown)
                                    .focused($focusedField, equals: .password)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                                focusedField == .password ? Color.nommieGreen.opacity(0.5) : Color.nommieBrown.opacity(0.12),
                                lineWidth: 1
                            ))
                        }

                        // Error / info
                        if !authViewModel.errorMessage.isEmpty {
                            Text(authViewModel.errorMessage)
                                .font(NommieFont.caption.font())
                                .foregroundColor(.nommieBlush)
                                .multilineTextAlignment(.center)
                        }
                        if !authViewModel.infoMessage.isEmpty {
                            Text(authViewModel.infoMessage)
                                .font(NommieFont.caption.font())
                                .foregroundColor(.nommieGreen)
                                .multilineTextAlignment(.center)
                        }

                        // Log in
                        Button(action: {
                            guard formIsValid else { return }
                            Task { await authViewModel.signIn(email: email, password: password) }
                        }) {
                            ZStack {
                                if authViewModel.isLoading {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Log in")
                                        .font(NommieFont.bodySemiBold.font())
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(formIsValid ? Color.nommieGreen : Color.nommieGreen.opacity(0.4))
                            )
                        }
                        .disabled(!formIsValid || authViewModel.isLoading)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.nommieBrown.opacity(0.07), lineWidth: 1))
                    .padding(.horizontal, 20)

                    // Create account
                    Button(action: { authViewModel.currentFlow = .signUp }) {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(.nommieBrown.opacity(0.6))
                            Text("Create one")
                                .foregroundColor(.nommieGreen)
                                .font(Font.custom("Nunito-Bold", size: 14))
                        }
                        .font(Font.custom("Nunito-Regular", size: 14))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 56)
                }
            }
        }
    }
}

// MARK: - Animated Card Stack
struct WelcomeCardStack: View {
    @State private var appeared = false
    @State private var floating = false

    var body: some View {
        ZStack {
            // Back card — slides in from the left
            MiniRecipeCard(
                platedBy: "@ubin",
                dish: "Avocado Toast",
                stars: 2, timeLabel: "~15 min",
                cal: "310", pro: "12g", carb: "28g", fat: "18g",
                tags: ["Plant-Based", "Light Meal"],
                imageName: "marcus_plate"
            )
            .rotationEffect(.degrees(-8))
            .offset(x: appeared ? -52 : -160, y: -10)
            .opacity(appeared ? 1 : 0)

            // Front card — slides in from the right
            MiniRecipeCard(
                platedBy: "@you",
                dish: "Grilled Chicken Salad",
                stars: 3, timeLabel: "~45 min",
                cal: "420", pro: "38g", carb: "18g", fat: "14g",
                tags: ["High Protein", "Low Carb"],
                imageName: "demo_plate"
            )
            .rotationEffect(.degrees(5))
            .offset(x: appeared ? 48 : 160, y: 14)
            .opacity(appeared ? 1 : 0)
        }
        // Gentle continuous float after entrance
        .offset(y: floating ? -5 : 5)
        .frame(height: 300)
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.72).delay(0.12)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true).delay(0.65)) {
                floating = true
            }
        }
    }
}

// MARK: - Mini Recipe Card (compact, fixed width)
private struct MiniRecipeCard: View {
    let platedBy: String
    let dish: String
    let stars: Int
    let timeLabel: String
    let cal, pro, carb, fat: String
    let tags: [String]
    let imageName: String

    private let accent = Color(hex: "3A5C44")
    private let bg = Color(hex: "EDE8DC")
    private let cardWidth: CGFloat = 190

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("Plated by: \(platedBy)")
                .font(Font.custom("Caveat-Regular", size: 15))
                .foregroundColor(accent)
                .padding(.horizontal, 12)
                .padding(.top, 11)
                .padding(.bottom, 8)

            // Image area — identical dimensions on both cards
            Group {
                if let img = UIImage(named: imageName) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(accent.opacity(0.08))
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 22))
                                .foregroundColor(accent.opacity(0.22))
                        )
                }
            }
            .frame(width: cardWidth - 24, height: cardWidth - 24)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 9)

            Text(dish)
                .font(Font.custom("Lora-Bold", size: 13))
                .foregroundColor(.nommieBrown)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

            StarsRow(stars: stars, accent: accent, timeLabel: timeLabel)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            // Macro row
            HStack(spacing: 0) {
                MiniMacroCell(value: cal, label: "CAL", accent: accent)
                MiniMacroCell(value: pro, label: "PRO", accent: accent)
                MiniMacroCell(value: carb, label: "CARB", accent: accent)
                MiniMacroCell(value: fat, label: "FAT", accent: accent)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 9)

            // Tags + watermark
            HStack(spacing: 0) {
                HStack(spacing: 5) {
                    ForEach(tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(Font.custom("Nunito-Regular", size: 9))
                            .foregroundColor(accent)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(accent.opacity(0.1)))
                    }
                }
                Spacer()
                Text("nommie")
                    .font(Font.custom("Nunito-Regular", size: 9))
                    .italic()
                    .foregroundColor(.nommieBrown.opacity(0.25))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 11)
        }
        .frame(width: cardWidth)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accent.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
        .shadow(color: .black.opacity(0.11), radius: 14, x: 0, y: 5)
    }
}

private struct MiniMacroCell: View {
    let value, label: String
    let accent: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(Font.custom("Nunito-Bold", size: 11)).foregroundColor(.nommieBrown)
            Text(label).font(Font.custom("Nunito-Regular", size: 8)).foregroundColor(.nommieBrown.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(accent.opacity(0.08))
        .overlay(Rectangle().stroke(accent.opacity(0.12), lineWidth: 0.5))
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthViewModel())
}
