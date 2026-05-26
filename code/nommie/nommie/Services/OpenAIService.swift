import Foundation

class OpenAIService {
    private let apiKey = Config.openAIKey
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    func estimateMacros(ingredients: [Ingredient]) async throws -> (macros: Macros, tags: [String]) {
        let ingredientList = ingredients
            .filter { !$0.name.isEmpty }
            .map { "\($0.quantity) \($0.name)" }
            .joined(separator: ", ")
        
        guard !ingredientList.isEmpty else {
            throw OpenAIError.emptyIngredients
        }
        
        let prompt = """
        Given these ingredients: \(ingredientList). \
        Estimate the total nutritional macros for this dish. \
        Return ONLY a JSON object with fields: \
        calories (Int), protein (Int), carbs (Int), fat (Int), \
        tags (Array of strings from this list: High Protein, High Fiber, \
        Low Carb, Comfort Food, Light Meal, High Calorie, Plant-Based, \
        Baked Good, Drink/Cocktail). No explanation, just the JSON.
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 200
        ]
        
        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.requestFailed
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }
        
        let cleanedContent = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let contentData = cleanedContent.data(using: .utf8),
              let macroJSON = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            throw OpenAIError.parsingFailed
        }
        
        let macros = Macros(
            calories: macroJSON["calories"] as? Int ?? 0,
            protein: macroJSON["protein"] as? Int ?? 0,
            carbs: macroJSON["carbs"] as? Int ?? 0,
            fat: macroJSON["fat"] as? Int ?? 0
        )
        
        let tags = macroJSON["tags"] as? [String] ?? []
        
        return (macros: macros, tags: tags)
    }
}

enum OpenAIError: LocalizedError {
    case emptyIngredients
    case invalidURL
    case requestFailed
    case invalidResponse
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .emptyIngredients:
            return "Please add at least one ingredient before estimating macros."
        case .invalidURL:
            return "Something went wrong. Please try again."
        case .requestFailed:
            return "Couldn't reach the macro estimator. Check your connection and try again."
        case .invalidResponse:
            return "Received an unexpected response. Please try again."
        case .parsingFailed:
            return "Couldn't read the macro estimate. Please try again."
        }
    }
}
