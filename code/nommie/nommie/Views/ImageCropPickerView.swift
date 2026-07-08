import SwiftUI
import UIKit

// Wraps UIImagePickerController with allowsEditing = true, which gives the
// native iOS square crop + zoom/pan UI before the user confirms the photo.
struct ImageCropPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImageCropPickerView

        init(_ parent: ImageCropPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Prefer the square-cropped edited image; fall back to original.
            // The edit UI can silently return nil on newer iOS, so we always
            // normalize to a square ourselves — a non-square image overflows
            // the Step 1 preview and blocks all touches.
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            parent.selectedImage = image.map { Self.squareCropped($0) }
            parent.onDismiss()
        }

        // Center-crops to a square and caps resolution (smaller, faster uploads).
        static func squareCropped(_ image: UIImage, maxSide: CGFloat = 2400) -> UIImage {
            let w = image.size.width
            let h = image.size.height
            let side = min(w, h)
            guard side > 0 else { return image }
            if abs(w - h) < 1 && side <= maxSide { return image }

            let target = min(side, maxSide)
            let scale = target / side
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: target, height: target))
            return renderer.image { _ in
                image.draw(in: CGRect(
                    x: -((w - side) / 2) * scale,
                    y: -((h - side) / 2) * scale,
                    width: w * scale,
                    height: h * scale
                ))
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss()
        }
    }
}
