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
    @Published var servings: Int = 1
    @Published var prepTimeStars: Int = 3
    @Published var isEstimatingMacros: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String = ""
    @Published var isComplete: Bool = false
    private(set) var usedAIEstimate: Bool = false
    private(set) var replateMeta: ReplateMeta? = nil
    private(set) var isEditMode: Bool = false
    private(set) var editingRecipeId: String? = nil
    private(set) var editingImageURL: String = ""

    private let openAIService = OpenAIService()
    private let imageUploadService = ImageUploadService()
    private let db = Firestore.firestore()

    var canProceedFromStep1: Bool {
        selectedImage != nil
    }

    var canProceedFromStep2: Bool {
        !dishName.isEmpty && ingredients.contains { !$0.name.isEmpty }
    }

    func configureForEdit(recipe: Recipe) {
        isEditMode = true
        editingRecipeId = recipe.id
        editingImageURL = recipe.imageURL
        dishName = recipe.dishName
        ingredients = recipe.ingredients.isEmpty ? [Ingredient()] : recipe.ingredients
        notes = recipe.notes
        macros = recipe.macros
        tags = recipe.tags
        servings = recipe.servings
        prepTimeStars = recipe.prepTimeStars
        currentStep = 2
    }

    func configureForReplate(source: Recipe) {
        replateMeta = ReplateMeta(
            originalRecipeId: source.id,
            originalUserId: source.userId,
            originalUsername: source.username,
            originalDishName: source.dishName
        )
        dishName = source.dishName
        ingredients = source.ingredients.isEmpty ? [Ingredient()] : source.ingredients
        notes = source.notes
        macros = source.macros
        tags = source.tags
        servings = source.servings
        prepTimeStars = source.prepTimeStars
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

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    func estimateMacros() async {
        await MainActor.run {
            isEstimatingMacros = true
            errorMessage = ""
        }
        NommieAnalytics.macroEstimateTapped()
        do {
            let result = try await openAIService.estimateMacros(ingredients: ingredients, dishName: dishName, servings: servings)
            await MainActor.run {
                self.macros = result
                self.isEstimatingMacros = false
                self.usedAIEstimate = true
            }
            NommieAnalytics.macroEstimateSuccess(ingredientCount: ingredients.filter { !$0.name.isEmpty }.count)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isEstimatingMacros = false
            }
            NommieAnalytics.macroEstimateFailed()
        }
    }

    func saveRecipe(currentUser: NommieUser) async {
        await MainActor.run {
            isSaving = true
            errorMessage = ""
        }

        let filteredIngredients = ingredients.filter { !$0.name.isEmpty }

        do {
            if isEditMode, let recipeId = editingRecipeId {
                let updatedData: [String: Any] = [
                    "dishName": dishName,
                    "ingredients": filteredIngredients.map { ["name": $0.name, "quantity": $0.quantity] },
                    "notes": notes,
                    "macros": [
                        "calories": macros.calories,
                        "protein": macros.protein,
                        "carbs": macros.carbs,
                        "fat": macros.fat,
                        "fiber": macros.fiber,
                        "sugar": macros.sugar
                    ],
                    "tags": tags,
                    "servings": max(1, servings),
                    "prepTimeStars": prepTimeStars
                ]
                try await db.collection("recipes").document(recipeId).updateData(updatedData)
            } else {
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
                    ingredients: filteredIngredients,
                    notes: notes,
                    macros: macros,
                    tags: tags,
                    servings: max(1, servings),
                    prepTimeStars: prepTimeStars,
                    replateMeta: replateMeta
                )

                try await db.collection("recipes")
                    .document(recipeId)
                    .setData(recipe.toDictionary())

                NommieAnalytics.cardCreated(
                    ingredientCount: filteredIngredients.count,
                    hasNotes: !notes.isEmpty,
                    usedAIEstimate: usedAIEstimate,
                    isReplate: replateMeta != nil
                )
            }

            await MainActor.run {
                self.isSaving = false
                self.isComplete = true
                NotificationCenter.default.post(name: .profileNeedsRefresh, object: nil)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't save your recipe. Please try again."
                self.isSaving = false
            }
        }
    }
}
