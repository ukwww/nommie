import SwiftUI

struct Step2_DetailsView: View {
    @ObservedObject var viewModel: RecipeCreationViewModel
    @FocusState private var focusedField: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Dish name (no label — placeholder says it all)
                TextField("", text: $viewModel.dishName, prompt: Text("e.g. Spicy Vodka Rigatoni").foregroundColor(.nommieBrown.opacity(0.45)))
                    .font(NommieFont.titleSmall.font())
                    .foregroundColor(.nommieBrown)
                    .padding(NommieTheme.Padding.medium)
                    .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).fill(Color.white.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1))
                    .padding(.horizontal, NommieTheme.Padding.large)
                    .focused($focusedField, equals: "dishName")

                // Ingredients
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ingredients")
                        .font(NommieFont.bodySemiBold.font())
                        .foregroundColor(.nommieBrown)
                        .padding(.horizontal, NommieTheme.Padding.large)

                    VStack(spacing: 8) {
                        ForEach($viewModel.ingredients) { $ingredient in
                            HStack(spacing: 8) {
                                // Name first, then quantity
                                TextField("", text: $ingredient.name, prompt: Text("e.g. Rigatoni").foregroundColor(.nommieBrown.opacity(0.45)))
                                    .font(NommieFont.bodyRegular.font())
                                    .foregroundColor(.nommieBrown)
                                    .padding(NommieTheme.Padding.medium)
                                    .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).fill(Color.white.opacity(0.7)))
                                    .overlay(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1))

                                TextField("", text: $ingredient.quantity, prompt: Text("1 lb").foregroundColor(.nommieBrown.opacity(0.45)))
                                    .font(NommieFont.bodyRegular.font())
                                    .foregroundColor(.nommieBrown)
                                    .frame(width: 70)
                                    .multilineTextAlignment(.center)
                                    .padding(NommieTheme.Padding.medium)
                                    .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).fill(Color.white.opacity(0.7)))
                                    .overlay(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1))

                                Button(action: { viewModel.removeIngredient(id: ingredient.id) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.nommieBrown.opacity(0.3))
                                        .font(.system(size: 16))
                                }
                                .opacity(viewModel.ingredients.count > 1 ? 1.0 : 0.2)
                                .disabled(viewModel.ingredients.count <= 1)
                            }
                            .padding(.horizontal, NommieTheme.Padding.large)
                        }
                    }

                    Button(action: { viewModel.addIngredient() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 13))
                            Text("Add ingredient")
                                .font(NommieFont.bodyRegular.font())
                        }
                        .foregroundColor(.nommieGreen)
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)
                    .padding(.top, 4)
                }

                // Prep time (stars) + servings
                VStack(alignment: .leading, spacing: 16) {
                    // Prep time stars
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Prep time")
                                .font(NommieFont.bodySemiBold.font())
                                .foregroundColor(.nommieBrown)
                            Spacer()
                            Text("~\(viewModel.prepTimeStars * 15) min")
                                .font(NommieFont.caption.font())
                                .foregroundColor(.nommieGreen)
                        }
                        HStack(spacing: 10) {
                            ForEach(1...5, id: \.self) { star in
                                Button(action: { viewModel.prepTimeStars = star }) {
                                    Image(systemName: star <= viewModel.prepTimeStars ? "star.fill" : "star")
                                        .font(.system(size: 24))
                                        .foregroundColor(star <= viewModel.prepTimeStars ? .nommieGreen : .nommieBrown.opacity(0.25))
                                }
                            }
                        }
                        Text("Each star is about 15 minutes of cook time.")
                            .font(Font.custom("Nunito-Regular", size: 11))
                            .foregroundColor(.nommieBrown.opacity(0.4))
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)

                    // Servings stepper
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Servings")
                                .font(NommieFont.bodySemiBold.font())
                                .foregroundColor(.nommieBrown)
                            Text("Used for per-serving macros")
                                .font(Font.custom("Nunito-Regular", size: 11))
                                .foregroundColor(.nommieBrown.opacity(0.4))
                        }
                        Spacer()
                        HStack(spacing: 16) {
                            Button(action: { if viewModel.servings > 1 { viewModel.servings -= 1 } }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(viewModel.servings > 1 ? .nommieGreen : .nommieBrown.opacity(0.2))
                            }
                            .disabled(viewModel.servings <= 1)

                            Text("\(viewModel.servings)")
                                .font(NommieFont.titleSmall.font())
                                .foregroundColor(.nommieBrown)
                                .frame(minWidth: 24)

                            Button(action: { if viewModel.servings < 20 { viewModel.servings += 1 } }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.nommieGreen)
                            }
                        }
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)
                }

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (optional)")
                        .font(NommieFont.bodySemiBold.font())
                        .foregroundColor(.nommieBrown)
                        .padding(.horizontal, NommieTheme.Padding.large)

                    TextField("", text: $viewModel.notes, prompt: Text("e.g. 1. Sauté shallot and garlic in butter over med heat until soft, ~3 min").foregroundColor(.nommieBrown.opacity(0.45)), axis: .vertical)
                        .font(NommieFont.bodyRegular.font())
                        .foregroundColor(.nommieBrown)
                        .lineLimit(4...8)
                        .padding(NommieTheme.Padding.medium)
                        .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).fill(Color.white.opacity(0.7)))
                        .overlay(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1))
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .focused($focusedField, equals: "notes")
                }

                // Tags
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tags")
                        .font(NommieFont.bodySemiBold.font())
                        .foregroundColor(.nommieBrown)
                        .padding(.horizontal, NommieTheme.Padding.large)
                    Text("Pick what applies to your dish.")
                        .font(Font.custom("Nunito-Regular", size: 12))
                        .foregroundColor(.nommieBrown.opacity(0.45))
                        .padding(.horizontal, NommieTheme.Padding.large)

                    TagPickerGrid(selectedTags: $viewModel.tags)
                        .padding(.horizontal, NommieTheme.Padding.large)
                }

                Spacer(minLength: 120)
            }
            .padding(.top, NommieTheme.Padding.medium)
        }
        .onTapGesture { focusedField = nil }
    }
}

