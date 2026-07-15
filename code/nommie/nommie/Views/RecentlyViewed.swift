import SwiftUI

// Locally-remembered recipes the user recently opened. Stored as lightweight
// snapshots in UserDefaults (last 10), so they render instantly with no fetch.
enum RecentlyViewed {
    private static let key = "recentlyViewedRecipes"
    private static let maxCount = 10

    static func record(_ recipe: Recipe) {
        var list = all().filter { $0.id != recipe.id }
        list.insert(recipe, at: 0)
        if list.count > maxCount { list = Array(list.prefix(maxCount)) }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func all() -> [Recipe] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([Recipe].self, from: data) else { return [] }
        return list
    }
}

// A horizontal strip of recently-viewed recipe thumbnails.
struct RecentlyViewedStrip: View {
    let recipes: [Recipe]
    let onTap: (Recipe) -> Void

    var body: some View {
        if !recipes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recently viewed")
                    .font(Font.custom("Nunito-SemiBold", size: 13))
                    .foregroundColor(.nommieBrown.opacity(0.5))
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recipes) { recipe in
                            Button(action: { onTap(recipe) }) {
                                VStack(alignment: .leading, spacing: 5) {
                                    CachedAsyncImage(url: URL(string: recipe.imageURL)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.nommieGreen.opacity(0.1))
                                            .overlay(Image(systemName: "fork.knife").foregroundColor(.nommieGreen.opacity(0.3)))
                                    }
                                    .frame(width: 104, height: 104)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                    Text(recipe.dishName)
                                        .font(Font.custom("Nunito-SemiBold", size: 12))
                                        .foregroundColor(.nommieBrown)
                                        .lineLimit(1)
                                        .frame(width: 104, alignment: .leading)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
