import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// One row in the steps editor. Session-only identity so rows keep focus
// stable while the user types, reorders, or deletes.
struct StepEntry: Identifiable {
    let id: String = UUID().uuidString
    var text: String = ""
}

class RecipeCreationViewModel: ObservableObject {
    @Published var currentStep: Int = 1
    @Published var selectedImage: UIImage? = nil
    @Published var dishName: String = ""
    @Published var stepEntries: [StepEntry] = [StepEntry()]
    @Published var ingredients: [Ingredient] = [Ingredient()]
    @Published var notes: String = ""
    @Published var macros: Macros = Macros()
    @Published var tags: [String] = []
    @Published var servings: Int = 1
    @Published var prepTimeStars: Int = 3
    @Published var isEstimatingMacros: Bool = false
    @Published var isExtractingIngredients: Bool = false
    @Published var ingredientsConfirmed: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String = ""
    @Published var isComplete: Bool = false
    private(set) var usedAIEstimate: Bool = false
    private(set) var didAutoExtract: Bool = false
    private(set) var replateMeta: ReplateMeta? = nil
    private(set) var isEditMode: Bool = false
    private(set) var editingRecipeId: String? = nil
    private(set) var editingImageURL: String = ""

    var cleanedSteps: [String] {
        stepEntries
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private let openAIService = OpenAIService()
    private let imageUploadService = ImageUploadService()
    private let db = Firestore.firestore()

    var canProceedFromStep1: Bool {
        selectedImage != nil
    }

    var canProceedFromStep2: Bool {
        // Fresh creations are steps-first. Edits and replates of older recipes
        // may predate steps, so they aren't blocked on writing them.
        guard !dishName.isEmpty else { return false }
        return !cleanedSteps.isEmpty || isEditMode || replateMeta != nil
    }

    var canProceedFromStep3: Bool {
        ingredientsConfirmed && ingredients.contains { !$0.name.isEmpty }
    }

    func configureForEdit(recipe: Recipe) {
        isEditMode = true
        editingRecipeId = recipe.id
        editingImageURL = recipe.imageURL
        dishName = recipe.dishName
        stepEntries = recipe.steps.isEmpty ? [StepEntry()] : recipe.steps.map { StepEntry(text: $0) }
        ingredients = recipe.ingredients.isEmpty ? [Ingredient()] : recipe.ingredients
        // Existing ingredients are the user's own data — no AI glow, no re-confirm.
        ingredientsConfirmed = true
        notes = recipe.notes
        macros = recipe.macros
        tags = recipe.tags
        servings = recipe.servings
        // Normalize legacy 5-star values into the 4-quarter clock scale
        prepTimeStars = min(max(recipe.prepTimeStars, 1), 4)
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
        stepEntries = source.steps.isEmpty ? [StepEntry()] : source.steps.map { StepEntry(text: $0) }
        ingredients = source.ingredients.isEmpty ? [Ingredient()] : source.ingredients
        // Replated ingredients come from the original recipe — already human-made.
        ingredientsConfirmed = true
        notes = source.notes
        macros = source.macros
        tags = source.tags
        servings = source.servings
        prepTimeStars = min(max(source.prepTimeStars, 1), 4)
    }

    // MARK: - Steps editor

    func addStep(focusAfter: ((String) -> Void)? = nil) {
        let entry = StepEntry()
        stepEntries.append(entry)
        focusAfter?(entry.id)
    }

    /// Inserts a new step right after the given one (return-key auto-advance).
    /// Returns the new entry's id so the view can move focus to it.
    func insertStep(after id: String) -> String {
        let entry = StepEntry()
        if let idx = stepEntries.firstIndex(where: { $0.id == id }) {
            stepEntries.insert(entry, at: idx + 1)
        } else {
            stepEntries.append(entry)
        }
        return entry.id
    }

    func removeStep(id: String) {
        guard stepEntries.count > 1 else { return }
        stepEntries.removeAll { $0.id == id }
    }

    // MARK: - AI ingredient draft

    /// Auto-runs once when arriving at the ingredients step of a fresh creation.
    /// Edits and replates already carry human-made ingredient lists.
    func extractIngredientsIfNeeded() async {
        guard !isEditMode, replateMeta == nil, !didAutoExtract, !cleanedSteps.isEmpty else { return }
        didAutoExtract = true
        await runExtraction()
    }

    /// Manual "re-draft from steps" — replaces the current list with a fresh draft.
    func redraftIngredients() async {
        await runExtraction()
    }

    private func runExtraction() async {
        await MainActor.run {
            isExtractingIngredients = true
            errorMessage = ""
        }
        do {
            let drafted = try await openAIService.extractIngredients(steps: cleanedSteps, dishName: dishName)
            await MainActor.run {
                if drafted.isEmpty {
                    self.errorMessage = "Couldn't find ingredients in your steps — add them below."
                    if self.ingredients.isEmpty { self.ingredients = [Ingredient()] }
                } else {
                    self.ingredients = drafted
                }
                self.ingredientsConfirmed = false
                self.isExtractingIngredients = false
            }
            NommieAnalytics.ingredientsDrafted(count: drafted.count)
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't draft ingredients — add them manually below."
                if self.ingredients.isEmpty { self.ingredients = [Ingredient()] }
                self.isExtractingIngredients = false
            }
            NommieAnalytics.ingredientsDraftFailed()
        }
    }

    /// The intentionality gate: blesses the whole list, clearing every AI glow.
    /// Rows stay editable afterwards.
    func confirmIngredients() {
        for i in ingredients.indices {
            ingredients[i].aiName = false
            ingredients[i].aiQuantity = false
        }
        ingredientsConfirmed = true
        NommieAnalytics.ingredientsConfirmed(count: ingredients.filter { !$0.name.isEmpty }.count)
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
                    "steps": cleanedSteps,
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
                    steps: cleanedSteps,
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
                if isEditMode {
                    NotificationCenter.default.post(name: .recipeEdited, object: nil)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Couldn't save your recipe. Please try again."
                self.isSaving = false
            }
        }
    }
}
