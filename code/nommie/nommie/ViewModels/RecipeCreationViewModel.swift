import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

class RecipeCreationViewModel: ObservableObject {
    @Published var currentStep: Int = 1
    @Published var selectedImage: UIImage? = nil
    @Published var dishName: String = ""
    @Published var ingredients: [Ingredient] = [Ingredient()]
    @Published var notes: String = ""
    @Published var macros: Macros = Macros()
    @Published var tags: [String] = []
    @Published var isEstimatingMacros: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String = ""
    @Published var isComplete: Bool = false
    
    private let openAIService = OpenAIService()
    private let imageUploadService = ImageUploadService()
    private let db = Firestore.firestore()
    
    var canProceedFromStep1: Bool {
        selectedImage != nil
    }
    
    var canProceedFromStep2: Bool {
        !dishName.isEmpty && ingredients.contains { !$0.name.isEmpty }
    }
    
    func addIngredient() {
        ingredients.append(Ingredient())
    }
    
    func removeIngredient(at offsets: IndexSet) {
        guard ingredients.count > 1 else { return }
        ingredients.remove(atOffsets: offsets)
    }
    
    func removeIngredient(id: String) {
        guard ingredients.count > 1 else { return }
        ingredients.removeAll { $0.id == id }
    }
    
    func estimateMacros() async {
        await MainActor.run {
            isEstimatingMacros = true
            errorMessage = ""
        }
        do {
            let result = try await openAIService.estimateMacros(ingredients: ingredients)
            await MainActor.run {
                self.macros = result.macros
                self.tags = result.tags
                self.isEstimatingMacros = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isEstimatingMacros = false
            }
        }
    }
    
    func saveRecipe(currentUser: NommieUser) async {
        await MainActor.run {
            isSaving = true
            errorMessage = ""
        }
        
        do {
            guard let image = selectedImage else {
                await MainActor.run {
                    errorMessage = "Please select a photo for your recipe."
                    isSaving = false
                }
                return
            }
            
            let recipeId = UUID().uuidString
            let imageURL = try await imageUploadService.uploadImage(image, recipeId: recipeId)
            
            let recipe = Recipe(
                id: recipeId,
                userId: currentUser.id,
                username: currentUser.username,
                dishName: dishName,
                imageURL: imageURL,
                ingredients: ingredients.filter { !$0.name.isEmpty },
                notes: notes,
                macros: macros,
                tags: tags,
                theme: currentUser.selectedTheme
            )
            
            try await db.collection("recipes")
                .document(recipeId)
                .setData(recipe.toDictionary())
            
            await MainActor.run {
                self.isSaving = false
                self.isComplete = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't save your recipe. Please try again."
                self.isSaving = false
            }
        }
    }
}
