import SwiftUI

struct Step3_MacrosView: View {
    @ObservedObject var viewModel: RecipeCreationViewModel
    var footer: AnyView = AnyView(EmptyView())

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Heading
                VStack(alignment: .leading, spacing: 4) {
                    Text("Macros & Tags")
                        .font(NommieFont.titleSmall.font())
                        .foregroundColor(.nommieBrown)
                    Text("Let AI estimate or enter your own")
                        .font(NommieFont.bodyRegular.font())
                        .foregroundColor(.nommieBrown.opacity(0.5))
                }
                .padding(.horizontal, NommieTheme.Padding.large)

                // Estimate button
                // Estimate button with sparkle icon
                Button(action: { Task { await viewModel.estimateMacros() } }) {
                    ZStack {
                        if viewModel.isEstimatingMacros {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16))
                                Text("Estimate Macros")
                                    .font(Font.custom("Nunito-SemiBold", size: 16))
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).fill(Color.nommieGreen))
                }
                .disabled(viewModel.isEstimatingMacros)
                .padding(.horizontal, NommieTheme.Padding.large)

                // Macro 3x2 grid
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        MacroInputBox(label: "CALORIES", value: $viewModel.macros.calories, unit: "")
                        MacroInputBox(label: "PROTEIN", value: $viewModel.macros.protein, unit: "g")
                        MacroInputBox(label: "CARBS", value: $viewModel.macros.carbs, unit: "g")
                    }
                    HStack(spacing: 10) {
                        MacroInputBox(label: "FAT", value: $viewModel.macros.fat, unit: "g")
                        MacroInputBox(label: "FIBER", value: $viewModel.macros.fiber, unit: "g")
                        MacroInputBox(label: "SUGAR", value: $viewModel.macros.sugar, unit: "g")
                    }
                }
                .padding(.horizontal, NommieTheme.Padding.large)

                // AI disclaimer
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.nommieBrown.opacity(0.4))
                        .padding(.top, 1)
                    Text("Heads up! AI macro estimates aren't perfect. If something looks off, feel free to tweak the numbers to better match your recipe.")
                        .font(Font.custom("Nunito-Regular", size: 12))
                        .foregroundColor(.nommieBrown.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
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

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(NommieFont.caption.font())
                        .foregroundColor(.nommieBlush)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, NommieTheme.Padding.large)
                }

                footer
            }
            .padding(.top, NommieTheme.Padding.small)
        }
    }
}

// MARK: - Macro Input Box
struct MacroInputBox: View {
    let label: String
    @Binding var value: Int
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Font.custom("Nunito-Regular", size: 11))
                .foregroundColor(.nommieBrown.opacity(0.5))
                .kerning(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                TextField(value: $value, format: .number, prompt: Text("0").foregroundColor(.nommieBrown.opacity(0.4))) {}
                    .font(NommieFont.titleSmall.font())
                    .foregroundColor(.nommieBrown)
                    .keyboardType(.numberPad)

                if !unit.isEmpty {
                    Text(unit)
                        .font(NommieFont.caption.font())
                        .foregroundColor(.nommieBrown.opacity(0.4))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NommieTheme.Padding.medium)
        .background(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).fill(Color.white.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: NommieTheme.CornerRadius.medium).stroke(Color.nommieBrown.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Flow Layout
struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(items, id: \.self) { item in
                    content(item)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geometry.size.width {
                                width = 0
                                height -= d.height + 8
                            }
                            let result = width
                            if item == items.last { width = 0 } else { width -= d.width + 8 }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if item == items.last { height = 0 }
                            return result
                        }
                }
            }
        }
        .frame(height: calculateHeight(itemCount: items.count))
    }

    private func calculateHeight(itemCount: Int) -> CGFloat {
        let estimatedTagWidth: CGFloat = 120
        let availableWidth = UIScreen.main.bounds.width - 48
        let tagsPerRow = max(1, Int(availableWidth / (estimatedTagWidth + 8)))
        let rowCount = ceil(Double(itemCount) / Double(tagsPerRow))
        return rowCount * 36
    }
}
