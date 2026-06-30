import UIKit
import FirebaseStorage

class ImageUploadService {
    private let storage = Storage.storage()
    
    func uploadImage(_ image: UIImage, recipeId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ImageUploadError.compressionFailed
        }
        
        let storageRef = storage.reference()
        let imageRef = storageRef.child("recipe_images/\(recipeId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await imageRef.downloadURL()

        return downloadURL.absoluteString
    }

    func deleteImage(recipeId: String) async throws {
        try await storage.reference().child("recipe_images/\(recipeId).jpg").delete()
    }
}

enum ImageUploadError: LocalizedError {
    case compressionFailed
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Couldn't process your photo. Please try a different image."
        case .uploadFailed:
            return "Couldn't upload your photo. Check your connection and try again."
        }
    }
}
