import Foundation
import FirebaseFirestore

struct Ingredient: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var quantity: String

    // Creation-session provenance: true while the value came from the AI draft
    // and hasn't been touched or confirmed by the user. Never persisted.
    var aiName: Bool = false
    var aiQuantity: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id, name, quantity
    }

    init(name: String = "", quantity: String = "", aiName: Bool = false, aiQuantity: Bool = false) {
        self.name = name
        self.quantity = quantity
        self.aiName = aiName
        self.aiQuantity = aiQuantity
    }
}

struct Macros: Codable {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var fiber: Int
    var sugar: Int

    init(calories: Int = 0, protein: Int = 0, carbs: Int = 0, fat: Int = 0, fiber: Int = 0, sugar: Int = 0) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
    }
}

struct ReplateMeta: Codable {
    var originalRecipeId: String
    var originalUserId: String
    var originalUsername: String
    var originalDishName: String
}

// A recent liker of a recipe — denormalized onto the recipe doc by cloud
// triggers so the feed can render "@user and 3 others liked" without queries.
struct RecipeLiker: Codable, Equatable {
    var userId: String
    var username: String
}

// The most recent top-level comments, denormalized by triggers so feed cards
// can preview them Instagram-style without extra queries.
struct RecipePreviewComment: Codable, Hashable {
    var userId: String
    var username: String
    var text: String
}

struct Recipe: Identifiable, Codable {
    var id: String
    var userId: String
    var username: String
    var dishName: String
    var imageURL: String
    var ingredients: [Ingredient]
    var steps: [String]
    var notes: String
    var macros: Macros
    var tags: [String]
    var servings: Int
    var prepTimeStars: Int
    var replateMeta: ReplateMeta?
    var createdAt: Date
    // Social counters — written only by cloud function triggers, never the client.
    var likeCount: Int
    var saveCount: Int
    var commentCount: Int
    var replateCount: Int
    var recentLikers: [RecipeLiker]
    var recentComments: [RecipePreviewComment]

