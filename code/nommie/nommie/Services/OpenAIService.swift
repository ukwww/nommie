import Foundation
import FirebaseAuth

// Calls the AI Firebase Cloud Functions via HTTP.
// The OpenAI key lives securely in Firebase Secrets — never in the app binary.
class OpenAIService {
    private let functionURL = "https://us-central1-nommie-bc531.cloudfunctions.net/estimateMacros"
    private let extractURL = "https://us-central1-nommie-bc531.cloudfunctions.net/extractIngredients"

    /// Drafts an ingredient list from written cooking steps. Quantities come back
    /// empty unless the steps explicitly stated an amount.
    func extractIngredients(steps: [String], dishName: String = "") async throws -> [Ingredient] {
        let stepsText = steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        guard !stepsText.isEmpty else { throw OpenAIError.emptySteps }

        guard let idToken = try await Auth.auth().currentUser?.getIDToken() else {
            throw OpenAIError.notAuthenticated
        }
        guard let url = URL(string: extractURL) else { throw OpenAIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": [
            "steps": stepsText,
            "dishName": dishName
        ]])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenAIError.requestFailed
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let list = result["ingredients"] as? [[String: Any]] else {
            throw OpenAIError.invalidResponse
        }

        return list.compactMap { item in
            guard let name = item["name"] as? String, !name.isEmpty else { return nil }
            let quantity = item["quantity"] as? String ?? ""
            // Mark provenance: the name is always AI-drafted; the quantity only
            // glows as AI if the model actually found one in the steps.
            return Ingredient(name: name, quantity: quantity, aiName: true, aiQuantity: !quantity.isEmpty)
        }
    }

    func estimateMacros(ingredients: [Ingredient], dishName: String = "", servings: Int = 1) async throws -> Macros {
        let ingredientList = ingredients
            .filter { !$0.name.isEmpty }
            .map { "\($0.quantity) \($0.name)".trimmingCharacters(in: .whitespaces) }
            .joined(separator: ", ")

        guard !ingredientList.isEmpty else {
            throw OpenAIError.emptyIngredients
        }

        guard let idToken = try await Auth.auth().currentUser?.getIDToken() else {
            throw OpenAIError.notAuthenticated
        }

        guard let url = URL(string: functionURL) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": [
            "ingredients": ingredientList,
            "dishName": dishName,
            "servings": servings
        ]])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenAIError.requestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any] else {
            throw OpenAIError.invalidResponse
        }

        let macros = Macros(
            calories: result["calories"] as? Int ?? 0,
            protein: result["protein"] as? Int ?? 0,
            carbs: result["carbs"] as? Int ?? 0,
            fat: result["fat"] as? Int ?? 0,
            fiber: result["fiber"] as? Int ?? 0,
            sugar: result["sugar"] as? Int ?? 0
        )

        return macros
    }
}

enum OpenAIError: LocalizedError {
    case emptyIngredients
    case emptySteps
    case notAuthenticated
    case invalidURL
    case requestFailed
    case invalidResponse
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .emptyIngredients:  return "Please add at least one ingredient before estimating macros."
        case .emptySteps:        return "Write at least one step so we can draft your ingredients."
        case .notAuthenticated:  return "Please sign in to use macro estimation."
        case .invalidURL:        return "Something went wrong. Please try again."
        case .requestFailed:     return "Couldn't reach the macro estimator. Check your connection and try again."
        case .invalidResponse:   return "Received an unexpected response. Please try again."
        case .parsingFailed:     return "Couldn't read the macro estimate. Please try again."
        }
    }
}
