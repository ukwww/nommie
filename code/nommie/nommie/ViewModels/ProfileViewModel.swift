import SwiftUI
import Combine
import FirebaseFirestore

class ProfileViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    private let db = Firestore.firestore()
    private let userService = UserService()
    
    func fetchRecipes(for userID: String) async {
        await MainActor.run { isLoading = true }
        
        do {
            let snapshot = try await db.collection("recipes")
                .whereField("userId", isEqualTo: userID)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            let fetched = snapshot.documents.compactMap { doc in
                Recipe(from: doc.data())
            }
            
            await MainActor.run {
                self.recipes = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't load your recipes."
                self.isLoading = false
            }
        }
    }
    
    func updateTheme(theme: String, for userID: String) async {
        do {
            try await db.collection("users")
                .document(userID)
                .updateData(["selectedTheme": theme])
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't update your theme."
            }
        }
    }
}