    var isReplate: Bool { replateMeta != nil }

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        username: String = "",
        dishName: String = "",
        imageURL: String = "",
        ingredients: [Ingredient] = [],
        steps: [String] = [],
        notes: String = "",
        macros: Macros = Macros(),
        tags: [String] = [],
        servings: Int = 1,
        prepTimeStars: Int = 3,
        replateMeta: ReplateMeta? = nil,
        createdAt: Date = Date(),
        likeCount: Int = 0,
        saveCount: Int = 0,
        commentCount: Int = 0,
        replateCount: Int = 0,
        recentLikers: [RecipeLiker] = [],
        recentComments: [RecipePreviewComment] = []
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.dishName = dishName
        self.imageURL = imageURL
        self.ingredients = ingredients
        self.steps = steps
        self.notes = notes
        self.macros = macros
        self.tags = tags
        self.servings = servings
        self.prepTimeStars = prepTimeStars
        self.replateMeta = replateMeta
        self.createdAt = createdAt
        self.likeCount = likeCount
        self.saveCount = saveCount
        self.commentCount = commentCount
        self.replateCount = replateCount
        self.recentLikers = recentLikers
        self.recentComments = recentComments
    }

    init?(from dictionary: [String: Any]) {
        guard
            let id = dictionary["id"] as? String,
            let userId = dictionary["userId"] as? String,
            let username = dictionary["username"] as? String,
            let dishName = dictionary["dishName"] as? String,
            let imageURL = dictionary["imageURL"] as? String,
            let timestamp = dictionary["createdAt"] as? Timestamp
        else { return nil }

        self.id = id
        self.userId = userId
        self.username = username
        self.dishName = dishName
        self.imageURL = imageURL
        self.createdAt = timestamp.dateValue()
        self.steps = dictionary["steps"] as? [String] ?? []
        self.notes = dictionary["notes"] as? String ?? ""
        self.tags = dictionary["tags"] as? [String] ?? []
        self.servings = dictionary["servings"] as? Int ?? 1
        self.prepTimeStars = dictionary["prepTimeStars"] as? Int ?? 3
        self.likeCount = dictionary["likeCount"] as? Int ?? 0
        self.saveCount = dictionary["saveCount"] as? Int ?? 0
        self.commentCount = dictionary["commentCount"] as? Int ?? 0
        self.replateCount = dictionary["replateCount"] as? Int ?? 0
        if let likersArray = dictionary["recentLikers"] as? [[String: Any]] {
            self.recentLikers = likersArray.compactMap { dict in
                guard let userId = dict["userId"] as? String,
                      let username = dict["username"] as? String else { return nil }
                return RecipeLiker(userId: userId, username: username)
            }
        } else {
            self.recentLikers = []
        }

        if let commentsArray = dictionary["recentComments"] as? [[String: Any]] {
            self.recentComments = commentsArray.compactMap { dict in
                guard let username = dict["username"] as? String,
                      let text = dict["text"] as? String else { return nil }
                return RecipePreviewComment(
                    userId: dict["userId"] as? String ?? "",
                    username: username,
                    text: text
                )
            }
        } else {
            self.recentComments = []
        }

        if let macrosDict = dictionary["macros"] as? [String: Any] {
            self.macros = Macros(
                calories: macrosDict["calories"] as? Int ?? 0,
                protein: macrosDict["protein"] as? Int ?? 0,
                carbs: macrosDict["carbs"] as? Int ?? 0,
                fat: macrosDict["fat"] as? Int ?? 0,
                fiber: macrosDict["fiber"] as? Int ?? 0,
                sugar: macrosDict["sugar"] as? Int ?? 0
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

        if let replateDict = dictionary["replateMeta"] as? [String: Any],
           let originalRecipeId = replateDict["originalRecipeId"] as? String,
           let originalUserId = replateDict["originalUserId"] as? String,
           let originalUsername = replateDict["originalUsername"] as? String,
           let originalDishName = replateDict["originalDishName"] as? String {
            self.replateMeta = ReplateMeta(
                originalRecipeId: originalRecipeId,
                originalUserId: originalUserId,
                originalUsername: originalUsername,
                originalDishName: originalDishName
            )
        } else {
            self.replateMeta = nil
        }
    }

    // Lowercased tokens the recipe search matches against: dish-name words,
    // tags, ingredient names, and derived macro labels ("high protein",
    // "low carb", …). Stored on the doc so search is a single arrayContains.
    func searchTerms() -> [String] {
        var terms = Set<String>()
        func addWords(_ s: String) {
            for w in s.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) where w.count >= 2 {
                terms.insert(String(w))
            }
        }
        addWords(dishName)
        for t in tags {
            terms.insert(t.lowercased())
            addWords(t)
        }
        for ing in ingredients { addWords(ing.name) }

        let per = max(1, servings)
        let p = macros.protein / per
        let fib = macros.fiber / per
        let carb = macros.carbs / per
        let cal = macros.calories / per
        if p >= 20 { terms.insert("high protein"); terms.insert("protein") }
        if fib >= 6 { terms.insert("high fiber"); terms.insert("fiber") }
        if carb <= 20 { terms.insert("low carb") }
        if cal <= 400 { terms.insert("low calorie") }

        return Array(terms)
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "userId": userId,
            "username": username,
            "dishName": dishName,
            "imageURL": imageURL,
            "steps": steps,
            "notes": notes,
            "tags": tags,
            "searchTerms": searchTerms(),
            "servings": servings,
            "prepTimeStars": prepTimeStars,
            "createdAt": Timestamp(date: createdAt),
            "likeCount": likeCount,
            "saveCount": saveCount,
            "commentCount": commentCount,
            "replateCount": replateCount,
            "recentLikers": recentLikers.map { ["userId": $0.userId, "username": $0.username] },
            "macros": [
                "calories": macros.calories,
                "protein": macros.protein,
                "carbs": macros.carbs,
                "fat": macros.fat,
                "fiber": macros.fiber,
                "sugar": macros.sugar
            ],
            "ingredients": ingredients.map { [
                "name": $0.name,
                "quantity": $0.quantity
            ]}
        ]

        if let meta = replateMeta {
            dict["replateMeta"] = [
                "originalRecipeId": meta.originalRecipeId,
                "originalUserId": meta.originalUserId,
                "originalUsername": meta.originalUsername,
                "originalDishName": meta.originalDishName
            ]
        }

        return dict
    }
}
