import SwiftUI

// Edit Profile — the home for identity changes: profile photo and a short bio
// (30 characters, emoji welcome).
struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var isPresented: Bool

    @State private var bio: String = ""
    @State private var username: String = ""
    @State private var errorText: String = ""
    @State private var showingAvatarPicker = false
    @State private var avatarPickerImage: UIImage? = nil
    @State private var isSaving = false
    @FocusState private var focusedField: String?

    private let bioLimit = 30

    // 30-day username cooldown
    private var usernameLockedUntil: Date? {
        guard let last = authViewModel.currentNommieUser?.usernameChangedAt,
              let next = Calendar.current.date(byAdding: .day, value: 30, to: last),
              Date() < next else { return nil }
        return next
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.nommieBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Edit Profile")
                    .font(Font.custom("Lora-SemiBold", size: 20))
                    .foregroundColor(.nommieBrown)
                    .padding(.top, 24)
                    .padding(.bottom, 26)

                // Avatar with camera badge
                Button(action: { showingAvatarPicker = true }) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(
                            userId: authViewModel.currentNommieUser?.id ?? "",
                            username: authViewModel.currentNommieUser?.username ?? "",
                            photoURL: authViewModel.currentNommieUser?.photoURL,
                            size: 124
                        )
                        .overlay {
                            if authViewModel.isUploadingAvatar {
                                ZStack {
                                    Circle().fill(Color.black.opacity(0.35))
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                            }
                        }

                        ZStack {
                            Circle()
                                .fill(Color.nommieGreen)
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(Color.nommieBackground, lineWidth: 2.5))
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                        }
                        .offset(x: 2, y: 2)
                    }
                }
                .padding(.bottom, 8)

                Text("Change photo")
                    .font(Font.custom("Nunito-Regular", size: 13))
                    .foregroundColor(.nommieGreen)
                    .padding(.bottom, 28)

                VStack(alignment: .leading, spacing: 20) {
                    // Username
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(Font.custom("Nunito-SemiBold", size: 14))
                            .foregroundColor(.nommieBrown)

                        HStack(spacing: 2) {
                            Text("@")
                                .font(Font.custom("Nunito-Regular", size: 15))
                                .foregroundColor(.nommieBrown.opacity(0.45))
                            TextField("", text: $username)
                                .font(Font.custom("Nunito-Regular", size: 15))
                                .foregroundColor(usernameLockedUntil == nil ? .nommieBrown : .nommieBrown.opacity(0.4))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusedField, equals: "username")
                                .disabled(usernameLockedUntil != nil)
                                .onChange(of: username) { _, newValue in
                                    let cleaned = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                    if cleaned != newValue { username = cleaned }
                                }
                        }
                        .padding(NommieTheme.Padding.medium)
                        .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).fill(Color.white.opacity(usernameLockedUntil == nil ? 0.7 : 0.4)))
                        .overlay(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1))

                        if let lockedUntil = usernameLockedUntil {
                            Label("Locked until \(lockedUntil.formatted(date: .abbreviated, time: .omitted))", systemImage: "lock")
                                .font(Font.custom("Nunito-Regular", size: 11))
                                .foregroundColor(.nommieBrown.opacity(0.45))
                        } else {
                            Text("Changing your username locks it for 30 days.")
                                .font(Font.custom("Nunito-Regular", size: 11))
                                .foregroundColor(.nommieBrown.opacity(0.45))
                        }
                    }

                    // Bio
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Bio")
                                .font(Font.custom("Nunito-SemiBold", size: 14))
                                .foregroundColor(.nommieBrown)
                            Spacer()
                            Text("\(bio.count)/\(bioLimit)")
                                .font(Font.custom("Nunito-Regular", size: 12))
                                .foregroundColor(bio.count >= bioLimit ? .nommieBlush : .nommieBrown.opacity(0.4))
                        }

                        TextField("", text: $bio, prompt: Text("A little about your kitchen 🍳").foregroundColor(.nommieBrown.opacity(0.4)))
                            .font(Font.custom("Nunito-Regular", size: 15))
                            .foregroundColor(.nommieBrown)
                            .focused($focusedField, equals: "bio")
                            .padding(NommieTheme.Padding.medium)
                            .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).fill(Color.white.opacity(0.7)))
                            .overlay(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1))
                            .onChange(of: bio) { _, newValue in
                                if newValue.count > bioLimit {
                                    bio = String(newValue.prefix(bioLimit))
                                }
                            }
                    }

                    if !errorText.isEmpty {
                        Text(errorText)
                            .font(Font.custom("Nunito-Regular", size: 12))
                            .foregroundColor(.nommieBlush)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Save
                Button(action: save) {
                    ZStack {
                        if isSaving {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save")
                                .font(Font.custom("Nunito-SemiBold", size: 16))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.nommieGreen))
                }
                .disabled(isSaving)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            // X button
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.nommieBrown.opacity(0.5))
                    .frame(width: 30, height: 30)
                    .background(Circle().strokeBorder(Color.nommieBrown.opacity(0.2), lineWidth: 1.5))
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            bio = authViewModel.currentNommieUser?.bio ?? ""
            username = authViewModel.currentNommieUser?.username ?? ""
        }
        .fullScreenCover(isPresented: $showingAvatarPicker) {
            ImageCropPickerView(selectedImage: $avatarPickerImage) {
                showingAvatarPicker = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: avatarPickerImage) { _, newImage in
            guard let newImage else { return }
            avatarPickerImage = nil
            Task { await authViewModel.updateProfilePhoto(newImage) }
        }
    }

    private func save() {
        isSaving = true
        errorText = ""
        focusedField = nil
        Task {
            // Username first (it can fail on cooldown/availability), then bio
            var ok = true
            if username != authViewModel.currentNommieUser?.username {
                ok = await authViewModel.updateUsername(username)
            }
            if ok {
                ok = await authViewModel.updateBio(bio)
            }
            await MainActor.run {
                isSaving = false
                if ok {
                    isPresented = false
                } else {
                    errorText = authViewModel.errorMessage
                }
            }
        }
    }
}

#Preview {
    EditProfileView(isPresented: .constant(true))
        .environmentObject(AuthViewModel())
}
