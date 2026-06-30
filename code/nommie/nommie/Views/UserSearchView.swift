import SwiftUI
import Combine

struct UserSearchView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var results: [NommieUser] = []
    @State private var isSearching = false
    @State private var selectedUsername: String? = nil
    @State private var cancellable: AnyCancellable? = nil
    @FocusState private var isFocused: Bool

    private let userService = UserService()

    var body: some View {
        ZStack {
            Color.nommieBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Find cooks")
                        .font(Font.custom("Lora-SemiBold", size: 20))
                        .foregroundColor(.nommieBrown)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.nommieBrown.opacity(0.5))
                            .frame(width: 30, height: 30)
                            .background(Circle().strokeBorder(Color.nommieBrown.opacity(0.2), lineWidth: 1.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(.nommieBrown.opacity(0.4))
                    TextField("Search by username", text: $query)
                        .font(NommieFont.bodyRegular.font())
                        .foregroundColor(.nommieBrown)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($isFocused)
                        .onChange(of: query) { _, newValue in
                            let cleaned = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            if cleaned != newValue {
                                query = cleaned
                                return
                            }
                            debounceSearch(cleaned)
                        }
                    if isSearching {
                        ProgressView().scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.nommieBrown.opacity(0.12), lineWidth: 1))
                .padding(.horizontal, 20)

                // Results
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { user in
                            Button(action: { selectedUsername = user.username }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(CardPalettes.paletteForUser(user.id).accent.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                        Text(String(user.username.prefix(1)).uppercased())
                                            .font(Font.custom("Nunito-Bold", size: 16))
                                            .foregroundColor(CardPalettes.paletteForUser(user.id).accent)
                                    }
                                    Text("@\(user.username)")
                                        .font(Font.custom("Nunito-SemiBold", size: 16))
                                        .foregroundColor(.nommieBrown)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13))
                                        .foregroundColor(.nommieBrown.opacity(0.3))
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            Divider().padding(.leading, 72)
                        }

                        if !query.isEmpty && results.isEmpty && !isSearching {
                            Text("No cooks found for \"\(query)\"")
                                .font(Font.custom("Nunito-Regular", size: 14))
                                .foregroundColor(.nommieBrown.opacity(0.4))
                                .padding(.top, 40)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .fullScreenCover(item: Binding(
            get: { selectedUsername.map { IdentifiableUsername(value: $0) } },
            set: { selectedUsername = $0?.value }
        )) { wrapper in
            OtherUserProfileView(username: wrapper.value)
                .environmentObject(authViewModel)
        }
        .onAppear { isFocused = true }
    }

    private func debounceSearch(_ text: String) {
        cancellable?.cancel()
        guard !text.isEmpty else { results = []; return }
        isSearching = true
        cancellable = Just(text)
            .delay(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { q in
                Task {
                    let found = (try? await userService.searchUsers(prefix: q)) ?? []
                    await MainActor.run {
                        // Don't list yourself
                        self.results = found.filter { $0.id != authViewModel.currentNommieUser?.id }
                        self.isSearching = false
                    }
                }
            }
    }
}

private struct IdentifiableUsername: Identifiable {
    let id = UUID()
    let value: String
}

#Preview {
    UserSearchView().environmentObject(AuthViewModel())
}
