import SwiftUI

struct NommieTextField: View {
    let placeholder: String
    @Binding var text: String
    var label: String? = nil
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    private var promptText: Text {
        Text(placeholder).foregroundColor(.nommieBrown.opacity(0.5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label)
                    .font(Font.custom("Nunito-SemiBold", size: 13))
                    .foregroundColor(.nommieBrown)
                    .padding(.horizontal, NommieTheme.Padding.large)
            }

            Group {
                if isSecure {
                    SecureField("", text: $text, prompt: promptText)
                } else {
                    TextField("", text: $text, prompt: promptText)
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
}
