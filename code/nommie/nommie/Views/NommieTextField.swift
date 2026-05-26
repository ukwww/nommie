import SwiftUI

struct NommieTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
        .font(NommieFont.bodyRegular.font())
        .foregroundColor(.nommieBrown)
        .padding(NommieTheme.Padding.medium)
        .background(
            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium)
                .stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, NommieTheme.Padding.large)
    }
}
