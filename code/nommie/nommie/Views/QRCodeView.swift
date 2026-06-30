import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let username: String
    @Binding var isPresented: Bool

    var qrImage: UIImage {
        generateQRCode(from: "nommie://user/\(username)")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.nommieBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Your Nommie QR")
                    .font(NommieFont.titleSmall.font())
                    .foregroundColor(.nommieBrown)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 28)
                    .padding(.bottom, 24)

                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.card)
                            .fill(Color.white)
                            .shadow(color: NommieTheme.Shadow.cardColor, radius: NommieTheme.Shadow.cardRadius)
                    )
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("@\(username)")
                    .font(NommieFont.titleSmall.font())
                    .foregroundColor(.nommieBrown)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)

                Spacer()
            }
            .padding(.horizontal, NommieTheme.Padding.large)

            // X button
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.nommieBrown.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.nommieBrown.opacity(0.08)))
            }
            .padding(.top, NommieTheme.Padding.large)
            .padding(.trailing, NommieTheme.Padding.large)
        }
        .presentationDetents([.fraction(0.6)])
        .onAppear { NommieAnalytics.qrProfileViewed() }
    }

    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }

        // Color the QR green (foreground) with transparent background
        let colorFilter = CIFilter(name: "CIFalseColor")!
        colorFilter.setValue(outputImage, forKey: kCIInputImageKey)
        colorFilter.setValue(CIColor(color: UIColor(Color.nommieGreen)), forKey: "inputColor0")
        colorFilter.setValue(CIColor.clear, forKey: "inputColor1")
        guard let coloredOutput = colorFilter.outputImage else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }

        let scaled = coloredOutput.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    QRCodeView(username: "testuser", isPresented: .constant(true))
}
