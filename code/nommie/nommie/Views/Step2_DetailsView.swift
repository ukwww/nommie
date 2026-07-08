import SwiftUI

// Step 2 — "Write": the heart of creation. Name the dish, tell the story of
// how you cooked it. Ingredients are drafted by AI from these steps in Step 3.
struct Step2_DetailsView: View {
    @ObservedObject var viewModel: RecipeCreationViewModel
    @FocusState private var focusedField: String?

    var body: some View {
        ScrollViewReader { proxy in
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

                    // Steps
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How did you make it?")
                            .font(NommieFont.bodySemiBold.font())
                            .foregroundColor(.nommieBrown)
                            .padding(.horizontal, NommieTheme.Padding.large)
                        Text("Write it like you'd tell a friend. We'll draft your ingredient list from these steps.")
                            .font(Font.custom("Nunito-Regular", size: 12))
                            .foregroundColor(.nommieBrown.opacity(0.45))
                            .padding(.horizontal, NommieTheme.Padding.large)

                        VStack(spacing: 8) {
                            ForEach(Array(viewModel.stepEntries.enumerated()), id: \.element.id) { index, entry in
                                StepEditorRow(
                                    number: index + 1,
                                    text: bindingForStep(id: entry.id),
                                    canDelete: viewModel.stepEntries.count > 1,
                                    onDelete: { viewModel.removeStep(id: entry.id) },
                                    onReturn: {
                                        let newId = viewModel.insertStep(after: entry.id)
                                        focusedField = "step_\(newId)"
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            proxy.scrollTo("step_\(newId)", anchor: .center)
                                        }
                                    }
                                )
                                .focused($focusedField, equals: "step_\(entry.id)")
                                .id("step_\(entry.id)")
                                .padding(.horizontal, NommieTheme.Padding.large)
                            }
                        }

                        Button(action: {
                            viewModel.addStep { newId in
                                focusedField = "step_\(newId)"
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo("step_\(newId)", anchor: .center)
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13))
                                Text("Add step")
                                    .font(NommieFont.bodyRegular.font())
                            }
                            .foregroundColor(.nommieGreen)
                        }
                        .padding(.horizontal, NommieTheme.Padding.large)
                        .padding(.top, 4)
                    }

                    // Prep time — quarter-clock dropdown (~15/~30/~45/~60)
                    HStack {
                        Text("Prep time")
                            .font(NommieFont.bodySemiBold.font())
                            .foregroundColor(.nommieBrown)
                        Spacer()
                        Menu {
                            ForEach(1...4, id: \.self) { quarter in
                                Button(action: { viewModel.prepTimeStars = quarter }) {
                                    if viewModel.prepTimeStars == quarter {
                                        Label("~\(quarter * 15) min", systemImage: "checkmark")
                                    } else {
                                        Text("~\(quarter * 15) min")
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                QuarterClockIcon(
                                    quarters: min(max(viewModel.prepTimeStars, 1), 4),
                                    size: 18,
                                    accent: .nommieGreen
                                )
                                Text("~\(min(max(viewModel.prepTimeStars, 1), 4) * 15) min")
                                    .font(NommieFont.bodyRegular.font())
                                    .foregroundColor(.nommieBrown)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.nommieBrown.opacity(0.4))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).fill(Color.white.opacity(0.7)))
                            .overlay(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, NommieTheme.Padding.large)

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (optional)")
                            .font(NommieFont.bodySemiBold.font())
                            .foregroundColor(.nommieBrown)
                            .padding(.horizontal, NommieTheme.Padding.large)

                        TextField("", text: $viewModel.notes, prompt: Text("e.g. Swap chicken broth for veggie broth to make it vegetarian").foregroundColor(.nommieBrown.opacity(0.45)), axis: .vertical)
                            .font(NommieFont.bodyRegular.font())
                            .foregroundColor(.nommieBrown)
                            .lineLimit(3...6)
                            .padding(NommieTheme.Padding.medium)
                            .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).fill(Color.white.opacity(0.7)))
                            .overlay(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1))
                            .padding(.horizontal, NommieTheme.Padding.large)
                            .focused($focusedField, equals: "notes")
                    }

                    Spacer(minLength: 120)
                }
                .padding(.top, NommieTheme.Padding.medium)
            }
        }
        .onTapGesture { focusedField = nil }
    }

    private func bindingForStep(id: String) -> Binding<String> {
        Binding(
            get: { viewModel.stepEntries.first(where: { $0.id == id })?.text ?? "" },
            set: { newValue in
                if let idx = viewModel.stepEntries.firstIndex(where: { $0.id == id }) {
                    viewModel.stepEntries[idx].text = newValue
                }
            }
        )
    }
}

// MARK: - Step Editor Row

// A numbered, growing text row. Pressing return doesn't insert a newline —
// it advances to a fresh step (the auto-advance testers asked for).
struct StepEditorRow: View {
    let number: Int
    @Binding var text: String
    let canDelete: Bool
    let onDelete: () -> Void
    let onReturn: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(Font.custom("Nunito-Bold", size: 13))
                .foregroundColor(.nommieGreen)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.nommieGreen.opacity(0.12)))
                .padding(.top, 12)

            TextField("", text: $text, prompt: Text(number == 1 ? "e.g. Boil eggs for exactly 6 minutes, then ice bath" : "Next step...").foregroundColor(.nommieBrown.opacity(0.4)), axis: .vertical)
                .font(NommieFont.bodyRegular.font())
                .foregroundColor(.nommieBrown)
                .lineLimit(1...5)
                .padding(NommieTheme.Padding.medium)
                .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).fill(Color.white.opacity(0.7)))
                .overlay(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.small).stroke(Color.nommieBrown.opacity(0.15), lineWidth: 1))
                .onChange(of: text) { _, newValue in
                    // Vertical-axis fields insert "\n" on return; convert that
                    // into "advance to the next step" instead.
                    if newValue.contains("\n") {
                        text = newValue.replacingOccurrences(of: "\n", with: "")
                        onReturn()
                    }
                }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.nommieBrown.opacity(0.3))
                    .font(.system(size: 15))
            }
            .opacity(canDelete ? 1.0 : 0.2)
            .disabled(!canDelete)
            .padding(.top, 14)
        }
    }
}

// MARK: - Tag Picker (used on the Macros step)

let allAvailableTags: [String] = [
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
