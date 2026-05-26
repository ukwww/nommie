import Foundation
import FirebaseFirestore

struct Ingredient: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var quantity: String
    
    init(name: String = "", quantity: String = "") {
        self.name = name
        self.quantity = quantity
    }
}

struct Macros: Codable {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    
    init(calories: Int = 0, protein: Int = 0, carbs: Int = 0, fat: Int = 0) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

struct Recipe: Identifiable, Codable {
    var id: String
    var userId: String
    var username: String
    var dishName: String
    var imageURL: String
    var ingredients: [Ingredient]
    var notes: String
    var macros: Macros
    var tags: [String]
    var theme: String
    var createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        userId: String = "",
        username: String = "",
        dishName: String = "",
        imageURL: String = "",
        ingredients: [Ingredient] = [],
        notes: String = "",
        macros: Macros = Macros(),
        tags: [String] = [],
        theme: String = "classic",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.dishName = dishName
        self.imageURL = imageURL
        self.ingredients = ingredients
        self.notes = notes
        self.macros = macros
        self.tags = tags
        self.theme = theme
        self.createdAt = createdAt
    }
    
    init?(from dictionary: [String: Any]) {
        guard
            let id = dictionary["id"] as? String,
            let userId = dictionary["userId"] as? String,
            let username = dictionary["username"] as? String,
            let dishName = dictionary["dishName"] as? String,
            let imageURL = dictionary["imageURL"] as? String,
            let theme = dictionary["theme"] as? String,
            let timestamp = dictionary["createdAt"] as? Timestamp
        else { return nil }
        
        self.id = id
        self.userId = userId
        self.username = username
        self.dishName = dishName
        self.imageURL = imageURL
        self.theme = theme
        self.createdAt = timestamp.dateValue()
        self.notes = dictionary["notes"] as? String ?? ""
        self.tags = dictionary["tags"] as? [String] ?? []
        
        if let macrosDict = dictionary["macros"] as? [String: Any] {
            self.macros = Macros(
                calories: macrosDict["calories"] as? Int ?? 0,
                protein: macrosDict["protein"] as? Int ?? 0,
                carbs: macrosDict["carbs"] as? Int ?? 0,
                fat: macrosDict["fat"] as? Int ?? 0
            )
        } else {
            self.macros = Macros()
        }
        
        if let ingredientsArray = dictionary["ingredients"] as? [[String: Any]] {
            self.ingredients = ingredientsArray.compactMap { dict in
                guard let name = dict["name"] as? String,
                      let quantity = dict["quantity"] as? String else { return nil }
                return Ingredient(name: name, quantity: quantity)
            }
        } else {
            self.ingredients = []
        }
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "username": username,
            "dishName": dishName,
            "imageURL": imageURL,
            "notes": notes,
            "tags": tags,
            "theme": theme,
            "createdAt": Timestamp(date: createdAt),
            "macros": [
                "calories": macros.calories,
                "protein": macros.protein,
                "carbs": macros.carbs,
                "fat": macros.fat
            ],
            "ingredients": ingredients.map { [
                "name": $0.name,
                "quantity": $0.quantity
            ]}
        ]
    }
}
