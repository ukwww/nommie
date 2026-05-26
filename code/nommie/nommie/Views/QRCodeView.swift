import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let username: String
    @Binding var isPresented: Bool
    
    var qrImage: UIImage {
        generateQRCode(from: "nommie://user/\(username)")
    }
    
    var body: some View {
        ZStack {
            Color.nommieBackground
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.nommieBrown.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                Text("Your Nommie Code")
                    .font(NommieFont.titleSmall.font())
                    .foregroundColor(.nommieBrown)
                
                // QR Code
                VStack(spacing: 20) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.card)
                                .fill(Color.white)
                                .shadow(
                                    color: NommieTheme.Shadow.cardColor,
                                    radius: NommieTheme.Shadow.cardRadius
                                )
                        )
                    
                    Text("@\(username)")
                        .font(NommieFont.titleSmall.font())
                        .foregroundColor(.nommieBrown)
                    
                    Text("Scan to find me on Nommie")
                        .font(NommieFont.caption.font())
                        .foregroundColor(.nommieBrown.opacity(0.5))
                }
                
                NommieButton(title: "Close", style: .secondary) {
                    isPresented = false
                }
                .padding(.bottom, 32)
                
                Spacer()
            }
            .padding(.horizontal, NommieTheme.Padding.large)
        }
        .presentationDetents([.large])
    }
    
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}

#Preview {
    QRCodeView(username: "testuser", isPresented: .constant(true))
}