// MARK: - Tag Picker

private let allAvailableTags: [String] = [
    "Breakfast", "Lunch", "Dinner", "Snack", "Sweet Treat",
    "Dessert", "Drink", "Meal Prep",
    "High Protein", "High Fiber", "Low Carb", "Low Calorie",
    "Plant-Based", "Dairy-Free", "Gluten-Free"
]

struct TagPickerGrid: View {
    @Binding var selectedTags: [String]

    var body: some View {
        FlowTagLayout(tags: allAvailableTags) { tag in
            let isSelected = selectedTags.contains(tag)
            Button(action: {
                if isSelected {
                    selectedTags.removeAll { $0 == tag }
                } else {
                    selectedTags.append(tag)
                }
            }) {
                Text(tag)
                    .font(Font.custom("Nunito-Regular", size: 13))
                    .foregroundColor(isSelected ? .nommieGreen : .nommieBrown.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(isSelected ? Color.nommieGreen.opacity(0.12) : Color.nommieBrown.opacity(0.07)))
                    .overlay(Capsule().stroke(isSelected ? Color.nommieGreen.opacity(0.35) : Color.nommieBrown.opacity(0.15), lineWidth: 1))
            }
        }
    }
}

struct FlowTagLayout<Content: View>: View {
    let tags: [String]
    let content: (String) -> Content

    init(tags: [String], @ViewBuilder content: @escaping (String) -> Content) {
        self.tags = tags
        self.content = content
    }

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        let screenWidth = UIScreen.main.bounds.width - 48

        return GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                ForEach(tags, id: \.self) { tag in
                    content(tag)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > screenWidth {
                                width = 0
                                height -= d.height + 8
                            }
                            let result = width
                            if tag == tags.last { width = 0 } else { width -= d.width + 8 }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if tag == tags.last { height = 0 }
                            return result
                        }
                }
            }
        }
        .frame(height: estimatedHeight(for: tags, screenWidth: screenWidth))
    }

    private func estimatedHeight(for tags: [String], screenWidth: CGFloat) -> CGFloat {
        let avgTagWidth: CGFloat = 100
        let tagsPerRow = max(1, Int(screenWidth / (avgTagWidth + 8)))
        let rows = Int(ceil(Double(tags.count) / Double(tagsPerRow)))
        return CGFloat(rows) * 36
    }
}
