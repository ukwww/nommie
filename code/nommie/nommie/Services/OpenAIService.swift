import Foundation
import FirebaseAuth

// Calls the estimateMacros Firebase Cloud Function via HTTP.
// The OpenAI key lives securely in Firebase Secrets — never in the app binary.
class OpenAIService {
    private let functionURL = "https://us-central1-nommie-bc531.cloudfunctions.net/estimateMacros"

    func estimateMacros(ingredients: [Ingredient], dishName: String = "", servings: Int = 1) async throws -> (macros: Macros, tags: [String]) {
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
            fat: result["fat"] as? Int ?? 0
        )
        let tags = result["tags"] as? [String] ?? []

        return (macros: macros, tags: tags)
    }
}

enum OpenAIError: LocalizedError {
    case emptyIngredients
    case notAuthenticated
    case invalidURL
    case requestFailed
    case invalidResponse
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .emptyIngredients:  return "Please add at least one ingredient before estimating macros."
        case .notAuthenticated:  return "Please sign in to use macro estimation."
        case .invalidURL:        return "Something went wrong. Please try again."
        case .requestFailed:     return "Couldn't reach the macro estimator. Check your connection and try again."
        case .invalidResponse:   return "Received an unexpected response. Please try again."
        case .parsingFailed:     return "Couldn't read the macro estimate. Please try again."
        }
    }
}
